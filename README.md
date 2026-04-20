# rpi-autoupdate

A simple bash script that keeps Raspberry Pi OS up to date automatically by running unattended APT upgrades on a cron schedule.

## What it does

1. Refreshes package lists (`apt-get update`)
2. Upgrades installed packages non-interactively, preserving existing config files
3. Runs `full-upgrade` to handle dependency changes
4. Removes orphaned packages (`autoremove --purge`)
5. Clears the APT package cache
6. Logs disk usage after the update
7. Schedules a reboot (1 minute delay) if a kernel/firmware update requires it

All output is logged to `/var/log/rpi_auto_update.log`, automatically trimmed to the last 500 lines.

## Installation

```bash
git clone https://github.com/cruzher/rpi-autoupdate

```bash
sudo chmod +x rpi_auto_update.sh #make it executable
```

## Scheduling with cron

```bash
sudo crontab -e
```

Add the script to crontab with fullpath, for example:

| Schedule | Cron line |
|---|---|
| Every Sunday at 03:00 (recommended) | `0 3 * * 0 /usr/local/bin/rpi_auto_update.sh` |
| Every day at 03:00 | `0 3 * * * /usr/local/bin/rpi_auto_update.sh` |
| 1st of every month at 02:30 | `30 2 1 * * /usr/local/bin/rpi_auto_update.sh` |

## Manual run

```bash
sudo /usr/local/bin/rpi_auto_update.sh
```

## Log file

```bash
tail -f /var/log/rpi_auto_update.log
```
