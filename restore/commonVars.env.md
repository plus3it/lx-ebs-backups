This file contains variable-declarations that are used across scripts in this utility-bundle. 

~~~
THISINSTID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
DATESTMP=`date "+%Y%m%d%H%M"`
LOGDIR="/var/log/EBSbackup"
LOGFILE="${LOGDIR}/backup-${DATESTMP}.log"

DEFRETAIN="7"						# Value expressed in days
CURCTIME=`date "+%s"`					# Current time in seconds
DAYINSEC="$((60 * 60 * 24))"				# Seconds in a day
KEEPHORIZ="$((${DAYINSEC} * ${DEFRETAIN}))"		# Keep-interval (in seconds)
EXPBEYOND="$((${CURCTIME} - ${KEEPHORIZ}))"		# Expiry horizon (in seconds)
EXPDATE=`date -d @${EXPBEYOND} "+%Y/%m/%d @ %H:%M"`	# Expiry horizon
~~~
