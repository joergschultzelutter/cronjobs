#!/bin/zsh

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

SRC="com.moneymoney-app.retail"
SRC_DIR="/Users/jsl/Library/Containers"
PROJECT_NAME="MoneyMoney"
ROOT_DIR="/Users/jsl/Documents/Backups"
BACKUP_DIR=$ROOT_DIR/$PROJECT_NAME
CLOUD_BACKUP_TEMP=$ROOT_DIR/.cloud
BACKUP_RETENTION=15
BACKUP_RETENTION_CLOUD=2
AWK_COMMAND="NR>"$BACKUP_RETENTION
AWK_COMMAND_CLOUD="NR>"$BACKUP_RETENTION_CLOUD
PASSPHRASE="REPLACE_WITH_CORRECT_PASSWORD"
MACPORTS_PATH=/opt/local/bin

DATE=`date +"%Y%m%d"`

if [ ! -f "$MACPORTS_PATH/7z" ]; then
	logger Cannot create backup - 7z command not found!
	#Sofern nicht Root, dann Notification an Nutzer
	if [ "$EUID" -ne 0 ]; then
		osascript -e 'display notification "Cannot create backup - 7z command not found!" with title "Cron job report"' > /dev/null 2>&1
	fi
fi

#backup-Dir anlegen, falls nicht vorhanden
if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p $BACKUP_DIR
fi

#cloud-backup-temp anlegen, falls nicht vorhanden
if [ ! -d "$CLOUD_BACKUP_TEMP/$PROJECT_NAME" ]; then
	mkdir -p $CLOUD_BACKUP_TEMP/$PROJECT_NAME
fi

#Archiv erstellen
tar -cf $BACKUP_DIR/$PROJECT_NAME-$DATE.tar -C $SRC_DIR $SRC > /dev/null

#tar-archiv in 7z einpacken (lokale Kopie ohne Passwort)
#zunächst bestehendes Archiv ggf. weglöschen
if [ -f "$BACKUP_DIR/$PROJECT_NAME-$DATE.7z" ]; then
        rm $BACKUP_DIR/$PROJECT_NAME-$DATE.7z > /dev/null
fi

#nun das Archiv normal ohne Passwort einpacken
7z a -t7z -mx=9 $BACKUP_DIR/$PROJECT_NAME-$DATE.7z $BACKUP_DIR/$PROJECT_NAME-$DATE.tar > /dev/null

#jetzt das tar-archiv für die Cloud erstellen; wird gesondert gesichert
#zunächst bestehendes Archiv ggf. weglöschen
if [ -f "$CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z" ]; then
        rm $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z > /dev/null
fi

#nun das gleiche Archiv gesondert geschützt in das Cloudvereichnis stellen
7z a -t7z -mx=9 -mhe=on -p$PASSPHRASE $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z $BACKUP_DIR/$PROJECT_NAME-$DATE.tar > /dev/null

#sofern root: anderen Nutzer zuweisen
if [ "$EUID" -eq 0 ]; then
	chown jsl:staff $BACKUP_DIR/$PROJECT_NAME-$DATE.7z $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z
fi

#generell: Leserechte einschränken
chmod u=rw,go-rwx $BACKUP_DIR/$PROJECT_NAME-$DATE.7z $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z

#Löschen eventueller alter Kopien im Cloudverzeichnis
cd $CLOUD_BACKUP_TEMP/$PROJECT_NAME
ls -t | awk $AWK_COMMAND_CLOUD | xargs rm -f

#das work-tar-file löschen
rm $BACKUP_DIR/$PROJECT_NAME-$DATE.tar

# im eigentlichen Backup-Verzeichnis nur die letzten 15 Dateien behalten; der Rest wird gelöscht
cd $BACKUP_DIR
ls -t | awk $AWK_COMMAND | xargs rm -f

#syslog-Nachricht einstellen
logger Have created MoneyMoney backup on date $DATE. Backup retention time is set to $BACKUP_RETENTION files.

#sofern nicht root, dann per osascript Notification an den User erstellen
if [ "$EUID" -ne 0 ]; then
        osascript -e 'display notification "Have created MoneyMoney database backup" with title "Cron job report"' > /dev/null 2>&1
fi

