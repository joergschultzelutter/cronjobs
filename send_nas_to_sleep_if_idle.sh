#!/bin/bash
lines=`hdparm -C /dev/sd[a-d]|grep "active/idle"|wc -l|tr -d ' '|cut -f1 -d' '`
if [ $lines == "0" ]; then
	timemachine_active=`ps |grep afpd|grep TimeMach|wc -l`
	if [ $timemachine_active == "0" ]; then
		cat /etc/config/sleepmail.txt|sendmail -t
		ntpdate time.euro.apple.com 2>/dev/null >/dev/null
		hwclock --systohc
		sleep 30
		echo mem >/sys/power/state
	fi
fi

