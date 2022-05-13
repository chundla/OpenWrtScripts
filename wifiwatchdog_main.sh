#/bin/bash
trap "" SIGHUP
#
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
# 
# set +m
# Author:		Catfriend1
#
# Info:					OpenWRT Watchdog Service Main Loop
# Prerequisites:		BASH
#
# Filename:				wrtwatchdog_main.sh
# Usage:				This script gets instanced by "wrtwatchdog"
#
# wrtwatchdog			main service wrapper
# wrtwatchdog_main.sh	main service program
# 
# For testing purposes only:
# 	killall logread; killall tail; sh wrtwatchdog stop; bash wrtwatchdog_main.sh debug
# 	kill -INT "$(cat "/tmp/wrtwatchdog_main.sh.pid")"
#
# Script Configuration.

PATH=/usr/bin:/usr/sbin:/sbin:/bin
CURRENT_SCRIPT_PATH="$(cd "$(dirname "$0")"; pwd)"
PID_FILE=/tmp/"$(basename "$0")".pid
LOGFILE="/tmp/wrtwatchdog.log"
LOG_MAX_LINES="1000"
DEBUG_MODE="0"

# Variables: RUNTIME.

MY_SERVICE_NAME="$(basename "$0")"

# -----------------------------------------------------
# -------------- START OF FUNCTION BLOCK --------------
# -----------------------------------------------------

logAdd ()
{
	TMP_DATETIME="$(date '+%Y-%m-%d [%H-%M-%S]')"
	TMP_LOGSTREAM="$(tail -n ${LOG_MAX_LINES} ${LOGFILE} 2>/dev/null)"
	echo "${TMP_LOGSTREAM}" > "$LOGFILE"
	if [ "$1" == "-q" ]; then
		#
		# Quiet mode.
		#
		echo "${TMP_DATETIME} ${@:2}" >> "${LOGFILE}"
	else
		#
		# Loud mode.
		#
		echo "${TMP_DATETIME} $*" | tee -a "${LOGFILE}"
	fi
	return
}


logreader() {
	#
	# Called by:	MAIN
	#
	logAdd -q "[INFO] BEGIN logreader_loop"
	/sbin/logread -f | while read line; do
		if $(echo -n "${line}" | grep "kernel.*ath10k_pci.*SWBA "); then
			logAdd -q "[ERROR] ath10k_pci 5G WiFi card failed. Restarting driver ..."
			rmmod ath10k_pci
			sleep 2
			modprobe ath10k_pci
			sleep 5
			logAdd -q "[INFO] Restarting WiFi after driver restart ..."
			wifi up
		fi
		
		if $(echo -n "${line}" | grep -q "kernel.*ath10k_ahb.*SWBA "); then
			logAdd -q "[ERROR] ath10k_ahb 2G WiFi card failing. Restarting driver ..."
			rmmod ath10k_ahb
			sleep 2
			modprobe ath10k_ahb
			sleep 5
			logAdd -q "[INFO] Restarting WiFi after driver restart ..."
			wifi up
		fi
	done
}
# ---------------------------------------------------
# -------------- END OF FUNCTION BLOCK --------------
# ---------------------------------------------------
#
#
#
#
#
#
#
#
# Check commmand line parameters.
#
case "$1" in 
'debug')
	# Turn DEBUG_MODE on.
	DEBUG_MODE="1"
	# Continue script execution.
	;;
esac
#
# Service Startup.
#
if [ "${DEBUG_MODE}" == "0" ]; then
	logAdd "${MY_SERVICE_NAME} watchdog has started."
	sleep 10
else
	# Log message.
	logAdd "${MY_SERVICE_NAME} watchdog is in DEBUG_MODE."
fi
#
# Service Main.
#
# Store script PID.
echo "$$" > "${PID_FILE}"
#
# Fork three permanently running background processes.
logreader &
#
# Wait for kill -INT from service stub.
wait
#
# We should never reach here.
#
logAdd "${MY_SERVICE_NAME}: End of script reached."
exit 0
