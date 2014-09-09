#!/bin/sh
#
#
# A simple Nagios command that check some statistics of a JAVA JVM.
#
# It first chech that the process specified by its pid (-p) or its
# service name (-s) (assuming there is a /var/run/<name>.pid file
# holding its pid) is running and is a java process.
# It then call jstat -gc and jstat -gccapacity to catch current and
# maximum 'heap' and 'perm' sizes.
# What is called 'heap' here is the edden + old generation space,
# while 'perm' represents the permanent generation space.
# If specified (with -w and -c options) values can be checked with
# WARNING or CRITICAL thresholds (apply to both heap and perm regions).
# This plugin also attach perfomance data to the output:
#  pid=<pid>
#  heap=<heap-size-used>;<heap-max-size>;<%ratio>;<warning-threshold-%ratio>;<critical-threshold-%ratio>
#  perm=<perm-size-used>;<perm-max-size>;<%ratio>;<warning-threshold-%ratio>;<critical-threshold-%ratio>
#
#
# Created: 2012, June
# By: Eric Blanchard
# License: LGPL v2.1
#


# Usage helper for this script
function usage() {
    local prog="${1:-check_jstat.sh}"
    echo "Usage: $prog -v";
    echo "       Print version and exit"
    echo "Usage: $prog -h";
    echo "      Print this help and exit"
    echo "Usage: $prog -p <pid> [-w <%ratio>] [-c <%ratio>]";
    echo "Usage: $prog -s <service> [-w <%ratio>] [-c <%ratio>]";
    echo "Usage: $prog -j <java-name> [-w <%ratio>] [-c <%ratio>]";
    echo "       -p <pid>       the PID of process to monitor"
    echo "       -s <service>   the service name of process to monitor"
    echo "       -j <java-name> the java app (see jps) process to monitor"
    echo "                      if this name in blank (-j '') any java app is"
    echo "                      looked for (as long there is only one)"
    echo "       -w <%>         the warning threshold ratio current/max in %"
    echo "       -c <%>         the critical threshold ratio current/max in %"
}

VERSION='1.3'
service=''
pid=''
ws=-1
cs=-1
use_jps=0

while getopts hvp:s:j:w:c: opt ; do
    case ${opt} in
    v)  echo "$0 version $VERSION"
        exit 0
        ;;
    h)  usage $0
        exit 3
        ;;
    p)  pid="${OPTARG}"
        ;;
    s)  service="${OPTARG}"
        ;;
    j)  java_name="${OPTARG}"
        use_jps=1
        ;;
    w)  ws="${OPTARG}"
        ;;
    c)  cs="${OPTARG}"
        ;;
    esac
done

if [ -z "$pid" -a -z "$service" -a $use_jps -eq 0 ] ; then
    echo "One of -p, -s or -j parameter must be provided"
    usage $0
    exit 3
fi

if [ -n "$pid" -a -n "$service" ] ; then
    echo "Only one of -p or -s parameter must be provided"
    usage $0
    exit 3
fi
if [ -n "$pid" -a $use_jps -eq 1 ] ; then
    echo "Only one of -p or -j parameter must be provided"
    usage $0
    exit 3
fi
if [ -n "$service" -a $use_jps -eq 1 ] ; then
    echo "Only one of -s or -j parameter must be provided"
    usage $0
    exit 3
fi

if [ $use_jps -eq 1 ] ; then
    if [ -n "$java_name" ] ; then
        java=$(jps | grep "$java_name" 2>/dev/null)
    else
        java=$(jps | grep -v Jps 2>/dev/null)
    fi
    java_count=$(echo "$java" | wc -l)
    if [ -z "$java" -o "$java_count" != "1" ] ; then
        echo "UNKNOWN: No (or multiple) java app found"
        exit 3
    fi
    pid=$(echo "$java" | cut -d ' ' -f 1)
    label=${java_name:-$(echo "$java" | cut -d ' ' -f 2)}
elif [ -n "$service" ] ; then
    if [ ! -r /var/run/${service}.pid ] ; then
        echo "/var/run/${service}.pid not found"
        exit 3
    fi
    pid=$(cat /var/run/${service}.pid)
    label=$service
else
    label=$pid
fi

if [ ! -d /proc/$pid ] ; then
    echo "CRITICAL: process pid[$pid] not found"
    exit 2
fi

proc_name=$(cat /proc/$pid/status | grep 'Name:' | sed -e 's/Name:[ \t]*//')
if [ "$proc_name" != "java" ]; then
    echo "CRITICAL: process pid[$pid] seems not to be a JAVA application"
    exit 2
fi

gc=$(jstat -gc $pid | tail -1 | sed -e 's/[ ][ ]*/ /g')
if [ -z "$gc" ]; then
    echo "CRITICAL: Can't get GC statistics"
    exit 2
fi
#echo "gc=$gc"
set -- $gc
eu=$(expr "${6}" : '\([0-9]\+\)')
ou=$(expr "${8}" : '\([0-9]\+\)')
pu=$(expr "${10}" : '\([0-9]\+\)')

gccapacity=$(jstat -gccapacity $pid | tail -1 | sed -e 's/[ ][ ]*/ /g')
if [ -z "$gccapacity" ]; then
    echo "CRITICAL: Can't get GC capacity"
    exit 2
fi

#echo "gccapacity=$gccapacity"
set -- $gccapacity
ygcmx=$(expr "${2}" : '\([0-9]\+\)')
ogcmx=$(expr "${8}" : '\([0-9]\+\)')
pgcmx=$(expr "${12}" : '\([0-9]\+\)')

#echo "eu=${eu}k ygcmx=${ygcmx}k"
#echo "ou=${ou}k ogcmx=${ogcmx}k"
#echo "pu=${pu}k pgcmx=${pgcmx}k"

heap=$(($eu + $ou))
heapmx=$(($ygcmx + $ogcmx))
heapratio=$((($heap * 100) / $heapmx))
permratio=$((($pu * 100) / $pgcmx))
#echo "youg+old=${heap}k, (Max=${heapmx}k, current=${heapratio}%)"
#echo "perm=${pu}k, (Max=${pgcmx}k, current=${permratio}%)"


perfdata="pid=$pid heap=$heap;$heapmx;$heapratio;$ws;$cs perm=$pu;$pgcmx;$permratio;$ws;$cs"

if [ $cs -gt 0 -a $permratio -ge $cs ]; then
    echo "CRITICAL: jstat process $label critical PermGen (${permratio}% of MaxPermSize)|$perfdata"
    exit 2
fi
if [ $cs -gt 0 -a $heapratio -ge $cs ]; then
    echo "CRITICAL: jstat process $label critical Heap (${heapratio}% of MaxHeapSize)|$perfdata"
    exit 2
fi

if [ $ws -gt 0 -a $permratio -ge $ws ]; then
    echo "WARNING: jstat process $label warning PermGen (${permratio}% of MaxPermSize)|$perfdata"
    exit 1
fi
if [ $ws -gt 0 -a $heapratio -ge $ws ]; then
    echo "WARNING: jstat process $label warning Heap (${heapratio}% of MaxHeapSize)|$perfdata"
    exit 1
fi
echo "OK: jstat process $label alive|$perfdata"
exit 0

# That's all folks !
