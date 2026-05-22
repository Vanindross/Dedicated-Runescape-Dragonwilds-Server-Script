#!/bin/bash
# ==============================================================================
# RuneScape: Dragonwilds Dedicated Server Management Script
# (Heavily inspired by Njordmenu for Valheim)
# ==============================================================================

# --- Variables ---
STEAM_USER="steam"
SERVER_DIR="/home/$STEAM_USER/dragonwilds_server"
SAVE_DIR="$SERVER_DIR/RSDragonwilds/Saved/SaveGames"
CONFIG_DIR="$SERVER_DIR/RSDragonwilds/Saved/Config/LinuxServer"
CONFIG_FILE="$CONFIG_DIR/DedicatedServer.ini"
BACKUP_DIR="/home/$STEAM_USER/RSDragonwilds_Backups"


# Execution specifics
EXEC_DIR="$SERVER_DIR/RSDragonwilds/Binaries/Linux"
EXEC_BIN="./RSDragonwildsServer-Linux-Shipping"

# Systemd & Tmux config
SERVICE_NAME="dragonwilds"
LOG_FILE="/var/log/dragonwilds.log"
SESSION_NAME="rsdragonwilds"
# Log Rotation
LOGROTATE_CONF="/etc/logrotate.d/dragonwilds"
GAME_LOG_DIR="$SERVER_DIR/RSDragonwilds/Saved/Logs" # Target internal game logs too

