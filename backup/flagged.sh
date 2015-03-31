#!/bin/sh
#
# This script is designed to perform consistent backups of
# - Selected EBS volumes (referenced by volume-id)
# - Mounted filesystems  (referenced by fully-qualified directory-path)
# - LVM volumes (referenced by VGNAME/LVNAME path-specification)
#
#
# Dependencies:
# - Generic: See the top-level README_dependencies.md for script dependencies
#
# License:
# - This script released under the Apache 2.0 OSS License
#
######################################################################

# Starter Variables
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/AWScli/bin
WHEREAMI=`readlink -f ${0}`
SCRIPTDIR=`dirname ${WHEREAMI}`
PROGNAME=`basename ${WHEREAMI}`

# Put the bulk of our variables into an external file so they
# can be easily re-used across scripts
source ${SCRIPTDIR}/commonVars.env

# SCRIPT Variables
TARGVG=${1:-UNDEF}
BKNAME="$(hostname -s)_${THISINSTID}-bkup-${DATESTMP}"
OPTIONBUFR=`getopt -o v:f: --long vgname:fsname: -n ${PROGNAME} -- "$@"`
# Note the quotes around '$OPTIONBUFR': they are essential!
eval set -- "${OPTIONBUFR}"

# Parse our flagged args
while [ true ]
do
   case "$1" in
      -v|--vgname)
         # Mandatory argument. Operating in quoted mode: an
	 # empty parameter will be generated if its optional
	 # argument is not found
	 case "$2" in
	    "")
	       echo "Error: option required but not specified"
	       shift 2
	       exit 1
	       ;;
	    *)
	       echo "A VG-name has been specified: '${2}'"
               ${SCRIPTDIR}/VGsnap.sh "${2}"
	       shift 2;
	       ;;
	 esac
	 ;;
      -f|--fsname)
         # Mandatory argument. Operating in quoted mode: an
	 # empty parameter will be generated if its optional
	 # argument is not found
	 case "$2" in
	    "")
	       echo "Error: option required but not specified"
	       shift 2
	       exit 1
	       ;;
	    *) 
	       echo "A filesystem-name has been specified: '${2}'"
	       shift 2;
	       ;;
	 esac
	 ;;
      --)
         shift
         break
         ;;
      *)
         echo "Internal error!"
         exit 1
         ;;
   esac
done

