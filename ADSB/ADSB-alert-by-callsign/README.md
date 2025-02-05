Dieses Script durchsucht die Aircraft.json von dump1090. Es vergleicht den Inhalt nicht mit statischen Hexcodes aus einer Liste, sondern sucht nach bestimmten Callsign-Patterns.
Das macht das Script äußerst flexibel, da alle Interessanten Flüge somit immer gefunden werden, auch wenn eine Transponder Kennung geändert wird.

Die Suche nach statischen Transpondern Hexcodes ist bei Maschinen der Bundeswehr nicht mehr möglich, da sie im Rahmen Mode S Adressvergabe mit agilem Entwicklungsframework mit unregelmäßigen Adressen fliegen. SAR Hubschrauber lassen sich somit nicht mehr eindeutig zuordnen.
Bei der Suche nach Callsigns werden diese Transponder allerdings gefunden.


Als Voraussetzung wird jq benötigt:
apt-get install jq

Das fertige Script kann als Linux Dienst installiert werden:
nano /etc/systemd/system/adsb-alert-callsign.service

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

chmod 644 /etc/systemd/system/adsb-alert-callsign.service

systemctl enable adsb-alert-callsign.service
