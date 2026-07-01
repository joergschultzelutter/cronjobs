#!/bin/bash
#
# Batchjob zum Backup der MoneyMoney-Datenbank
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
#  <string>com.jsl.backup_moneymoney</string>
#
#  <key>ProgramArguments</key>
#  <array>
#    <string>/Users/jsl/cronjobs/backup_moneymoney.sh</string>
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
#  <string>/tmp/backup-moneymoney-launchd.out</string>
#
#  <key>StandardErrorPath</key>
#  <string>/tmp/backup-moneymoney-launchd.err</string>
#
#  <key>WorkingDirectory</key>
#  <string>/Users/jsl</string>
#</dict>
#</plist>

#
# speichern als ~/Library/LaunchAgents/com.jsl.backup_moneymoney.plist
#
# Installieren: launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.jsl.backup_moneymoney.plist
#
# Manuell ausführen: launchctl kickstart -k gui/$(id -u)/com.jsl.backup_moneymoney
#
# Deinstallieren: launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.jsl.backup_moneymoney.plist
#

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

SRC="com.moneymoney-app.retail/Data/Library/Application Support/MoneyMoney"
SRC_DIR="/Users/jsl/Library/Containers"
PROJECT_NAME="MoneyMoney"
ROOT_DIR="/Users/jsl/Documents/Backups"
BACKUP_DIR=$ROOT_DIR/$PROJECT_NAME
CLOUD_BACKUP_TEMP=$ROOT_DIR/.cloud
BACKUP_RETENTION=15
BACKUP_RETENTION_CLOUD=2
AWK_COMMAND="NR>"$BACKUP_RETENTION
AWK_COMMAND_CLOUD="NR>"$BACKUP_RETENTION_CLOUD
MACPORTS_PATH=/opt/local/bin

DATE=`date +"%Y%m%d"`

SCRIPT_DIR="/Users/jsl/cronjobs"
PWFILE="$SCRIPT_DIR/cronpw.txt"
. "$SCRIPT_DIR/get_password.sh"


main() {

  if [ ! -f "$MACPORTS_PATH/7zz" ]; then
	  logger Cannot create backup - 7z command not found!
	  #Sofern nicht Root, dann Notification an Nutzer
	  if [ "$EUID" -ne 0 ]; then
		  osascript -e 'display notification "Cannot create backup - 7z command not found!" with title "MoneyMoney Backup"' > /dev/null 2>&1
	  fi
	  exit 1
  fi

  #backup-Dir anlegen, falls nicht vorhanden
  if [ ! -d "$BACKUP_DIR" ]; then
          mkdir -p $BACKUP_DIR
  fi


  local schluessel="PASSWORD_MONEYMONEY_BACKUPS"
  local MEINPASSWORT

  MEINPASSWORT=$(get_password "$schluessel" "$PWFILE")
  case $? in
    0) : ;;
    1) logger "Password key \"$schluessel\" not found in $PWFILE."; osascript -e 'display notification "Key not found in password file" with title "MoneyMoney Backup"' > /dev/null 2>&1;exit 1 ;;
    2) # unsichere Rechte oder Stat-Fehler
       logger "Insecure password file $PWFILE or other error has occurred."; osascript -e 'display notification "Insecure password file or other error" with title "MoneyMoney Backup"' > /dev/null 2>&1;exit 1 ;;
    *) exit 1 ;;
  esac

  #cloud-backup-temp anlegen, falls nicht vorhanden
  if [ ! -d "$CLOUD_BACKUP_TEMP/$PROJECT_NAME" ]; then
	  mkdir -p $CLOUD_BACKUP_TEMP/$PROJECT_NAME
  fi

  #nun das Verzeichnis  normal ohne Passwort einpacken
  $MACPORTS_PATH/7zz a -t7z -mx=9 -bd -bb0 -y $BACKUP_DIR/$PROJECT_NAME-$DATE.7z "$SRC_DIR/$SRC" >/dev/null </dev/null

  #jetzt das tar-archiv für die Cloud erstellen; wird gesondert gesichert
  #zunächst bestehendes Archiv ggf. weglöschen
  if [ -f "$CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z" ]; then
          rm $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z > /dev/null
  fi

  #nun das gleiche Archiv gesondert geschützt in das Cloudvereichnis stellen
  $MACPORTS_PATH/7zz a -t7z -mx=9 -mhe=on -p"$MEINPASSWORT" -bd -bb0 -y $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z "$SRC_DIR/$SRC" >/dev/null </dev/null

  #sofern root: anderen Nutzer zuweisen
  if [ "$EUID" -eq 0 ]; then
	  chown jsl:staff $BACKUP_DIR/$PROJECT_NAME-$DATE.7z $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z
  fi

  #generell: Leserechte einschränken
  chmod u=rw,go-rwx $BACKUP_DIR/$PROJECT_NAME-$DATE.7z $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z

  #Löschen eventueller alter Kopien im Cloudverzeichnis
  cd $CLOUD_BACKUP_TEMP/$PROJECT_NAME
  ls -t | awk $AWK_COMMAND_CLOUD | xargs rm -f

  # im eigentlichen Backup-Verzeichnis nur die letzten 15 Dateien behalten; der Rest wird gelöscht
  cd $BACKUP_DIR
  ls -t | awk $AWK_COMMAND | xargs rm -f

  #syslog-Nachricht einstellen
  logger Have created MoneyMoney backup on date $DATE. Backup retention time is set to $BACKUP_RETENTION files.

  #sofern nicht root, dann per osascript Notification an den User erstellen
  if [ "$EUID" -ne 0 ]; then
          osascript -e 'display notification "Have created MoneyMoney database backup" with title "Cron job report"' > /dev/null 2>&1
  fi

  #jetzt das tar-archiv für die Cloud erstellen; wird gesondert gesichert
  #zunächst bestehendes Archiv ggf. weglöschen
  if [ -f "$CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z" ]; then
          rm $CLOUD_BACKUP_TEMP/$PROJECT_NAME/$PROJECT_NAME-$DATE.7z > /dev/null
  fi

}

main "$@"
