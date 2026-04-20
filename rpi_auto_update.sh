#!/bin/bash
# =============================================================
#  Raspberry Pi OS – Scheduled Auto-Updater
#  Installs updates and cleans up cached packages automatically.
#
#  SETUP (run once as root):
#    sudo chmod +x /usr/local/bin/rpi_auto_update.sh
#    sudo crontab -e   →  add the cron line shown at the bottom
# =============================================================

LOG="/var/log/rpi_auto_update.log"
MAX_LOG_LINES=500   # keep the log file from growing forever

# ── helpers ──────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This script must be run as root (use sudo)." >&2
        exit 1
    fi
}

trim_log() {
    if [[ -f "$LOG" ]]; then
        local lines
        lines=$(wc -l < "$LOG")
        if (( lines > MAX_LOG_LINES )); then
            tail -n "$MAX_LOG_LINES" "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
        fi
    fi
}

# ── main ─────────────────────────────────────────────────────
require_root
trim_log

log "========================================"
log "  Starting Raspberry Pi OS update cycle"
log "========================================"

# 1. Refresh package lists
log "→ Updating package lists…"
if apt-get update -qq 2>>"$LOG"; then
    log "  Package lists refreshed."
else
    log "  WARNING: 'apt-get update' reported errors (check log above)."
fi

# 2. Upgrade installed packages (non-interactive, keep existing configs)
log "→ Upgrading installed packages…"
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    -o Dpkg::Options::="--force-confold" \
    -o Dpkg::Options::="--force-confdef" \
    >> "$LOG" 2>&1
log "  Upgrade complete."

# 3. Full-upgrade: handles packages that need dependency changes
log "→ Running full-upgrade…"
DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y \
    -o Dpkg::Options::="--force-confold" \
    -o Dpkg::Options::="--force-confdef" \
    >> "$LOG" 2>&1
log "  Full-upgrade complete."

# 4. Remove packages that are no longer needed
log "→ Removing orphaned packages…"
apt-get autoremove -y --purge >> "$LOG" 2>&1
log "  Autoremove done."

# 5. Clear the APT package cache (downloaded .deb files)
log "→ Cleaning APT package cache…"
apt-get clean >> "$LOG" 2>&1          # removes /var/cache/apt/archives/*.deb
apt-get autoclean >> "$LOG" 2>&1      # removes .deb files for packages no longer in repos
log "  Cache cleaned."

# 6. Show disk usage summary
DISK_USED=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 " used)"}')
log "→ Root filesystem: $DISK_USED"

# 7. Optional reboot if a kernel/firmware update requires it
if [[ -f /var/run/reboot-required ]]; then
    log "  A reboot is required to apply kernel/firmware updates."
    log "  Scheduling reboot in 1 minute…"
    shutdown -r +1 "System rebooting to apply updates" >> "$LOG" 2>&1
fi

log "  Update cycle finished."
log ""

# =============================================================
#  CRON SETUP  (add ONE of these to: sudo crontab -e)
#
#  Every Sunday at 03:00 (recommended for most Pi projects):
#    0 3 * * 0  /usr/local/bin/rpi_auto_update.sh
#
#  Every day at 03:00:
#    0 3 * * *  /usr/local/bin/rpi_auto_update.sh
#
#  Every 1st of the month at 02:30:
#    30 2 1 * * /usr/local/bin/rpi_auto_update.sh
# =============================================================