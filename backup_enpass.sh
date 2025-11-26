#!/bin/zsh
#
# Cronjob zum Backup der Enpass-Datenbank
# Von den Backup-Archiven werden jeweils nur die letzten 15 Backups behalten; der Rest wird gelöscht
#
# Ab MacOS Catalina notwendig: System Preferences - Privacy & Security - Full Disk Access -> /usr/sbin/cron hinzufügen
#
# Entpacken der Dateien via 7z x -p"<Passwort>"
#
# Autor: Jörg Schultze-Lutter,20255
#
# Falls sich tar-Archive nicht entpacken lassen: gnu-tar via Macports installieren und dann erneut probieren


#
# Crontab-Settings
#
# *     *     *     *     *  command
# -     -     -     -     -
# |     |     |     |     |
# |     |     |     |     +----- weekday (0 - 7) (Sunday = 0 and 7)
# |     |     |     +------- month (1 - 12)
# |     |     +--------- day (1 - 31)
# |     +----------- hour (0 - 23)
# +------------- minute (0 - 59)
#0 22 * * * /Users/jsl/cronjobs/backup_enpass.sh

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

SRC="Backups"
SRC_DIR1="/Users/jsl/Library/Containers/in.sinew.Enpass-Desktop/Data/Documents/Backups"
SRC_DIR2="/Users/jsl/WebDAV/Enpass"
PROJECT_NAME="Enpass"
ROOT_DIR="/Users/jsl/Documents/Backups"
BACKUP_DIR=$ROOT_DIR/$PROJECT_NAME
CLOUD_BACKUP_TEMP=$ROOT_DIR/.cloud
MACPORTS_PATH=/opt/local/bin

FAKE_DIR="Library/Containers/in.sinew.Enpass-Desktop/Data/Documents/Backups"
TEMP_DIR=".tmp"
BACKUP_RETENTION=15
BACKUP_RETENTION_CLOUD=2
AWK_COMMAND="NR>"$BACKUP_RETENTION
AWK_COMMAND_CLOUD="NR>"$BACKUP_RETENTION_CLOUD

DATE=`date +"%Y%m%d"`

SCRIPT_DIR="/Users/jsl/cronjobs"
PWFILE="$SCRIPT_DIR/cronpw.txt"
. "$SCRIPT_DIR/get_password.sh"

main() {
  if [ ! -f "$MACPORTS_PATH/7z" ]; then
	  logger Cannot create backup - 7z command not found!
	  #Sofern nicht Root, dann Notification an Nutzer
	  if [ "$EUID" -ne 0 ]; then
		  osascript -e 'display notification "Cannot create backup - 7z command not found!" with title "Enpass Backup"' > /dev/null 2>&1
	  fi
	  exit 1
  fi

  #Zielverzeichnis erstellen, falls es nicht existiert
  if [ ! -d "$BACKUP_DIR" ]; then
          mkdir -p $BACKUP_DIR
  fi

  #cloud-backup-temp anlegen, falls nicht vorhanden
  if [ ! -d "$CLOUD_BACKUP_TEMP/$PROJECT_NAME" ]; then
	  mkdir -p $CLOUD_BACKUP_TEMP/$PROJECT_NAME
  fi

  #temporäres Verzeichnis erstellen, falls es nicht existiert
  if [ -d "$BACKUP_DIR/$TEMP_DIR" ]; then
	  rm -r $BACKUP_DIR/$TEMP_DIR > /dev/null
  fi

  local schluessel="PASSWORD_ENPASS_BACKUPS"
  local MEINPASSWORT

  MEINPASSWORT=$(get_password "$schluessel" "$PWFILE")
  case $? in
    0) : ;;
    1) logger "Password key \"$schluessel\" not found in $PWFILE."; osascript -e 'display notification "Key not found in password file" with title "Enpass Backup"' > /dev/null 2>&1;exit 1 ;;
    2) # unsichere Rechte oder Stat-Fehler
       logger "Insecure password file $PWFILE or other error has occurred."; osascript -e 'display notification "Insecure password file or other error" with title "Enpass Backup"' > /dev/null 2>&1;exit 1 ;;
    *) exit 1 ;;
  esac

  #Kopieren der letzten drei aktiven Backup-Files
  mkdir -p $BACKUP_DIR/$TEMP_DIR/$FAKE_DIR
  ls -t -1 $SRC_DIR1 | sed '3q'|xargs -I{} cp $SRC_DIR1/{} $BACKUP_DIR/$TEMP_DIR/$FAKE_DIR

  #Kopieren des Enpass-Verzeichnisses incl. Key
  cp -R $SRC_DIR2 $BACKUP_DIR/$TEMP_DIR

  #Erstellen des finalen tar-Archivs
  tar --no-xattrs -cf $BACKUP_DIR/$PROJECT_NAME-$DATE.tar -C $BACKUP_DIR/$TEMP_DIR/ . 

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
  7z a -t7z -mx=9 -mhe=on -p"$MEINPASSWORT" $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z $BACKUP_DIR/$PROJECT_NAME-$DATE.tar > /dev/null

  #sofern root: anderen Nutzer zuweisen
  if [ "$EUID" -eq 0 ]; then
          chown jsl:staff $BACKUP_DIR/$PROJECT_NAME-$DATE.7z $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z
  fi

  #generell: Leserechte einschränken
  chmod u=rw,go-rwx $BACKUP_DIR/$PROJECT_NAME-$DATE.7z $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z

  #Löschen eventueller alter Kopien im Cloudverzeichnis
  cd $CLOUD_BACKUP_TEMP/$PROJECT_NAME
  ls -t | awk $AWK_COMMAND_CLOUD | xargs rm -f

  #temporäre Datei löschen
  rm $BACKUP_DIR/$PROJECT_NAME-$DATE.tar

  #Löschen des temporären Verzeichnisses
  if [ -d "$BACKUP_DIR/$TEMP_DIR" ]; then
	  rm -r $BACKUP_DIR/$TEMP_DIR > /dev/null
  fi

  #Alle Dateien im Backup-Verzeichnis bis auf die letzten 15 Dateien weglöschen
  cd $BACKUP_DIR
  ls -t | awk $AWK_COMMAND | xargs rm -f

  #Syslog schreiben
  logger Have created Enpass backup on date $DATE. Backup retention time is set to $BACKUP_RETENTION files.

  #Sofern nicht Root, dann Notification an Nutzer
  if [ "$EUID" -ne 0 ]; then
	  osascript -e 'display notification "Have created Enpass database backup" with title "Enpass Backup"' > /dev/null 2>&1
  fi
}

main "$@"
