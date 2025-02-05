#!/bin/bash

# Parameter Konfiguration
AIRCRAFT_JSON="URL-OF-DUMP1090-AIRCRAFT-JSON/aircraft.json"
PUSHOVER_USER="XXX"  # Pushover User Key
PUSHOVER_TOKEN="XXX" # Pushover App Token
TEMP_FILE="/tmp/aircraft_notifications.txt" # Zwischenspeicherung der gefundenen Aircraft zwecks Cooldown Alert
SEARCH_PATTERNS=("CHX" "LIFELN" "RESQ" "JOKER" "SAREX" "AIRESC" "HUMMEL" "NATO" "ESSO" "SONIC" "MRPHY" "DUKE") # CHX,LIFELN,RESQ,AIRESC=Rettungshubschrauber;HUMMEL=Polizei NRW;NATO,ESSO,SONIC,MRPHY,DUKE=Militär
NOTIFICATION_COOLDOWN=600  # 10 Minuten in Sekunden
MAX_DISTANCE=32  # Maximale Entfernung in NM
DEBUG=false  # Debug-Ausgaben true oder false

# Position des ADSB-Empfängers (wird von tar1090 verwendet)
MY_LAT="XX.XXXXXX"  # Breitengrad-Koordinate
MY_LON="X.XXXXXX"  # Längengrad-Koordinate

# Erstelle temp file falls nicht vorhanden
touch "$TEMP_FILE"

debug_print() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1"
    fi
}

while true; do
    # Hole aktuelle Aircraft Daten
    AIRCRAFT_DATA=$(curl -s "$AIRCRAFT_JSON")
    if [ -z "$AIRCRAFT_DATA" ]; then
        debug_print "Keine Daten von $AIRCRAFT_JSON empfangen"
        sleep 30
        continue
    fi
    
    debug_print "Aircraft Daten empfangen, suche nach Flugzeugen..."
    
    # Debug: Zeige alle Aircraft mit Callsign und Entfernung
    debug_print "Alle gefundenen Aircraft mit Callsign und Entfernung:"
    echo "$AIRCRAFT_DATA" | jq -r '.aircraft[] | select(.flight != null and .r_dst != null) | "\(.flight | gsub("\\s+$"; "")) - \(.r_dst)NM"' | while read -r flight_info; do
        debug_print "Gefunden: $flight_info"
    done
    
    # Debug: Zeige Aircraft innerhalb der Distanz
    debug_print "Aircraft innerhalb von ${MAX_DISTANCE}km:"
    echo "$AIRCRAFT_DATA" | jq -r '.aircraft[] | select(.flight != null and .r_dst != null and .r_dst <= '"$MAX_DISTANCE"') | "\(.flight | gsub("\\s+$"; "")) - \(.r_dst)NM"' | while read -r flight_info; do
        debug_print "In Reichweite: $flight_info"
    done
    
    # Extrahiere alle relevanten Aircraft und verarbeite sie
    echo "$AIRCRAFT_DATA" | jq -r '.aircraft[] | select(.flight != null and .r_dst != null and .r_dst <= '"$MAX_DISTANCE"') | {flight: (.flight | gsub("\\s+$"; "")), hex: .hex, r_dst: .r_dst} | @json' | while read -r line; do
        FLIGHT=$(echo "$line" | jq -r '.flight')
        HEX=$(echo "$line" | jq -r '.hex')
        DISTANCE=$(echo "$line" | jq -r '.r_dst')
        
        debug_print "Check Aircraft: $FLIGHT (HEX: $HEX) in ${DISTANCE}NM Entfernung"
        
        # Prüfe ob das Flight-Callsign mit einem der Suchmuster übereinstimmt
        for pattern in "${SEARCH_PATTERNS[@]}"; do
            if [[ "${FLIGHT}" =~ ^${pattern} ]]; then
                debug_print "Match gefunden für Pattern $pattern: $FLIGHT"
                
                # Prüfe ob für dieses Aircraft kürzlich eine Benachrichtigung gesendet wurde
                LAST_NOTIFICATION=$(grep "^${HEX}:" "$TEMP_FILE" 2>/dev/null | cut -d: -f2)
                CURRENT_TIME=$(date +%s)
                
                if [ -z "$LAST_NOTIFICATION" ] || [ $((CURRENT_TIME - LAST_NOTIFICATION)) -ge $NOTIFICATION_COOLDOWN ]; then
                    # Erstelle Nachricht mit dem Callsign - Hexcode - Entfernung und einem Link zu ADSB-Exchange
                    MESSAGE="$FLIGHT - $HEX - ${DISTANCE}NM
https://globe.adsbexchange.com/?icao=$HEX"
                    
                    debug_print "Sende Pushover Nachricht: $MESSAGE"
                    
                    # Sende Pushover Benachrichtigung
                    PUSH_RESPONSE=$(curl -s \
                        --form-string "token=$PUSHOVER_TOKEN" \
                        --form-string "user=$PUSHOVER_USER" \
                        --form-string "message=$MESSAGE" \
                        https://api.pushover.net/1/messages.json)
                    
                    debug_print "Pushover Antwort: $PUSH_RESPONSE"
                    
                    # Aktualisiere Zeitstempel für dieses Aircraft
                    sed -i "/^${HEX}:/d" "$TEMP_FILE"
                    echo "${HEX}:${CURRENT_TIME}" >> "$TEMP_FILE"
                else
                    debug_print "Benachrichtigung für $FLIGHT wurde kürzlich schon gesendet"
                fi
                break
            fi
        done
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
    
    debug_print "Warte 30 Sekunden bis zum nächsten Durchlauf..."
    sleep 30
done 
