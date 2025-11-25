#!/bin/bash
#
# Cronjob zum Backup der aktuellsten 5 Firefox-Backup-Dateien in einem Archiv
# Von den Backup-Archiven werden jeweils nur die letzten 15 Backups behalten; der Rest wird gelöscht
#
# Ab MacOS Catalina notwendig: System Preferences - Privacy & Security - Full Disk Access -> /usr/sbin/cron hinzufügen 
#
# Entpacken der Dateien via 7z x -p"<Passwort>"
#
# Autor: Jörg Schultze-Lutter, 2025
#

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
#0 22 * * * /Users/jsl/cronjobs/backup_mozilla.sh


PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

# Mozilla-Profil und Username anpassen
MOZILLA_PROFILE="epiacaea.default-release"
USERNAME="jsl"

# Quellverzeichnis
MOZILLA_DIR="/Users"/$USERNAME/"Library/Application Support/Firefox/Profiles"
SRC=$MOZILLA_DIR/$MOZILLA_PROFILE/bookmarkbackups

# Zielverzeichnis und -Projektname
ROOT_DIR="/Users"/$USERNAME/"Documents/Backups"
PROJECT_NAME="Mozilla"
BACKUP_DIR=$ROOT_DIR/$PROJECT_NAME

#Backup-Retention
BACKUP_RETENTION=15
PLUS='+'

MACPORTS_PATH=/opt/local/bin

DATE=`date +"%Y%m%d"`

SCRIPT_DIR="/Users/jsl/cronjobs"
PWFILE="$SCRIPT_DIR/cronpw.txt"
. "$SCRIPT_DIR/get_password.sh"

main() {

  #Test auf Vorhandensein von 7z
  if [ ! -f "$MACPORTS_PATH/7z" ]; then
          logger Cannot create backup - 7z command not found!
	  exit 0
  fi

  #Backup-Dir anlegen, falls nicht vorhanden
  if [ ! -d "$BACKUP_DIR" ]; then
          mkdir -p $BACKUP_DIR
  fi

  local schluessel="PASSWORD_MOZILLA_BACKUPS"
  local MEINPASSWORT

  MEINPASSWORT=$(get_password "$schluessel" "$PWFILE")
  case $? in
    0) : ;;
    1) logger "Password key \"$schluessel\" not found in $PWFILE."; exit 1 ;;
    2) # unsichere Rechte oder Stat-Fehler
       logger "Insecure password file $PWFILE or other error has occurred." exit 1 ;;
    *) exit 1 ;;
  esac
  
  #Backup der letzten 5 Dateien aus dem Quellverzeichnis anlegen
  #Erweitertes Konstrukt aufgrund des Leerzeichens im Pfadnamen notwendig
  find "$SRC" -type f -print0 \
  | xargs -0 ls -t \
  | head -n 5 \
  | while IFS= read -r file; do
      7z a -t7z -mx=9 -mhe=on -p"$MEINPASSWORT" "$BACKUP_DIR/$PROJECT_NAME-$DATE.7z" "$file" > /dev/null
    done

  #sofern root: anderen Nutzer zuweisen
  if [ "$EUID" -eq 0 ]; then
          chown $USERNAME:staff $BACKUP_DIR/$PROJECT_NAME-$DATE.7z
  fi

  #generell: Leserechte einschränken
  chmod u=rw,go-rwx $BACKUP_DIR/$PROJECT_NAME-$DATE.7z

  #Alte Backups weglöschen
  cd $BACKUP_DIR/
  find . -name $PROJECT_NAME'*' -mtime $PLUS$BACKUP_RETENTION -exec rm {} \;
  logger Have created Mozilla backup on date $DATE. Backup retention time is set to $BACKUP_RETENTION days.
}

main "$@"
