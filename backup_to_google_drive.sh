#!/bin/bash
#
# Batchjob zum Backup der lokalen Backups gen Google Drive
# Ab MacOS Catalina notwendig: System Preferences - Privacy & Security - Full Disk Access -> /bin/bash und /opt/local/bin/7zz hinzufügen
#
# Autor: Jörg Schultze-Lutter, 2025
#
# NICHT per cron ausführen; Ausführung per cron kann zu Race Condition führen
#
# LaunchAgent settings
#
#<?xml version="1.0" encoding="UTF-8"?>
#<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
# "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
#<plist version="1.0">
#<dict>
#  <key>Label</key>
#  <string>com.jsl.backup_to_google_drive</string>
#
#  <key>ProgramArguments</key>
#  <array>
#    <string>/Users/jsl/cronjobs/backup_to_google_drive.sh</string>
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
#  <string>/tmp/backup-to-google-drive-launchd.out</string>
#
#  <key>StandardErrorPath</key>
#  <string>/tmp/backup-to-google-drive-launchd.err</string>
#
#  <key>WorkingDirectory</key>
#  <string>/Users/jsl</string>
#</dict>
#</plist>

#
# speichern als ~/Library/LaunchAgents/com.jsl.backup_to_google_drive.plist
#
# Installieren: launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jsl.backup_to_google_drive.plist
#
# Manuell ausführen: launchctl kickstart -k gui/$(id -u)/com.jsl.backup_to_google_drive
#
# Deinstallieren: launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.jsl.backup_to_google_drive.plist
#

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

ROOT_DIR="/Users/jsl/Documents/Backups"
CLOUD_BACKUP_TEMP=$ROOT_DIR/.cloud
CLOUD_BACKUP_ROOT_DIR="/Users/jsl/Google Drive/My Drive/.cron"
ARCHIV_VOLNAME="google_drive_cron_folder"
ARCHIV_DRIVENAME=".backup.sparseimage"
MACPORTS_PATH=/opt/local/bin

DATE=`date`

SCRIPT_DIR="/Users/jsl/cronjobs"
PWFILE="$SCRIPT_DIR/cronpw.txt"
. "$SCRIPT_DIR/get_password.sh"

main() {
  if [ ! -f "$MACPORTS_PATH/7z" ]; then
	  logger Cannot create backup - 7z command not found!
	  #Sofern nicht Root, dann Notification an Nutzer
	  if [ "$EUID" -ne 0 ]; then
		  osascript -e 'display notification "Cannot create backup - 7z command not found!" with title "Upload to Google Drive"' > /dev/null 2>&1
		  exit 1
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

  local schluessel="PASSWORD_GOOGLE_DRIVE"
  local MEINPASSWORT

  MEINPASSWORT=$(get_password "$schluessel" "$PWFILE")
  case $? in
    0) : ;;
    1) logger "Password key \"$schluessel\" not found in $PWFILE."; osascript -e 'display notification "Key not found in password file" with title "Upload to Google Drive"' > /dev/null 2>&1;exit 1 ;;
    2) # unsichere Rechte oder Stat-Fehler
       logger "Insecure password file $PWFILE or other error has occurred."; osascript -e 'display notification "Insecure password file or other error" with title "Upload to Google Drive"' > /dev/null 2>&1;exit 1 ;;
    *) exit 1 ;;
  esac


  cd "$CLOUD_BACKUP_ROOT_DIR"

  if [ ! -f "$ARCHIV_DRIVENAME" ]; then
	  echo -n $MEINPASSWORT|hdiutil create -fs HFS+ -type SPARSE -layout GPTSPUD -quiet -size 1g -nospotlight -volname $ARCHIV_VOLNAME -encryption AES-256 -stdinpass $ARCHIV_DRIVENAME
  fi

  echo -n $MEINPASSWORT|hdiutil attach -quiet -stdinpass $ARCHIV_DRIVENAME

  if [ -d "/Volumes/$ARCHIV_VOLNAME" ]; then
	  rm -r /Volumes/$ARCHIV_VOLNAME/Enpass 2>/dev/null
	  rm -r /Volumes/$ARCHIV_VOLNAME/MoneyMoney 2>/dev/null
	  rm -r /Volumes/$ARCHIV_VOLNAME/Mozilla 2>/dev/null
	  rm /Volumes/$ARCHIV_VOLNAME/version.txt 2>/dev/null

	  echo Version: $DATE >/Volumes/$ARCHIV_VOLNAME/version.txt
	  cp -r $CLOUD_BACKUP_TEMP/Enpass /Volumes/$ARCHIV_VOLNAME 2>/dev/null
	  cp -r $CLOUD_BACKUP_TEMP/MoneyMoney /Volumes/$ARCHIV_VOLNAME 2>/dev/null
	  cp -r $CLOUD_BACKUP_TEMP/Mozilla /Volumes/$ARCHIV_VOLNAME 2>/dev/null

	  hdiutil detach -quiet "/Volumes/$ARCHIV_VOLNAME"
	  sleep 1
	  echo -n $MEINPASSWORT|hdiutil compact -quiet -stdinpass $ARCHIV_DRIVENAME
  fi

  #syslog-Nachricht einstellen
  logger Have created Cloud backup on date $DATE.

  #sofern nicht root, dann per osascript Notification an den User erstellen
  if [ "$EUID" -ne 0 ]; then
          osascript -e 'display notification "Have created Cloud backup" with title "Upload to Google Drive"' > /dev/null 2>&1
  fi
}

main "$@"
