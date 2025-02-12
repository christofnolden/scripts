#!/bin/bash

# Parameter Konfiguration
AIRCRAFT_JSON="http://XXX.XXX.XXX/tar1090/data/aircraft.json" # Replace with your Hostname or IP
PUSHOVER_USER="XXX" # Replace with your User Key
PUSHOVER_TOKEN="XXX" # Replace with your User Token
TEMP_FILE="/tmp/aircraft_notifications.txt"
SEARCH_PATTERNS=("CHX" "LIFELN" "RESQ" "JOKER" "SAREX" "AIRESC" "HUMMEL" "NATO" "ESSO" "SONIC" "MRPHY" "LIMIT" "DUKE" "SPADE") # The Callsign searchpatterns with wildcard
NOTIFICATION_COOLDOWN=600 # Cooldown in seconds
MAX_DISTANCE=32 # Distance in NM
DEBUG=false

# Position des ADSB-Empfängers
MY_LAT="XX.XXXXXX" # Replace
MY_LON="X.XXXXXX" # Replace

# Liste der Hexcodes einlesen
HEXCODES=()
debug_print "Lese Hexcodes aus /srv/adsb/adsb-hexcodes.txt..."
while IFS= read -r line; do
    # Entferne Leerzeichen und konvertiere zu Kleinbuchstaben
    cleaned_line=$(echo "$line" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
    if [ -n "$cleaned_line" ]; then  # Nur nicht-leere Zeilen hinzufügen
        HEXCODES+=("$cleaned_line")
        debug_print "Hexcode hinzugefügt: $cleaned_line"
    fi
done < /srv/adsb/adsb-hexcodes.txt

# Debug-Ausgabe der geladenen Hexcodes
if [ "$DEBUG" = true ]; then
    echo "[DEBUG] Geladene Hexcodes:"
    printf '[DEBUG] %s\n' "${HEXCODES[@]}"
fi

# Erstelle temp file falls nicht vorhanden
touch "$TEMP_FILE"

debug_print() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1"
    fi
}

send_notification() {
    local HEX=$1
    local FLIGHT=$2
    local DISTANCE=$3
    local SOURCE=$4  # "hexcode" oder "callsign"
    
    MESSAGE="${FLIGHT:+$FLIGHT - }$HEX - ${DISTANCE}NM
https://globe.adsbexchange.com/?icao=$HEX"
    
    debug_print "Sende Pushover Nachricht ($SOURCE): $MESSAGE"
    
    PUSH_RESPONSE=$(curl -s \
        --form-string "token=$PUSHOVER_TOKEN" \
        --form-string "user=$PUSHOVER_USER" \
        --form-string "message=$MESSAGE" \
        https://api.pushover.net/1/messages.json)
    
    debug_print "Pushover Antwort: $PUSH_RESPONSE"
    
    # Aktualisiere Zeitstempel
    sed -i "/^${HEX}:/d" "$TEMP_FILE"
    echo "${HEX}:$(date +%s):${SOURCE}" >> "$TEMP_FILE"
}

while true; do
    # Hole aktuelle Aircraft Daten
    AIRCRAFT_DATA=$(curl -s "$AIRCRAFT_JSON")
    if [ -z "$AIRCRAFT_DATA" ]; then
        debug_print "Keine Daten von $AIRCRAFT_JSON empfangen"
        sleep 30
        continue
    fi
    
    debug_print "Aircraft Daten empfangen, beginne Verarbeitung..."
    
    # Verarbeite alle Aircraft innerhalb der maximalen Distanz
    echo "$AIRCRAFT_DATA" | jq -r '.aircraft[] | select(.r_dst != null and .r_dst <= '"$MAX_DISTANCE"') | {flight: (.flight // "" | gsub("\\s+$"; "")), hex: .hex, r_dst: .r_dst} | @json' | while read -r line; do
        FLIGHT=$(echo "$line" | jq -r '.flight')
        HEX=$(echo "$line" | jq -r '.hex')
        DISTANCE=$(echo "$line" | jq -r '.r_dst')
        
        debug_print "Prüfe Aircraft: $HEX${FLIGHT:+ ($FLIGHT)} in ${DISTANCE}NM Entfernung"
        
        # Prüfe Cooldown
        LAST_NOTIFICATION=$(grep "^${HEX}:" "$TEMP_FILE" 2>/dev/null)
        CURRENT_TIME=$(date +%s)
        
        if [ -n "$LAST_NOTIFICATION" ]; then
            LAST_TIME=$(echo "$LAST_NOTIFICATION" | cut -d: -f2)
            if [ $((CURRENT_TIME - LAST_TIME)) -lt $NOTIFICATION_COOLDOWN ]; then
                debug_print "Cooldown aktiv für $HEX, überspringe..."
                continue
            fi
        fi
        
        # 1. Prüfe zuerst auf Hexcode-Match
        HEXCODE_MATCH=false
        HEX_LOWER=$(echo "$HEX" | tr '[:upper:]' '[:lower:]')
        debug_print "Suche nach Hexcode: $HEX_LOWER in ${#HEXCODES[@]} geladenen Hexcodes"
        for hexcode in "${HEXCODES[@]}"; do
            debug_print "Vergleiche mit Hexcode aus Liste: $hexcode"
            if [[ "${HEX_LOWER}" == "${hexcode}" ]]; then
                debug_print "Hexcode Match gefunden: $HEX (matched with $hexcode)"
                send_notification "$HEX" "$FLIGHT" "$DISTANCE" "hexcode"
                HEXCODE_MATCH=true
                break
            fi
        done
        
        # 2. Wenn kein Hexcode-Match, prüfe auf Callsign-Match
        if [ "$HEXCODE_MATCH" = false ] && [ -n "$FLIGHT" ]; then
            for pattern in "${SEARCH_PATTERNS[@]}"; do
                if [[ "${FLIGHT}" =~ ^${pattern} ]]; then
                    debug_print "Callsign Match gefunden: $FLIGHT"
                    send_notification "$HEX" "$FLIGHT" "$DISTANCE" "callsign"
                    break
                fi
            done
        fi
    done
    
    # Bereinige alte Einträge aus der temporären Datei
    CURRENT_TIME=$(date +%s)
    TEMP_CONTENT=$(cat "$TEMP_FILE")
    echo "$TEMP_CONTENT" | while read -r line; do
        HEX=$(echo "$line" | cut -d: -f1)
        TIMESTAMP=$(echo "$line" | cut -d: -f2)
        if [ $((CURRENT_TIME - TIMESTAMP)) -lt $NOTIFICATION_COOLDOWN ]; then
            echo "$line"
        fi
    done > "${TEMP_FILE}.tmp"
    mv "${TEMP_FILE}.tmp" "$TEMP_FILE"
    
    debug_print "Warte 10 Sekunden bis zum nächsten Durchlauf..."
    sleep 10
done 
