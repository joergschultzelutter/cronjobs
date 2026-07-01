#!/bin/bash
#
# Batchjob zum Backup der aktuellsten 5 Firefox-Backup-Dateien in einem Archiv
# Von den Backup-Archiven werden jeweils nur die letzten 15 Backups behalten; der Rest wird gelöscht
#
# Ab MacOS Catalina notwendig: System Preferences - Privacy & Security - Full Disk Access -> /bin/bash und /opt/local/bin/7zz hinzufügen
#
# Entpacken der Dateien via 7z x -p"<Passwort>"
#
# Autor: Jörg Schultze-Lutter, 2025
#
#
# NICHT per cron ausführen; Ausführung per cron kann zu Race Condition führen
#
#
# LaunchAgent settings
#
#<?xml version="1.0" encoding="UTF-8"?>
#<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
# "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
#<plist version="1.0">
#<dict>
#  <key>Label</key>
#  <string>com.jsl.backup_mozilla</string>
#
#  <key>ProgramArguments</key>
#  <array>
#    <string>/Users/jsl/cronjobs/backup_mozilla.sh</string>
#  </array>
#
#  <key>StartCalendarInterval</key>
#  <dict>
#    <key>Hour</key>
#    <integer>20</integer>
#    <key>Minute</key>
#    <integer>0</integer>
#  </dict>
#
#  <key>StandardOutPath</key>
#  <string>/tmp/backup-mozilla-launchd.out</string>
#
#  <key>StandardErrorPath</key>
#  <string>/tmp/backup-mozilla-launchd.err</string>
#
#  <key>WorkingDirectory</key>
#  <string>/Users/jsl</string>
#</dict>
#</plist>

#
# speichern als ~/Library/LaunchAgents/com.jsl.backup_mozilla.plist
#
# Installieren: launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jsl.backup_mozilla.plist
#
# Manuell ausführen: launchctl kickstart -k gui/$(id -u)/com.jsl.backup_mozilla
#
# Deinstallieren: launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.jsl.backup_mozilla.plist
#

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

# Mozilla-Profil und Username anpassen
MOZILLA_PROFILE="rbrescqi.default-release"
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
          if [ "$EUID" -ne 0 ]; then
             osascript -e 'display notification "Cannot create backup - 7z command not found!" with title "Mozilla Backup"' > /dev/null 2>&1
          fi
	  exit 1
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
    1) logger "Password key \"$schluessel\" not found in $PWFILE."; osascript -e 'display notification "Key not found in password file" with title "Mozilla Backup"' > /dev/null 2>&1;exit 1 ;;
    2) # unsichere Rechte oder Stat-Fehler
       logger "Insecure password file $PWFILE or other error has occurred."; osascript -e 'display notification "Insecure password file or other error" with title "Mozilla Backup"' > /dev/null 2>&1;exit 1 ;;
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

  #sofern nicht root, dann per osascript Notification an den User erstellen
  if [ "$EUID" -ne 0 ]; then
        osascript -e 'display notification "Have created Mozilla bookmarks backup" with title "Mozilla Backup"' > /dev/null 2>&1
  fi

}

main "$@"
