#!/usr/bin/env bash

# sp-sc-auth utilization script
#
#   sp-sc-auth is a headless sopcast client
#   for which this script uses VLC player as a frontend
#
# Anton Nefedov a.nefedov@yahoo.com
#

CHANNEL=-1
LOCPORT=-1
LOCPORT_DEFAULT=3908
PLAYPORT=-1
PLAYPORT_DEFAULT=8908
SERVER="broker.sopcast.com"
PROCNUM_ORIG=-1

TIMEOUT_SIGTERM=20 # sec

function usage {
   echo "usage: vsopcast [-l localportnum] [-p playportnum] [-s server] channel"
   echo "  e.g: vsopcast -l 3908 -p 8908 -s broker.sopcast.com 133272 will start playing sop://broker.sopcast.com:3912/133272 at http://localhost:8908/tv.asf"
}

function vlc_bin {
    if uname | grep Darwin > /dev/null ; then
	echo "/Applications/VLC.app/Contents/MacOS/VLC"
    else
	echo "vlc"
    fi
}

function progress_bar {
    nbars=20
    time=$1

    # gotta render the bar (time+1) times 
    for (( i=0; i<=time; i++ ))
    do
        completeness=$(($i * $nbars / $time))
	echo -n "["
	for (( y=1; y<=$completeness ; y++ ))
	do
	    echo -n "#"
	done
	for (( y=$completeness; y<$nbars; y++ ))
	do
	    echo -n "."
	done
	echo -ne "]\r"

	if [ $i -ne $time ] ; then sleep 1 ; fi
    done

    echo -ne "\n"
}

function isAlive {
    kill -0 $1 &> /dev/null
    return $?
}

function finish {
    if ! isAlive $PROCNUM_ORIG ; then return; fi

    echo "terminating sp-sc($PROCNUM_ORIG).."
    kill $PROCNUM_ORIG
    sleep 1
    if isAlive $PROCNUM_ORIG ; then
	sleep $TIMEOUT_SIGTERM
	if isAlive $PROCNUM_ORIG ; then
            echo "no response, killing $PROCNUM_ORIG.."
            kill -9 $PROCNUM_ORIG
	fi
    fi
}

function vlcloop {
    shallContinue=1

    while [ $shallContinue -eq 1 ] ; do
	$(vlc_bin) http://localhost:$PLAYPORT/tv.asf &> /dev/null
	echo -n "vlc closed. sp-sc is "

	if isAlive $PROCNUM_ORIG ; then echo "alive" ; else echo "dead" ; fi

	while true; do
	    read -p "[f]inish (end sp-sc) / [r]estart (vlc) / [e]xit (script) ? " ans
	    case $ans in
		[Ff]* )
		    echo "finishing"
		    shallContinue=0
		    finish
		    break;;
		[Rr]* )
		    echo "restarting vlc"
		    shallContinue=1
		    break;;
		[Ee]* )
		    echo -n "exiting.. "
		    if isAlive ; then echo "(sp-sc is still alive!)" ; else echo "" ; fi
		    shallContinue=0
		    break;;
		* ) echo "Please answer f/r/e ..";;
	    esac
	done
    done
}

function start_spsc {

    if ! command -v sp-sc-auth > /dev/null ; then
        echo "sp-sc-auth (sopcast client) is not found in your PATH"
        exit 1
    fi
    sp-sc-auth sop://$SERVER:3912/$CHANNEL $LOCPORT $PLAYPORT > /dev/null &
    PROCNUM_ORIG=$!
    echo "dbg: sp-sc pid($PROCNUM_ORIG)"
    echo "connecting to $SERVER:3912/$CHANNEL.. "
    progress_bar 10

    if kill -0 $PROCNUM_ORIG &> /dev/null ; then
	echo "connected. starting the player.."
    else
	echo "could not connect. exiting."
	exit
    fi
}

############################################################
############################################################
# main()
############################################################

if [ $# -lt 1 ] ; then
   usage
   exit 0
fi

nopts=1
while getopts "h?l:p:s:" opt; do
    case "$opt" in
	h|/?)
	    usage
	    exit 0
	    ;;
	l)
	    LOCPORT=$OPTARG
	    nopts=$(($nopts+2))
	    ;;
	p)
	    PLAYPORT=$OPTARG
	    nopts=$(($nopts+2))
	    ;;
	s)
	    SERVER=$OPTARG
	    nopts=$(($nopts+2))
	    ;;
    esac
done

if [ $# -lt $nopts ] ; then
    usage
    exit 0
fi

CHANNEL=${!nopts}

if [ $PLAYPORT -eq -1 ] || [ $LOCPORT -eq -1 ] ; then
    instances=$(pgrep sp-sc-auth)
    if [ $instances ] ; then
	echo "Found working sp-sc instances which ports might collide:"
	echo "  "$instances
	echo "Specify the port values explicitly"
	exit 1
    fi
    if [ $PLAYPORT -eq -1 ] ; then
        PLAYPORT=$PLAYPORT_DEFAULT
    fi
    if [ $LOCPORT -eq -1 ] ; then
        LOCPORT=$LOCPORT_DEFAULT
    fi
fi

echo "dbg: options: localport=$LOCPORT, playport=$PLAYPORT, server=$server, channel=$CHANNEL"

start_spsc
vlcloop
echo "end."
exit 0
