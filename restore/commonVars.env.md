This file contains variable-declarations that are used across scripts in this utility-bundle. 

&nbsp;

Use instance meta-data to determine calling host's Instance ID
~~~
THISINSTID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
~~~

&nbsp;

Set a fixed date-stamp for use within scripts. This ensures that all actions that tack on a date field tack on the *same* date.
~~~
DATESTMP=`date "+%Y%m%d%H%M"`
~~~

&nbsp;

Set a directory-location for external log-capture
~~~
LOGDIR="/var/log/EBSbackup"
~~~

&nbsp;

Set a file-location for external log-capture
~~~
LOGFILE="${LOGDIR}/backup-${DATESTMP}.log"
~~~

&nbsp;

Set default number of days to keep automatically-generated snapshots
~~~
DEFRETAIN="7"
~~~

&nbsp;

Set a fixed date-stamp for use within scripts denoted in seconds-since-epoch format
~~~
CURCTIME=`date "+%s"`
~~~

&nbsp;

Set a variable to contain the number of seconds in a day.
~~~
DAYINSEC="$((60 * 60 * 24))"
~~~

&nbsp;

Set a variable to contain the number of seconds within the snapshot keep-window
~~~
KEEPHORIZ="$((${DAYINSEC} * ${DEFRETAIN}))"
~~~
~~~
EXPBEYOND="$((${CURCTIME} - ${KEEPHORIZ}))"		# Expiry horizon (in seconds)
EXPDATE=`date -d @${EXPBEYOND} "+%Y/%m/%d @ %H:%M"`	# Expiry horizon
~~~
