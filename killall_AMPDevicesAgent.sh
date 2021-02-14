#!/bin/bash
killall AMPDevicesAgent 2>/dev/null

#syslog-Nachricht einstellen
logger Have killed any instances of AMPDevicesAgent

#sofern nicht root, dann per osascript Notification an den User erstellen
if [ "$EUID" -ne 0 ]; then
        osascript -e 'display notification "Have killed any instances of AMPDevicesAgent" with title "Cron job report"' > /dev/null 2>&1
fi
