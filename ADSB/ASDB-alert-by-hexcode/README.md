# ADSB Alert Script by Hexcode

Dieses Script durchsucht eine statische Hexcode Liste und sendet einen Alarm Pushover.
Nachteil: Die Hexcode Liste muss stetig gepflegt werden.

Der Aufbau dieser Hexcode Liste sieht folgt aus: Pro Zeile steht ein einzelner Hexcode. Beispiel: 3E0F5F
Zudem ändert die Bundeswehr seit Ende 2024 unregelmäßig die Transponder Adressen ihrer Maschinen. Dadurch ist es unmöglich geworden, die SAR Hubschrauber zu pflegen und eine Benachrichtigung zu erhalten. Bei zivilen Luftfahrtzeugen tritt dies in der Regel nur sehr selten auf.


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
nano /etc/systemd/system/adsb-alert-hexcode.service
```

2. Folgenden Inhalt einfügen:
```ini
[Unit]
Description=ADSB Alert Service (Hexcode Version)
After=network.target

[Service]
ExecStart=/bin/bash /srv/adsb/adsb-alert-hexcode.sh
Restart=on-failure
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

3. Berechtigungen setzen:
```bash
chmod 644 /etc/systemd/system/adsb-alert-hexcode.service
```

4. Service aktivieren:
```bash
systemctl enable adsb-alert-hexcode.service
```
