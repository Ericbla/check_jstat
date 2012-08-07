check_jstat
===========

A **Nagios** plugin to get memory statistics of a Java application using **jstat**.

It first check that the process specified by its pid (-p) or its
service name (-s) (assuming there is a /var/run/<name>.pid file
holding its pid) is running and is a java process.

It then call `jstat -gc` and `jstat -gccapacity` to catch current and
maximum *heap* and *perm* sizes.
What is called *heap* here is the edden + old generation space,
while *perm* represents the permanent generation space.

If specified (with -w and -c options) values can be checked with
WARNING or CRITICAL thresholds (apply to both heap and perm regions).

This plugin also attach perfomance data to the output:

    pid=<pid>
    heap=<heap-size-used>;<heap-max-size>;<%ratio>;<warning-threshold-%ratio>;<critical-threshold-%ratio>
    perm=<perm-size-used>;<perm-max-size>;<%ratio>;<warning-threshold-%ratio>;<critical-threshold-%ratio>
`

Usage:
------

    chech_jstat.sh [-v] [-h] [-p <pid> | -s <service>] [-w <%ratio>] [-c <%ratio>]
        -v Print version and exit  
        -h This help  
        -p <pid> the PID of process to monitor  
        -s <service> the service name of process to monitor  
        -w <%> the warning threshold ratio current/max in %  
        -c <%> the critical threshold ratio current/max in %  

 