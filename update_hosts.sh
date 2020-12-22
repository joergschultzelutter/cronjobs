#!/bin/bash

PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/local/bin

tempfile=`mktemp`
finalfile=`mktemp`

# list of to-be-downloaded-and-merged host files
FilePath=(
	"http://someonewhocares.org/hosts/hosts"
	"http://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&mimetype=plaintext"
	"https://hosts-file.net/download/hosts.txt"
	"http://adaway.org/hosts.txt"
	"http://winhelp2002.mvps.org/hosts.txt"
	"http://www.malwaredomainlist.com/hostslist/hosts.txt"
)

# any entries in the to-be-downloaded host files pointing to these patterns will be removed from the final host file
ExcludePath=(
	"macupdate"
	"bit.ly"
	"appleid.apple.com"
	"www.icloud.com"
)

# download hosts files
for Url in "${FilePath[@]}"
do
	echo -n Downloading $Url ....
	if curl -L --fail $Url >$tempfile 2>/dev/null	
	then
		echo ok
		cat $tempfile |tr -d '\r' >>$finalfile	
	else
		echo failed
	fi 
done

#remove everything that has been excluded
for Exclude in "${ExcludePath[@]}"
do
	echo -n Removing pattern $Exclude ....
	cat $finalfile|sed "/${Exclude}/d" >$tempfile
	cp $tempfile $finalfile
	echo ok
done

# backup existing hosts file

echo -n Create backup of existing hosts file ....
cp /etc/hosts /etc/hosts.backup
echo ok

#merge locally maintained host file with d/l'ed host files
echo -n Merge with locally maintained hosts file and replace /etc/hosts ....
cat /etc/hosts.jsl $tempfile|uniq >/etc/hosts
echo ok

# flush DNS cache
#echo -n Flushing DNS Cache ....
dscacheutil -flushcache
killall -HUP mDNSResponder
echo done

# update syslog and delete temp files
logger -s Hostfile updated, records: `wc -l /etc/hosts|awk {'print $1'}`

if [ "$EUID" -ne 0 ]; then
        osascript -e 'display notification "Have updated the hosts file" with title "Cron job report"' > /dev/null 2>&1
fi

rm $tempfile $finalfile
