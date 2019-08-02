#!/bin/sh
#
#
# Script to fetch authentication tokens using an EC2's IAM instance-role
########################################################################
PROGNAME="$( basename "${BASH_SOURCE[0]}" )"
LOGFACIL="user.err"
DEBUGVAL="${DEBUG:-false}"
INSTANCEROLENAME="$( curl -skL \
      http://169.254.169.254/latest/meta-data/iam/security-credentials/
   )"

# Function-abort hooks
trap "exit 1" TERM
export TOP_PID=$$


# Miscellaneous output-engine
function logIt {
   local LOGSTR
   local ERREXT

   LOGSTR="${1}"
   ERREXT="${2:-}"

   # Spit out message to calling-shell if debug-mode enabled
   if [[ ${DEBUGVAL} == true ]]
   then
      echo "${LOGSTR}" >&2
   fi

   # Send to syslog if passed message-code is non-zero
   if [[ ! -z ${ERREXT} ]] && [[ ${ERREXT} -gt 0 ]]
   then
      logger -st "${PROGNAME}" -p ${LOGFACIL} "${LOGSTR}"
      # Since we're non-zero, immediately terminate script
      kill -s TERM " ${TOP_PID}"
   fi
}

# Extract auth-elements from cred-snarf
function ExtractCredElement {
   local CRED_ELEM
   CRED_ELEM="${1}"

   if [[ ! -z ${CRED_ELEM} ]]
   then
      echo ${CRED_RETURN} | \
        python -c 'import json,sys; \
          obj=json.load(sys.stdin);print obj["'${CRED_ELEM}'"]'
   else
      logIt "No credential-element was specified. Aborting... " 1
   fi
}

# We only ever want this script sourced...
if [ "$0" = "${BASH_SOURCE}" ]; then
    logIt "Error: Script must be sourced" 1
fi

if [[ -z ${INSTANCEROLENAME}  ]]
then
   logIt "Could not detect an attached IAM instance-role" 1
else
   logIt "Found an attached IAM instance-role [${INSTANCEROLENAME}]" 0
   CRED_RETURN=$(
      curl -skL http://169.254.169.254/latest/meta-data/iam/security-credentials/${INSTANCEROLENAME}/
   )
fi

if [[ ${CRED_RETURN} =~ Success ]]
then
   logIt "Snarfed some creds" 0
   export AWS_ACCESS_KEY_ID=$( ExtractCredElement "AccessKeyId" )
   export AWS_SECRET_ACCESS_KEY=$( ExtractCredElement "SecretAccessKey" )
   export AWS_SESSION_TOKEN=$( echo ${CRED_RETURN} | ExtractCredElement "Token" )
else
   logIt "Failed to snarf some creds" 1
fi
