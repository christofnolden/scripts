# ADSB Alert Script by Callsign

Dieses Script durchsucht die Aircraft.json von dump1090. Es vergleicht den Inhalt nicht mit statischen Hexcodes aus einer Liste, sondern sucht nach bestimmten Callsign-Patterns.
Das macht das Script äußerst flexibel, da alle interessanten Flüge somit immer gefunden werden, auch wenn eine Transponder Kennung geändert wird.

## Hintergrund

Die Suche nach statischen Transpondern Hexcodes ist bei Maschinen der Bundeswehr nicht mehr möglich, da sie im Rahmen Mode S Adressvergabe mit agilem Entwicklungsframework mit unregelmäßigen Adressen fliegen. SAR Hubschrauber lassen sich somit nicht mehr eindeutig zuordnen.
Bei der Suche nach Callsigns werden diese Transponder allerdings gefunden.

## Installation

### Voraussetzungen

Als Voraussetzung wird jq benötigt:
```bash
apt-get install jq
```

### Systemd Service einrichten

Das fertige Script kann als Linux Dienst installiert werden:

1. Service-Datei erstellen:
```bash
nano /etc/systemd/system/adsb-alert-callsign.service
```

2. Folgenden Inhalt einfügen:
```ini
[Unit]
Description=ADSB Alert Service (Callsign Version)
After=network.target

[Service]
ExecStart=/bin/bash /srv/adsb/adsb-alert-callsign.sh
Restart=on-failure
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

3. Berechtigungen setzen:
```bash
chmod 644 /etc/systemd/system/adsb-alert-callsign.service
```

4. Service aktivieren:
```bash
systemctl enable adsb-alert-callsign.service
```
