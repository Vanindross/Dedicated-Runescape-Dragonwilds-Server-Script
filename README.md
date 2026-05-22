# AdventurerMenu: RuneScape Dragonwilds Server Manager

A feature-rich, interactive Bash management script for deploying, maintaining, and automating **RuneScape: Dragonwilds** dedicated servers on Linux. Heavily inspired by NjordMenu, this tool streamlines server administration, making it easy to handle everything from initial deployment to automated headless updates.

## ✨ Features

- **Interactive TUI:** An easy-to-use terminal interface for all core server tasks.
- **Smart Installs & Updates:** Automatically handles SteamCMD deployment (App ID `4019830`). Safely stops the server and stashes existing save files before applying updates to prevent SteamCMD validate from ruining your day.
- **Process Management:** Supports both lightweight `tmux` session management and robust `systemd` service integration for automatic start on boot.
- **Safe Restores:** The restore function automatically generates a safety backup of your _current_ data before applying an older archive, ensuring you never permanently lose progress if a rollback goes wrong.
- **Headless Automation:** \* Generates `systemd` timers to automatically check the Steam Web API for new public branch builds and update the server without manual intervention.
- **Log Management** Configures `logrotate` to keep server and internal game logs under control.

## 📦 Prerequisites

The script requires a few standard packages to function correctly. Ensure the following are installed via your distribution's package manager (e.g., `apt` for Ubuntu, `pacman` for Arch):

- `sudo`
- `tar`
- `nano`
- `steamcmd`
- `curl`
- `jq`
- `tmux` (if not running via systemd)

## 🚀 Installation & Usage

1. Download or clone `AdventurerMenu.sh` to your desired directory.
2. Make the script executable:

```bash
   chmod +x AdventurerMenu.sh
```

Run the script:

```bash
./AdventurerMenu.sh
```

Note: The script will automatically create a dedicated steam user and handle permission scoping for game files and backups to keep your system secure.

## 🛠️ Menu Options

##### Core Operations

1 ) Install / Update Server: Safely stops the server, stashes saves, pulls the latest files from SteamCMD, and restores your data.

2-4) Start / Stop / Restart Server: Gracefully manages the server process via systemd (if configured) or tmux.

5 ) View Console / Logs: Tails the live systemd output or attaches to the tmux session.

##### Data Management

6 ) Backup Save Data: Creates a timestamped .tar.gz archive of your world data.

7 ) Restore Backup: Allows you to select an archive to restore. Automatically creates a pre-restore safety backup of the current state.

8 ) Edit Configuration: Opens DedicatedServer.ini in nano for quick tweaks.

##### Automation Tasks

9 ) Build Systemd Service: Generates and enables a systemd service file for the server.

10 ) Configure Log Rotation: Sets up `/etc/logrotate.d/` rules for your server logs.

11 ) Configure Automated Updates: Creates a systemd timer that pings the Steam API daily to check against your local build ID, automatically applying updates only when necessary.
<img width="879" height="685" alt="image" src="https://github.com/user-attachments/assets/4aff6c11-457f-4185-8315-61150a64e726" />

## 📂 Directory Structure

By default, the script sets up the following structure under the steam user:

Server Install: `/home/steam/dragonwilds_server/`

Save Files: `/home/steam/dragonwilds_server/RSDragonwilds/Saved/SaveGames/`

Backups: `/home/steam/RSDragonwilds_Backups/`

System Logs: `/var/log/dragonwilds.log`

## 📝 License

Feel free to fork, modify, and expand this script for your own guild or community needs.

## ⚠️ Disclaimer: Network & Firewall Configuration

This script handles the local installation, automation, and process management of your server, but **it does not configure your network**.

You are entirely responsible for configuring your system's firewall (e.g., `ufw`, `firewalld`, `iptables`) and setting up any necessary port forwarding on your router to make the server publicly accessible.

For the required ports and specific network setup details, please reference the official documentation:
[How to Set Up Dedicated Servers](https://dragonwilds.runescape.com/news/how-to-dedicated-servers)

```

```
Copyright (C) 2026 <Vanindross>
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
