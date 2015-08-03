#!/usr/bin/env bash
#
#
# A simple Nagios plugin that check the number of open files owned by a process.
#
# It first chech that the process specified by its pid (-p) or its
# service name (-s) (assuming there is a /var/run/<name>.pid file
# holding its pid) or by its name (-n) is running.
# It then look at /proc/<pid>/fd to count the # of open file descriptors.
# If specified (with -w and -c options) the count can be checked with
# WARNING or CRITICAL thresholds.
# This plugin also attach perfomance data to the output:
#  pid=<pid>
#  lsof=<lsof>;<warning-threshold>;<critical-threshold>;<max-lsof>"
#
#
# Created: 2012, December
# By: Eric Blanchard
# License: LGPL v2.1
#


# Usage helper for this script
function usage() {
    local prog="${1:-check_of.sh}"
    echo "Usage: $prog -v";
    echo "       Print version and exit"
    echo "Usage: $prog -h";
    echo "      Print this help nd exit"
    echo "Usage: $prog -p <pid> [-w <%ratio>] [-c <%ratio>]";
    echo "Usage: $prog -s <service> [-w <%ratio>] [-c <%ratio>]";
    echo "Usage: $prog -n <name> [-w <%ratio>] [-c <%ratio>]";
    echo "       -p <pid>       the PID of process to monitor"
    echo "       -s <service>   the service name of process to monitor"
    echo "       -n <name>      the process name to monitor"
    echo "       -w <%>         the warning threshold ratio current/max in %"
    echo "       -c <%>         the critical threshold ratio current/max in %"
}

VERSION='1.1'
service=''
pid=''
ws=-1
cs=-1
use_ps=0
lsof_max=$(ulimit -n)

while getopts hvp:s:n:w:c: opt ; do
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
    n)  name="${OPTARG}"
        use_ps=1
        ;;
    w)  ws="${OPTARG}"
        ;;
    c)  cs="${OPTARG}"
        ;;
    esac
done

if [ $cs -gt 0 ]; then
    cs=$((($cs * $lsof_max) / 100))
fi
if [ $ws -gt 0 ]; then
    ws=$((($ws * $lsof_max) / 100))
fi

if [ -z "$pid" -a -z "$service" -a $use_ps -eq 0 ] ; then
    echo "One of -p, -s or -n parameter must be provided"
    usage $0
    exit 3
fi

if [ -n "$pid" -a -n "$service" ] ; then
    echo "Only one of -p or -s parameter must be provided"
    usage $0
    exit 3
fi
if [ -n "$pid" -a $use_ps -eq 1 ] ; then
    echo "Only one of -p or -n parameter must be provided"
    usage $0
    exit 3
fi
if [ -n "$service" -a $use_ps -eq 1 ] ; then
    echo "Only one of -s or -n parameter must be provided"
    usage $0
    exit 3
fi

if [ $use_ps -eq 1 ] ; then
    if [ -n "$name" ] ; then
        proc=$(ps -e | grep "$name" | grep -v "grep" 2>/dev/null)
    fi
    count=$(echo "$proc" | wc -l)
    if [ -z "$proc" -o "$count" != "1" ] ; then
        echo "UNKNOWN: No (or multiple) process $name found"
        exit 3
    fi
    pid=$(expr "$proc" : '[ ]*\([0-9]\+\)')
    label=$name
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

# Get count of open files
lsof=$(ls /proc/$pid/fd | wc -l)
if [ -z "$lsof" ]; then
    echo "CRITICAL: Can't get open files count"
    exit 2
fi

perfdata="pid=$pid lsof=$lsof;$ws;$cs;$lsof_max"

if [ $cs -gt 0 -a $lsof -ge $cs ]; then
    echo "CRITICAL: jstat process $label critical $lsof open files|$perfdata"
    exit 2
fi

if [ $ws -gt 0 -a $lsof -ge $ws ]; then
    echo "WARNING: jstat process $label warning $lsof open files|$perfdata"
    exit 1
fi
echo "OK: lsof process $label $lsof open files|$perfdata"
exit 0

# That's all folks !
