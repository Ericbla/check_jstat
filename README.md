check_jstat
===========

A **Nagios** plugin to get memory statistics of a Java application using **jstat**.

The process selection is done either by:
*  its pid (-p <pid>)
*  its service name (-s <service-name>) (assuming there is a /var/run/<name>.pid file holding its pid)
*  its java name (-j <java name>) where the java name depends on how the java application has been launched (main class or jar/war in case of java -jar) (see jps).
*  its java name or parameters (-J <java name>) (see jps -v).


It then call `jstat -gc` and `jstat -gccapacity` to catch current and
maximum *heap* and *perm* sizes.
What is called *heap* here is the edden + old generation space,
while *perm* represents the permanent generation space.

If specified (with -w and -c options) values can be checked with
**WARNING** or **CRITICAL** thresholds (apply to both heap and perm regions).

This plugin also attach perfomance data to the output:

    pid=<pid>
    heap=<heap-size-used>;<heap-max-size>;<%ratio>;<warning-threshold-%ratio>;<critical-threshold-%ratio>
    perm=<perm-size-used>;<perm-max-size>;<%ratio>;<warning-threshold-%ratio>;<critical-threshold-%ratio>



Usage:
------

    check_jstat.sh -v
        Print version and exit"
    check_jstat.sh -h
        Print this help nd exit
    check_jstat.sh -p <pid> [-w <%ratio>] [-c <%ratio>] [-P <java-home>]
    check_jstat.sh -s <service> [-w <%ratio>] [-c <%ratio>] [-P <java-home>]
    check_jstat.sh -j <java-name> [-w <%ratio>] [-c <%ratio>] [-P <java-home>]
    check_jstat.sh -J <java-name> [-w <%ratio>] [-c <%ratio>] [-P <java-home>]
        -p <pid>       the PID of process to monitor
        -s <service>   the service name of process to monitor
        -j <java-name> the java app (see jps) process to monitor
                       if this name in blank (-j '') any java app is
                       looked for (as long there is only one)
        -J <java-name> same as -j but checks on 'jps -v' output
        -P <java-home> use this java installation path
        -w <%> the warning threshold ratio current/max in % (defaults to 90)
        -c <%> the critical threshold ratio current/max in % (defaults to 95)

Configuration:
--------------

This plugin may require to be run with sudo. In this case add a configuration in /etc/sudoers. For example if nagios is the user that run nagios (or NRPE deamon):

    Defaults:nagios	!requiretty
    nagios ALL=(root) NOPASSWD: /opt/nagios/libexec/check_jstat.sh

check_of
========

Another**Nagios** plugin count the number of open files descriptors of a given process.

The process selection is done either by:
*  its pid (-p <pid>)
*  its service name (-s <service-name>) (assuming there is a /var/run/<name>.pid file holding its pid)
*  its process name (-n <name>) (assuming that there is a single process that can be greped by its name using ps -e command).

Usage:
------

    Usage: ./check_of.sh -v
        Print version and exit
    Usage: ./check_of.sh -h
        Print this help nd exit
    Usage: ./check_of.sh -p <pid> [-w <%ratio>] [-c <%ratio>]
    Usage: ./check_of.sh -s <service> [-w <%ratio>] [-c <%ratio>]
    Usage: ./check_of.sh -n <name> [-w <%ratio>] [-c <%ratio>]
        -p <pid>       the PID of process to monitor
        -s <service>   the service name of process to monitor
        -n <name>      the process name to monitor
        -w <%>         the warning threshold ratio current/max in %
        -c <%>         the critical threshold ratio current/max in %


