#!/bin/bash

# Farben definieren
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

USER_NAME=$(whoami)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
NEW_SESSION_NAME="${USER_NAME}_${TIMESTAMP}"

function list_sessions() {
    echo -e "${CYAN}Aktuelle tmux Sessions:${RESET}"
    tmux ls 2>/dev/null || echo -e "${YELLOW}Keine aktiven Sessions gefunden.${RESET}"
    echo
}

function attach_session() {
    read -p "$(echo -e ${BLUE}Gib den Namen der Session ein, die du fortführen willst:${RESET} )" session_name
    tmux attach-session -t "$session_name"
}

function create_session() {
    echo -e "${GREEN}Starte neue Session: $NEW_SESSION_NAME${RESET}"
    sleep 1
    tmux new-session -s "$NEW_SESSION_NAME"
}

function show_menu() {
    clear
    echo -e "${MAGENTA}===== Tmux Session Manager =====${RESET}"
    echo -e "${YELLOW}1)${RESET} Vorhandene Session fortführen"
    echo -e "${YELLOW}2)${RESET} Neue Session starten"
    echo -e "${YELLOW}3)${RESET} Beenden"
    echo
    list_sessions
    echo -ne "${BLUE}Wähle eine Option (1-3): ${RESET}"
    read choice



    case "$choice" in
        1)
            attach_session
            ;;
        2)
            create_session
            ;;
        3)
            echo -e "${RED}Beende das Script.${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Ungültige Eingabe.${RESET}"
            sleep 1
            show_menu
            ;;
    esac
}

function usage_tip() {
    echo
    echo -e "${CYAN}Hinweis:${RESET}"
    echo -e "Um die tmux-Session zu verlassen, ohne sie zu beenden,"
    echo -e "drücke ${YELLOW}Strg + b${RESET} gefolgt von ${YELLOW}d${RESET} (für detach)."
    echo -e "Du kannst dann später mit diesem Script wieder verbinden."
    echo
    echo -ne "${BLUE}Drücke Enter, um fortzufahren...${RESET}"
    read

}

# Hauptablauf
usage_tip
while true; do
    show_menu
done
