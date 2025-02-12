# ADSB Alert Script

Dieses Script vereint die Suche nach ADSB Hexcodes und Callsigns, welche ich als separate Scripts ebenfalls hier gelistet habe.
Der Vorteil des kombinierten Scripts liegt darin, dass bestimmte interessante Hexcodes von Flügen in einer Textdatei gepflegt werden können und zusätzlich nach gewünschten Callsigns gesucht werden kann.
Dadurch spart man sich den Betrieb von zwei Scripts und man erhält nur eine Benachrichtigung, wenn ein Flug gefunden wird, der sowohl als Hexcode, als auch als Callsign gefunden wird.

Der Aufbau dieser Hexcode Liste sieht folgt aus: Pro Zeile steht ein einzelner Hexcode. Beispiel: 3E0F5F


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
nano /etc/systemd/system/adsb-alert.service
```

2. Folgenden Inhalt einfügen:
```ini
[Unit]
Description=ADSB Alert Service (Combined Version)
After=network.target

[Service]
ExecStart=/bin/bash /srv/adsb/adsb-alert.sh
Restart=on-failure
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

3. Berechtigungen setzen:
```bash
chmod 644 /etc/systemd/system/adsb-alert.service
```

4. Service aktivieren:
```bash
systemctl enable adsb-alert.service
```
