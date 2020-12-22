#!/bin/zsh

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

ROOT_DIR="/Users/jsl/Documents/Backups"
CLOUD_BACKUP_TEMP=$ROOT_DIR/.cloud
CLOUD_BACKUP_ROOT_DIR="/Users/jsl/Google Drive/.cron"
ARCHIV_VOLNAME="google_drive_cron_folder"
ARCHIV_DRIVENAME=".backup.sparseimage"
PASSPHRASE="REPLACE_WITH_CORRECT_PASSWORD"
MACPORTS_PATH=/opt/local/bin

DATE=`date`

if [ ! -f "$MACPORTS_PATH/7z" ]; then
	logger Cannot create backup - 7z command not found!
	#Sofern nicht Root, dann Notification an Nutzer
	if [ "$EUID" -ne 0 ]; then
		osascript -e 'display notification "Cannot create backup - 7z command not found!" with title "Cron job report"' > /dev/null 2>&1
	fi
fi

#cloud-backup-temp anlegen, falls nicht vorhanden. Sollte immer da sein - ansonsten ist das Backup halt leer
if [ ! -d "$CLOUD_BACKUP_TEMP/$PROJECT_NAME" ]; then
	mkdir -p $CLOUD_BACKUP_TEMP/$PROJECT_NAME
fi

#cloud-backup-temp anlegen, falls nicht vorhanden
if [ ! -d "$CLOUD_BACKUP_ROOT_DIR" ]; then
	mkdir "$CLOUD_BACKUP_ROOT_DIR"
fi

cd $CLOUD_BACKUP_ROOT_DIR

if [ ! -f "$ARCHIV_DRIVENAME" ]; then
	echo -n $PASSPHRASE|hdiutil create -fs HFS+ -type SPARSE -layout GPTSPUD -quiet -size 1g -nospotlight -volname $ARCHIV_VOLNAME -encryption AES-256 -stdinpass $ARCHIV_DRIVENAME
fi

echo -n $PASSPHRASE|hdiutil attach -quiet -stdinpass $ARCHIV_DRIVENAME

if [ -d "/Volumes/$ARCHIV_VOLNAME" ]; then
	rm -r /Volumes/$ARCHIV_VOLNAME/Enpass 2>/dev/null
	rm -r /Volumes/$ARCHIV_VOLNAME/MoneyMoney 2>/dev/null
	rm /Volumes/$ARCHIV_VOLNAME/version.txt 2>/dev/null

	echo Version: $DATE >/Volumes/$ARCHIV_VOLNAME/version.txt
	cp -r $CLOUD_BACKUP_TEMP/Enpass /Volumes/$ARCHIV_VOLNAME 2>/dev/null
	cp -r $CLOUD_BACKUP_TEMP/MoneyMoney /Volumes/$ARCHIV_VOLNAME 2>/dev/null
	
	hdiutil detach -quiet "/Volumes/$ARCHIV_VOLNAME"
	sleep 1
	echo -n $PASSPHRASE|hdiutil compact -quiet -stdinpass $ARCHIV_DRIVENAME
fi

#syslog-Nachricht einstellen
logger Have created Cloud backup on date $DATE.

#sofern nicht root, dann per osascript Notification an den User erstellen
if [ "$EUID" -ne 0 ]; then
        osascript -e 'display notification "Have created Cloud backup" with title "Cron job report"' > /dev/null 2>&1
fi

