#!/bin/bash
# =============================================================
#  Debian-based System – Scheduled Auto-Updater
#  Installs updates and cleans up cached packages automatically.
#
#  SETUP (run once as root):
#    sudo chmod +555 /usr/local/bin/debian_auto_update.sh
#    sudo crontab -e   →  add the cron line shown at the bottom
# =============================================================

LOG="/var/log/debian_auto_update.log"
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

install_cron() {
    local script_path
    script_path=$(realpath "$0")

    echo "Select a crontab schedule for: $script_path"
    echo "1) Daily at 03:00 (0 3 * * *)"
    echo "2) Weekly on Sunday at 03:00 (0 3 * * 0)"
    echo "3) Monthly on the 1st at 02:30 (30 2 1 * *)"
    echo "4) Cancel"
    read -p "Enter choice [1-4]: " choice

    local cron_schedule=""
    case $choice in
        1) cron_template="0 3 * * *" ;;
        2) cron_template="0 3 * * 0" ;;
        3) cron_template="30 2 1 * *" ;;
        4) echo "Installation cancelled."; return 0 ;;
        *) echo "Invalid choice."; return 1 ;;
    esac

    local cron_entry="$cron_template $script_path"

    # Check if already exists
    if crontab -l 2>/dev/null | grep -Fq "$script_path"; then
        echo "Cron entry for $script_path already exists."
        return 0
    fi

    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    echo "Successfully installed cron job: $cron_entry"
}

# ── main ─────────────────────────────────────────────────────
require_root
trim_log

if [[ "$1" == "--install" ]]; then
    install_cron
    exit 0
fi

# Check internet connectivity before proceeding
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    log "No internet connection detected. Exiting."
    exit 1
fi

log "============================================================"
log "  Starting Debian-based system update cycle"
log "============================================================"

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
log "→ Cleaning APT package *package* cache…"
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

# ====================================================================
#  CRON SETUP  (add ONE of these to: sudo crontab -e)
#
#  Every Sunday at 03:00 (recommended for most Pi projects):
#    0 3 * * 0  /usr/local/bin/debian_auto_update.sh
#
#  Every day at 03:00:
#    0 3 * * *  /usr/local/bin/debian_auto_update.sh
#
#  Every 1st of the month at 02:30:
#    30 2 1 * * /usr/local/bin/debian_auto_update.sh
# ====================================================================
