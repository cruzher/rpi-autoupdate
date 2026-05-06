# debian-autoupdate

A simple bash script that keeps Debian-based system up to date automatically by running unattended APT upgrades on a cron schedule.

## What it does

1. Refreshes package lists (`apt-get update`)
2. Upgrades installed packages non-interactively, preserving existing config files
3. Runs `full-upgrade` to handle dependency changes
4. Removes orphaned packages (`autoremote --purge`)
5. Clears the APT package cache
6. Logs disk usage after the update
7. Schedules a reboot (1 minute delay) if a kernel/firmware update requires it

All output is logged to `/var/log/debian_auto_update.log`, automatically trimmed to the last 500 lines.

## Installation

```bash
git clone https://github.com/cruzher/debian-autoupdate
```

```bash
sudo chmod +x debian_auto_update.sh
```

### Easy Installation (Automated Cron Setup)

You can use the `--install` flag to interactively set up a cron job with the correct absolute path for the script:

```bash
sudo ./debian_auto_update.sh --install
```

The script will prompt you to choose between:
- **Daily** at 03:00
- **Weekly** on Sunday at 03:00
- **Monthly** on the 1st at 02:30

## Scheduling with cron

```bash
sudo crontab -e
```

Add the script to crontab with fullpath, for example:

| Schedule | Cron line |
|---|---|
| Every Sunday at 03:00 (recommended) | `0 3 * * 0 /usr/local/bin/debian_auto_update.sh` |
| Every day at 03:00 | `0 3 * * * /usr/local/bin/debian_auto_update.sh` |
| 1st of every month at 02:30 | `30 2 1 * * /usr/local/bin/debian_auto_update.sh` |

## Manual run

```bash
sudo /usr/local/bin/debian_auto_update.sh
```

## Log file

```bash
tail -f /var/log/debian_auto_update.log
```
