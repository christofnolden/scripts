#!/bin/bash

# Liste der Hexcodes, die überwacht werden sollen (pro Zeile ein Hexcode)
HEXCODES=()
while IFS= read -r line; do
  HEXCODES+=("$line")
done < /srv/adsb/adsb-hexcodes.txt

# Pfad zur aircraft.json-Datei
JSON_URL="http://XXX.XXX.XXX.XXX/tar1090/data/aircraft.json"

# Datei, um den letzten Versandzeitpunkt pro Hexcode zu speichern
LAST_SENT_FILE="/srv/adsb/adsb-last-sent.txt"

# API-Token für Pushover
PUSHOVER_TOKEN="XXX"
PUSHOVER_USER="XXX"

# Funktion zum Bereinigen der last_sent.txt-Datei
clean_last_sent_file() {
    while read -r line; do
        HEX=$(echo "$line" | awk '{print $1}')
        LAST_SENT=$(echo "$line" | awk '{print $2}')
        CURRENT_TIME=$(date +%s)
        ELAPSED_TIME=$((CURRENT_TIME - LAST_SENT))

        if [ "$ELAPSED_TIME" -ge 86400 ]; then
            sed -i "/$HEX/d" "$LAST_SENT_FILE"
        fi
    done < "$LAST_SENT_FILE"
}

# Endlosschleife mit 20-sekündiger Verzögerung zwischen den Durchläufen
while true; do
    # Schleife über die Hexcodes
    for HEXCODE in "${HEXCODES[@]}"; do
        # Überprüfen, ob der Hexcode in der aircraft.json gefunden wird
        if JSON=$(curl -s --header "Cache-Control: no-cache" "$JSON_URL" | jq --arg hex "$HEXCODE" -r '.aircraft[] | select(.hex | ascii_upcase == $hex)'); then
            # Extrahieren von r_dst-Wert
            RDST=$(echo "$JSON" | jq -r '.r_dst')

            # Überprüfen, ob der r_dst-Wert eine gültige Zahl ist und kleiner als 30 ist
            if [[ "$RDST" =~ ^[0-9.]+$ ]] && (( $(echo "$RDST < 30" | bc -l) )); then
                # Überprüfen, ob der Hexcode vor mindestens 5 Minuten gesendet wurde
                LAST_SENT=$(grep "$HEXCODE" "$LAST_SENT_FILE" | awk '{print $2}')
                CURRENT_TIME=$(date +%s)
                ELAPSED_TIME=$((CURRENT_TIME - LAST_SENT))

                if [ "$ELAPSED_TIME" -ge 600 ]; then
                    # Hexcode wurde seit 10 Minuten nicht mehr gesendet, Benachrichtigung senden
                    LINK="https://globe.adsbexchange.com/?icao=$HEXCODE"
                    MESSAGE="$HEXCODE - RDST: $RDST - $LINK"
                    curl -s --form-string "token=$PUSHOVER_TOKEN" --form-string "user=$PUSHOVER_USER" --form-string "message=$MESSAGE" https://api.pushover.net/1/messages.json

                    # Aktualisierten Zeitpunkt in der Datei speichern
                    sed -i "/$HEXCODE/d" "$LAST_SENT_FILE"
                    echo "$HEXCODE $(date +%s)" >> "$LAST_SENT_FILE"
                fi
            fi
        fi
    done

    # Bereinigen der last_sent.txt-Datei
    clean_last_sent_file

    sleep 20
done
