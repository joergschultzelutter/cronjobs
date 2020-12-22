#!/bin/bash

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

SRC="/Users/jsl/Keepass/Passwords.k*"
BACKUP_DIR="/Users/jsl/Documents/KeepassBackups"
PROJECT_NAME="Keepass"
BACKUP_RETENTION=15
PLUS='+'

DATE=`date +"%Y%m%d"`

if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p $BACKUP_DIR
fi

zip -9 -j -r $BACKUP_DIR/$PROJECT_NAME-$DATE.zip $SRC > /dev/null
cd $BACKUP_DIR/
find . -name $PROJECT_NAME'*' -mtime $PLUS$BACKUP_RETENTION -exec rm {} \;
logger Have created Keepass backup on date $DATE. Backup retention time is set to $BACKUP_RETENTION days.

if [ "$EUID" -ne 0 ]; then
        osascript -e 'display notification "Have created Keepass database backup" with title "Cron job report"' > /dev/null 2>&1
fi

