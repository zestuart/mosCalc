#!/bin/bash

function displayOutput() {
    local pid=$1
    local textRotate='testing route'
    local dispInt=0.1
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${textRotate#?}
        printf " [%c]  " "$textRotate"
        local textRotate=$temp${textRotate%"$temp"}
        sleep $dispInt
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

function routeLog() {
    nicInUse=$(route get $host | grep interface | awk '{print $2}')
    routingIP=$(ifconfig $nicInUse | grep inet\  | awk '{print $2}')
    echo "------Network and route information------" > /tmp/plot-$run/$resultsFile
    echo "NIC: $nicInUse" >> /tmp/plot-$run/$resultsFile
    echo "Routing IP: $routingIP" >> /tmp/plot-$run/$resultsFile
    traceroute $host 2> /dev/null | awk '{print $2}' > /tmp/plot-$run/route-to-host && sed -i.bak s/\*//g /tmp/plot-$run/route-to-host
}

function testRoute() {
     failPoint=0
     while [ $failPoint -lt $increment ]; do
          for i in ${hostArray[@]}; do
               ttl=$(ping -c 1 $i | grep icmp_seq | awk -F '=' '{print $4}' | awk '{print $1}')
               if [ "$?" -eq "0" ]; then
                    echo $ttl >> /tmp/plot-$run/$i-route-to-host
               else
                    echo "*" >> /tmp/plot-$run/$i-route-to-host
               fi
          done
          let failPoint=failPoint+1
     done
}

function report() {
     #average
     for i in ${hostArray[@]}; do
          hostAv=$(perl -lane '$a+=$_ for(@F);$f+=scalar(@F);END{print "".$a/$f}' /tmp/plot-$run/$i-route-to-host)
          echo "Average for $i: $hostAv"
     done

     #jitter
     trim=$increment #number of times to calculate jitter
     for i in ${hostArray[@]}; do #array of hosts in route
     ttlArray=$(cat /tmp/plot-$run/$i-route-to-host)
          while [ $trim -gt 1 ] ; do
            first=$("${ttlArray[$fistInt]}")
            second=$("${ttlArray[$secondInt]}")
               if [ $first > $second ] ; then
                    jitter=$(bc<<<"$first - $second")
                    echo $jitter >> /tmp/plot-$run/$i-jitterCalc
               else
                    jitter=$(bc<<<"$second - $first")
                    echo $jitter >> /tmp/plot-$run/$i-jitterCalc
               fi
               trim=$((trim-1))
               firstInt=$((firstInt+2))
               secondInt=$((secondInt+2))
          done
     done

}

run=$(date +%s)
mkdir /tmp/plot-$run
re='^[0-9]+$'

echo "Working directory: /tmp/plot-$run"


if [ -z "$1" ] ; then
     read -p "Enter host to test against:" host
else
     host=$1
fi

resultsFile=plot-"$host"-"$run".txt
echo "Results file: $resultsFile"

if [ -z "$2" ] ; then
     read -p "How many times would you like to test each hop? " increment
     if ! [[ $increment =~ $re ]] ; then
             echo "Error: you did not enter a valid integer. Don't they teach recreational mathamatics any more?" >&2; exit 1
     fi
else
     increment=$2
     if ! [[ $increment =~ $re ]] ; then
             echo "Error: you did not enter a valid integer for number of iterations. Don't they teach recreational mathamatics any more?" >&2; exit 1
     fi
fi

pingTest=$(ping -c 1 $host &>/dev/null)
if [ "$?" -eq "0" ]; then
     nicInUse=$(route get $host | grep interface | awk '{print $2}')
     routeLog
     hostArray=$(cat /tmp/plot-$run/route-to-host)
     (testRoute) & displayOutput $!
     report
else
     echo "Unable to ping host: please re-run, and try again."
fi