# --- Headless Auto-Update Check ---
if [[ "$1" == "--check-updates" ]]; then
        echo "Starting automated update check..."
    # Parse local build ID from the Steam appmanifest
    LOCAL_BUILD=$(awk -F'"' '/"buildid"/{print $4}' "$SERVER_DIR/steamapps/appmanifest_4019830.acf" 2>/dev/null)
    
    # Query Steam Web API for the remote public build ID
    REMOTE_BUILD=$(curl -sL https://api.steamcmd.net/v1/info/4019830 | jq -r '.data."4019830".depots.branches.public.buildid')
    
    # Abort if the API is down to prevent false positives
    if [ -z "$REMOTE_BUILD" ] || [ "$REMOTE_BUILD" == "null" ]; then
        echo "Error: Steam API unreadable or offline. Aborting."
        exit 1 
    fi
    
    if [ "$LOCAL_BUILD" != "$REMOTE_BUILD" ]; then
        echo "New build detected! Local: $LOCAL_BUILD | Remote: $REMOTE_BUILD"
        echo "Stopping server and initiating update process..."
        _do_stop_server
        _do_backup_saves "AutoUpdate_Safety"
        _do_update_server
        
        # Bring it back up if systemd is managing it
        if [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]; then
            echo "Update complete. Restarting systemd service."
            sudo systemctl start $SERVICE_NAME
        fi
    else
        echo "Server is up to date (Build: $LOCAL_BUILD). No action taken."
    fi
    exit 0
fi

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- ASCII Header ---
display_header() {
    clear
    echo -e "${CYAN}"
    echo "==============================================================================="
    echo "   ___      _                 _                        __  __                  "
    echo "  / _ \    | |               | |                      |  \/  |                 "
    echo " / /_\ \ __| |_   _____ _ __ | |_ _   _ _ __ ___ _ __ | \  / | ___ _ __  _   _ "
    echo " |  _  |/ _\` \ \ / / _ \ '_ \| __| | | | '__/ _ \ '__|| |\/| |/ _ \ '_ \| | | |"
    echo " | | | | (_| |\ V /  __/ | | | |_| |_| | | |  __/ |   | |  | |  __/ | | | |_| |"
    echo " \_| |_/\__,_| \_/ \___|_| |_|\__|\__,_|_|  \___|_|   \_|  |_/\___|_| |_|\__,_|"
    echo "                                                                               "
    echo "                     Dedicated Server Manager for Linux                        "
    echo "                       (Heavily inspired by NjordMenu)                         "
    echo -e "===============================================================================${NC}"
    echo ""
}

# --- Core Setup & Checks ---
check_deps() {
    for cmd in sudo tar nano steamcmd curl jq; do
        if ! command -v $cmd &> /dev/null; then
            echo -e "${RED}Error: $cmd is not installed. Please install it using your package manager.${NC}"
            exit 1
        fi
    done
}

ensure_steam_user() {
    if ! id "$STEAM_USER" &>/dev/null; then
        echo -e "${YELLOW}User '$STEAM_USER' does not exist. Creating now...${NC}"
        sudo useradd -m -s /bin/bash "$STEAM_USER"
        echo -e "${GREEN}User '$STEAM_USER' created successfully.${NC}"
    fi
}


is_service_installed() {
    [ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]
}

# --- Silent Helper Functions 
_do_stop_server() {
    if is_service_installed; then
        sudo systemctl stop $SERVICE_NAME
    else
        if sudo -u $STEAM_USER tmux has-session -t $SESSION_NAME 2>/dev/null; then
            sudo -u $STEAM_USER tmux send-keys -t $SESSION_NAME "quit" C-m
            sleep 5
            sudo -u $STEAM_USER tmux kill-session -t $SESSION_NAME 2>/dev/null
        fi
    fi
}

_do_backup_saves() {
    local prefix="${1:-RSDragonwilds_Save}"
    sudo -H -u $STEAM_USER mkdir -p "$BACKUP_DIR"
    
    # Use sudo to check if the directory exists as the steam user
    if sudo -u $STEAM_USER test -d "$SAVE_DIR"; then
        local TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
        local BACKUP_FILE="$BACKUP_DIR/${prefix}_$TIMESTAMP.tar.gz"
        
        sudo -H -u $STEAM_USER tar -czf "$BACKUP_FILE" -C "$SERVER_DIR/RSDragonwilds/Saved" SaveGames
        echo "$BACKUP_FILE"
    else
        echo ""
    fi
}

_do_update_server() {
    local TEMP_SAVED="/home/$STEAM_USER/.dragonwilds_saved_stash"
    
    # Stash
    # If the Saved folder exists, copy it (preserving permissions) to the safe stash
    if sudo -u $STEAM_USER test -d "$SERVER_DIR/RSDragonwilds/Saved"; then
        sudo -H -u $STEAM_USER rm -rf "$TEMP_SAVED" 
        sudo -H -u $STEAM_USER cp -a "$SERVER_DIR/RSDragonwilds/Saved" "$TEMP_SAVED"
    fi
    
    # Update
    # Dynamically find steamcmd path to ensure cross-distro path consistency
    STEAMCMD_PATH=$(command -v steamcmd)
    sudo -H -u $STEAM_USER "$STEAMCMD_PATH" +force_install_dir "/home/$STEAM_USER/dragonwilds_server" +login anonymous +app_update 4019830 validate +quit
    
    # Restore
    # Merge the stash back in. The '.' ensures hidden files are caught and directories merge cleanly
    if sudo -u $STEAM_USER test -d "$TEMP_SAVED"; then
        sudo -H -u $STEAM_USER cp -a "$TEMP_SAVED/." "$SERVER_DIR/RSDragonwilds/Saved/"
        sudo -H -u $STEAM_USER rm -rf "$TEMP_SAVED"
    fi
}
# --- 1. Install / Update Server ---
install_update_server() {
    ensure_steam_user
    echo -e "${YELLOW}Stopping server before running updates...${NC}"
    _do_stop_server
    echo -e "${YELLOW}Installing/Updating RuneScape: Dragonwilds Server...${NC}"
    
    _do_update_server
    
    sudo -H -u $STEAM_USER mkdir -p "$CONFIG_DIR"
    if ! sudo -u $STEAM_USER test -f "$CONFIG_FILE"; then
        echo -e "${CYAN}Default DedicatedServer.ini will be created after first start, then stop of the server${NC}"
    else
        echo -e "${GREEN}Existing DedicatedServer.ini retained securely.${NC}"
    fi
    
    echo -e "${GREEN}Install/Update Complete!${NC}"
    read -p "Press [Enter] to return to menu..."
}

# --- 2. Start Server ---
start_server() {
    ensure_steam_user
    if is_service_installed; then
        echo -e "${GREEN}Starting via Systemd...${NC}"
        sudo systemctl start $SERVICE_NAME
    else
        echo -e "${YELLOW}Starting via Tmux (Systemd not installed)...${NC}"
        if sudo -u $STEAM_USER tmux has-session -t $SESSION_NAME 2>/dev/null; then
            echo -e "${RED}Server is already running in tmux!${NC}"
        else
            sudo -u $STEAM_USER bash -c "cd '$EXEC_DIR' && tmux new-session -d -s $SESSION_NAME '$EXEC_BIN -log'"
            echo -e "${GREEN}Server started in tmux session '$SESSION_NAME'.${NC}"
        fi
    fi
    read -p "Press [Enter] to return to menu..."
}

# --- 3. Stop Server ---
stop_server() {
    echo -e "${YELLOW}Stopping Server gracefully...${NC}"
    _do_stop_server
    echo -e "${GREEN}Server stopped.${NC}"
    read -p "Press [Enter] to return to menu..."
}

# --- 5. View Console / Logs ---
view_console() {
    if is_service_installed; then
        echo -e "${CYAN}Tailing system log ($LOG_FILE). Press CTRL+C to exit!${NC}"
        sleep 2
        sudo tail -f $LOG_FILE
    else
        if sudo -u $STEAM_USER tmux has-session -t $SESSION_NAME 2>/dev/null; then
            echo -e "${CYAN}Attaching to server console. Press CTRL+B then D to detach!${RED}CTRL+C will stop the server!${NC}"
            sleep 2
            sudo -u $STEAM_USER tmux attach-session -t $SESSION_NAME
        else
            echo -e "${RED}Server is not running in tmux.${NC}"
            read -p "Press [Enter] to return to menu..."
        fi
    fi
}

# --- 6. Backup Saves ---
backup_saves() {
    ensure_steam_user
    echo -e "${CYAN}Starting Backup...${NC}"
    
    local RESULT=$(_do_backup_saves "RSDragonwilds_Save")
    
    if [ -n "$RESULT" ]; then
        echo -e "${GREEN}Backup successfully created at:${NC}\n$RESULT"
    else
        echo -e "${RED}No save data found! Start the server at least once.${NC}"
    fi
    read -p "Press [Enter] to return to menu..."
}

# --- 7. Restore Backup ---
restore_backup() {
    ensure_steam_user
    
    # Gather backup files as the steam user so permission isn't denied
    local BACKUPS=()
    if sudo -u $STEAM_USER test -d "$BACKUP_DIR"; then
        mapfile -t BACKUPS < <(sudo -i -u $STEAM_USER find "$BACKUP_DIR" -maxdepth 1 -name "*.tar.gz" -type f | sort -r)
    fi

    if [ ${#BACKUPS[@]} -eq 0 ] || [ -z "${BACKUPS[0]}" ]; then
        echo -e "${RED}No backups found in $BACKUP_DIR.${NC}"
        read -p "Press [Enter] to return to menu..."
        return
    fi

    echo -e "${CYAN}Available Backups:${NC}"
    PS3=$(echo -e "${YELLOW}Select the number of the backup to restore(or 0 to cancel): ${NC}")
    
select TARGET_BACKUP in "${BACKUPS[@]}"; do
        # Check raw user input for exactly '0'
        if [[ "$REPLY" == "0" ]]; then
            echo -e "${YELLOW}Restore cancelled. Returning to menu...${NC}"
            sleep 1
            return
        elif [ -n "$TARGET_BACKUP" ]; then
            echo -e "\n${CYAN}You selected: $(basename "$TARGET_BACKUP")${NC}"
            break
        else
            echo -e "${RED}Invalid selection. Enter a valid number or 0 to cancel.${NC}"
        fi
    done

    # 1. Stop the server
    echo -e "${YELLOW}Stopping server to safely alter save files...${NC}"
    _do_stop_server

    # 2. Create Safety Backup
    echo -e "${YELLOW}Creating a safety backup of your CURRENT data...${NC}"
    local SAFETY_BACKUP=$(_do_backup_saves "PreRestore_Safety")
    if [ -n "$SAFETY_BACKUP" ]; then
        echo -e "${GREEN}Safety backup created: $SAFETY_BACKUP${NC}"
    else
        echo -e "${YELLOW}No current save data found. Skipping safety backup.${NC}"
    fi

    # 3. Restore Selected Backup
    echo -e "${CYAN}Restoring from archive...${NC}"
    sudo -H -u $STEAM_USER mkdir -p "$SERVER_DIR/RSDragonwilds/Saved"
    
    # Remove current saves to prevent merging ghost files
    sudo -H -u $STEAM_USER rm -rf "$SAVE_DIR"
    
    # Extract the backup
    sudo -H -u $STEAM_USER tar -xzf "$TARGET_BACKUP" -C "$SERVER_DIR/RSDragonwilds/Saved"
    
    echo -e "${GREEN}Restore complete! You can now start the server.${NC}"
    read -p "Press [Enter] to return to menu..."
}
# --- 8. Edit Configuration ---
edit_config() {
    # Use sudo to check if the file exists as the steam user
    if sudo -u $STEAM_USER test -f "$CONFIG_FILE"; then
        sudo -H -u $STEAM_USER nano "$CONFIG_FILE"
        echo -e "${GREEN}Configuration updated! Remember to restart the server.${NC}"
    else
        echo -e "${RED}Config file not found! Please Install/Update the server first.${NC}"
    fi
    read -p "Press [Enter] to return to menu..."
}
# --- 9. Build Systemd Service ---
build_service() {
    ensure_steam_user
    echo -e "${YELLOW}Building Systemd Service...${NC}"
    
    sudo touch $LOG_FILE
    sudo chown $STEAM_USER:$STEAM_USER $LOG_FILE

    cat <<EOF | sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null
[Unit]
Description=Dragonwilds Dedicated Server
After=network.target

[Service]
Type=simple
User=$STEAM_USER
WorkingDirectory=/home/$STEAM_USER/dragonwilds_server/RSDragonwilds/Binaries/Linux
ExecStart=/home/$STEAM_USER/dragonwilds_server/RSDragonwilds/Binaries/Linux/RSDragonwildsServer-Linux-Shipping -log
Restart=always
RestartSec=5
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

# 1. Stop the server
    echo -e "${YELLOW}Stopping server.....${NC}"
    _do_stop_server

# 2. Load the changes and start the server
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl start $SERVICE_NAME
    echo -e "${GREEN}Service '$SERVICE_NAME' installed, started, and enabled to start on boot!${NC}"
    read -p "Press [Enter] to return to menu..."
}

# 10. Configure Log Rotation
configure_logrotation() {
    echo -e "${CYAN}--- Configure Log Rotation ---${NC}"
    echo -e "This will manage /var/log/dragonwilds.log and internal game logs."
    
    # Prompt for max size
    read -p "Enter maximum log size before rotation (e.g., 50M, 500M, 1G) [Default: 100M]: " input_size
    LOG_SIZE=${input_size:-100M}
    
    # Prompt for retention
    read -p "Enter number of old log archives to keep [Default: 5]: " input_keep
    LOG_KEEP=${input_keep:-5}

    echo -e "${YELLOW}Writing logrotate configuration...${NC}"
    
    # Create the logrotate config file
    cat <<EOF | sudo tee "$LOGROTATE_CONF" > /dev/null
$LOG_FILE
$GAME_LOG_DIR/*.log {
    su root root
    size $LOG_SIZE
    rotate $LOG_KEEP
    copytruncate
    compress
    delaycompress
    missingok
    notifempty
}
EOF

    # Verify logrotate syntax
    if sudo logrotate -d "$LOGROTATE_CONF" > /dev/null 2>&1; then
        echo -e "${GREEN}Log rotation successfully configured!${NC}"
        echo -e "Rules applied: Rotate at ${CYAN}$LOG_SIZE${NC}, keeping ${CYAN}$LOG_KEEP${NC} backups."
    else
        echo -e "${RED}Warning: logrotate encountered an issue verifying the config.${NC}"
    fi
    
    read -p "Press [Enter] to return to menu..."
}


# 11. Configure Automated Updates
configure_autoupdate() {
    echo -e "${CYAN}--- Configure Automated Updates ---${NC}"
    echo -e "This will check the Steam Web API daily and update only if a new build is detected."
    read -p "Enter time to check for updates (24h format, e.g., 04:00) [Default: 04:00]: " input_time
    CHECK_TIME=${input_time:-04:00}
    
    SCRIPT_PATH=$(realpath "$0")

    # Build the executing service
    cat <<EOF | sudo tee /etc/systemd/system/dragonwilds-updater.service > /dev/null
[Unit]
Description=Dragonwilds Update Checker
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH --check-updates
EOF

    # Build the timer
    cat <<EOF | sudo tee /etc/systemd/system/dragonwilds-updater.timer > /dev/null
[Unit]
Description=Timer for Dragonwilds Update Checker

[Timer]
OnCalendar=*-*-* $CHECK_TIME:00
RandomizedDelaySec=10m
Persistent=true

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now dragonwilds-updater.timer
    echo -e "${GREEN}Update timer enabled! The server will check the API daily at roughly $CHECK_TIME.${NC}"
    read -p "Press [Enter] to return to menu..."
}
# --- Main Menu Loop ---
check_deps
ensure_steam_user

while true; do
    display_header
    
    # Determine Status
    if is_service_installed; then
        if systemctl is-active --quiet $SERVICE_NAME; then
            STATUS="${GREEN}RUNNING (Systemd)${NC}"
        else
            STATUS="${RED}STOPPED (Systemd)${NC}"
        fi
    else
        if sudo -u $STEAM_USER tmux has-session -t $SESSION_NAME 2>/dev/null; then
            STATUS="${GREEN}RUNNING (Tmux)${NC}"
        else
            STATUS="${RED}STOPPED (Tmux)${NC}"
        fi
    fi
    
    echo -e "Server Status: $STATUS"
    echo "-------------------------------------------------------------------------------"
    echo -e "  ${CYAN}1)${NC} Install / Update Server"
    echo -e "  ${CYAN}2)${NC} Start Server"
    echo -e "  ${CYAN}3)${NC} Stop Server"
    echo -e "  ${CYAN}4)${NC} Restart Server"
    echo -e "  ${CYAN}5)${NC} View Console / Logs"
    echo -e "  ${CYAN}6)${NC} Backup Save Data"
    echo -e "  ${CYAN}7)${NC} Restore Backup"
    echo -e "  ${CYAN}8)${NC} Edit Configuration (DedicatedServer.ini)"
    echo -e "${GREEN}----------------------Automate your server-------------------------------------${NC}"
    echo -e "  ${CYAN}9)${NC} Build Systemd Service (start-on-boot)"
    echo -e "  ${CYAN}10)${NC} Configure Log Rotation"
    echo -e "  ${CYAN}11)${NC} Configure Automated Updates"
    echo "-------------------------------------------------------------------------------"
    echo -e "  ${CYAN}0)${NC} Quit"
    echo "-------------------------------------------------------------------------------"
    read -p "Enter your choice [1-12]: " choice
    
    case $choice in
        1) install_update_server ;;
        2) start_server ;;
        3) stop_server ;;
        4) _do_stop_server; sleep 2; start_server ;;
        5) view_console ;;
        6) backup_saves ;;
        7) restore_backup ;;
        8) edit_config ;;
        9) build_service ;;
        10) configure_logrotation ;;
        11) configure_autoupdate ;;
        0) clear; 
            echo -e "${CYAN}Wise Old Man:${NC} Farewell, adventurer! May your sword stay sharp and your bank stay organized."
            echo -e "Now off you go, I have some completely lawful business to attend to in Draynor Village...\n"
            exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
    esac
done