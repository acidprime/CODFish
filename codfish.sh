#!/bin/bash
# set -xv
[ "$EUID" != 0 ] &&	printf "%s\n" "This script requires root access ($EUID)!" && exit 1

# Edit the following settings to match your environment
DRY_RUN=NO # set to "no" when you're ready to do this for real
YOUR_USERNAME="bobsyouruncle"
YOUR_OU="ou=ITS-Academic IT Services,ou=Information Technology Services,o=example"
LDAP_SERVER="ldap://magis.example.loc"
YOUR_PASSWORD="MacAD2010"
DIRECTORY_SERVICE="/LDAPv3/127.0.0.1"
HOME_SERVER="server.example.com"
HOME_URL="afp://$HOME_SERVER/Users"
HOME_PATH="/Network/Servers/$HOME_SERVER/Volumes/DATA1/Users"
PGID=20
OD_ADMIN="diradmin"
OD_PASS="foobar"

# -- Runtime varibles
declare -x SCRIPT="${0##*/}" ; SCRIPT_NAME="${SCRIPT%%\.*}"
declare -x SCRIPTPATH="$0" RUNDIRECTORY="${0%/*}"
declare -x SYSTEM_VERSION="/System/Library/CoreServices/SystemVersion.plist"
declare -x OSVER="$(/usr/bin/defaults read "${SYSTEM_VERSION%.plist}" ProductVersion )"
declare -x DATE="$(/bin/date +%Y-%m-%d-%H_%M_%S)"
declare -x CONFIG_FILE="${RUNDIRECTORY:?}/${SCRIPT_NAME}.conf"
declare -x HOST_NAME="`/bin/hostname`"
declare -ix MAX_LOG_SIZE="50"
declare -x BUILDVERSION="2001111"
declare -x PATH=/bin:/usr/bin:/sbin:/usr/sbin

declare -x awk="/usr/bin/awk"
declare -x cat="/bin/cat"
declare -x dsmemberutil="/usr/bin/dsmemberutil"
declare -x dseditgroup="/usr/sbin/dseditgroup"
declare -x mkfifo="/usr/bin/mkfifo"
declare -x ldapsearch="/usr/bin/ldapsearch"
declare -x rm="/bin/rm "
declare -x mkdir="/bin/mkdir"
declare -x du="/usr/bin/du"
declare -x cp="/bin/cp"
declare -x open="/usr/bin/open"

declare -x dscl="/usr/bin/dscl"
declare -x defaults="/usr/bin/defaults"
declare -x id="/usr/bin/id"
declare -x ntpdate="ntpdate"
declare -x scutil="/usr/sbin/scutil"
declare -x perl="/usr/bin/perl"
declare -x basename="/usr/bin/basename"
declare -x date="/bin/date" 
declare -x defaults="/usr/bin/defaults"
declare -x dscl="/usr/bin/dscl"
declare -x find="/usr/bin/find"
declare -x groups="/usr/bin/groups"
declare -x id="/usr/bin/id"
declare -x ls="/bin/ls"
declare -x mv="/bin/mv"
declare -x rmdir="/bin/rmdir"
declare -x sudo="/usr/bin/sudo"
declare -x uuidgen="/usr/bin/uuidgen"
declare -x plistbuddy="/usr/libexec/PlistBuddy"
declare -x mbr_enum="${RUNDIRECTORY}/mbr_enum"
declare -x REQ_CMDS="$mbr_enum"



# -- Start the script log
# Set to "VERBOSE" for more logging prior to using -v
declare -x LOG_DIRECTORY="/Library/Logs/$SCRIPT_NAME"
if [ ! -d "$LOG_DIRECTORY" ] ; then
	$mkdir -p "$LOG_DIRECTORY"
fi
declare -x LOGLEVEL="NORMAL" SCRIPTLOG="$LOG_DIRECTORY/${SCRIPT%%\.*}_$DATE.log"

if [ -f "$SCRIPTLOG" ] ; then
declare -i CURRENT_LOG_SIZE="$("$du" -hm "${SCRIPTLOG:?}" |
                                "$awk" '/^[0-9]/{print $1;exit}')"
fi
if [ ${CURRENT_LOG_SIZE:=0} -gt "$MAX_LOG_SIZE" ] ; then
	"$rm" "$SCRIPTLOG"
        StatusMessage "LOGSIZE:$CURRENT_LOG_SIZE, too large removing"
fi

exec 2>>"${SCRIPTLOG:?}" # Redirect standard error to log file
# Strip any extention from SCRIPT_NAME and log stderr to script log
if [ -n ${SCRIPTLOG:?"The script log has not been specified"} ] ; then
	printf "%s\n" \
"STARTED:$SCRIPT_NAME:EUID:$EUID:$DATE: Mac OS X $OSVER:BUILD:$BUILDVERSION" >>"${SCRIPTLOG:?}"
	printf "%s\n" "Log file is: ${SCRIPTLOG:?}"
fi


StatusMessage() { # Status message function with type and now color!
# Requires SCRIPTLOG STATUS_TYPE=1 STATUS_MESSAGE=2

declare date="${date:="/bin/date"}"
declare DATE="$("$date" -u "+%Y-%m-%d")"
declare STATUS_TYPE="$1" STATUS_MESSAGE="$2"
if [ "$ENABLECOLOR" = "YES"  ] ; then
	# Background Color
	declare REDBG="41" WHITEBG="47" BLACKBG="40"
	declare YELLOWBG="43" BLUEBG="44" GREENBG="42"
	# Foreground Color
	declare BLACKFG="30" WHITEFG="37" YELLOWFG="33"
	declare BLUEFG="36" REDFG="31"
	declare BOLD="1" NOTBOLD="0"
	declare format='\033[%s;%s;%sm%s\033[0m\n'
	# "Bold" "Background" "Forground" "Status message"
	printf '\033[0m' # Clean up any previous color in the prompt
else
	declare format='%s\n'
fi
# Function only seems to work on intel and higher.
showUIDialog(){
StatusMessage header "FUNCTION: #	$FUNCNAME" ; unset EXITVALUE TRY
"$killall" -HUP "System Events" 2>/dev/null
declare -x UIMESSAGE="$1"
"$osascript" <<EOF
try
with timeout of 0.1 seconds
	tell application "System Events"
		set UIMESSAGE to (system attribute "UIMESSAGE") as string
		activate
			display dialog UIMESSAGE with icon 2 giving up after "3600" buttons "Dismiss" default button "Dismiss"
		end tell
	end timeout
end try
EOF
return 0
} # END showUIDialog()

case "${STATUS_TYPE:?"Error status message with null type"}" in
	progress) \
	[ -n "$LOGLEVEL" ] &&
	printf $format $NOTBOLD $WHITEBG $BLACKFG "PROGRESS:$STATUS_MESSAGE"  ;
	printf "%s\n" "$DATE:PROGRESS: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
	# Used for general progress messages, always viewable
	
	notice) \
	printf "%s\n" "$DATE:NOTICE:$STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
	[ -n "$LOGLEVEL" ] &&
	printf $format $NOTBOLD $YELLOWBG $BLACKFG "NOTICE  :$STATUS_MESSAGE"  ;;
	# Notifications of non-fatal errors , always viewable
	
	error) \
		printf "%s\n\a" "$DATE:ERROR:$STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
		printf "%s\n\a" "$DATE:ERROR:$STATUS_MESSAGE" >> "${SCRIPTLOG%.log}_error.log" ;
	[ -n "$LOGLEVEL" ] &&
	printf $format $NOTBOLD $REDBG $YELLOWFG "ERROR   :$STATUS_MESSAGE"  ;;
	# Errors , always viewable

	verbose) \
	printf "%s\n" "$DATE:VERBOSE: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;
	[ "$LOGLEVEL" = "VERBOSE" ] &&
	printf $format $NOTBOLD $WHITEBG $BLACKFG "VERBOSE :$STATUS_MESSAGE" ;;
	# All verbose output
	
	header) \
	[ "$LOGLEVEL" = "DEBUG" ] &&
	printf $format $NOTBOLD $BLUEBG $BLUEFG "VERBOSE :$STATUS_MESSAGE" ;
	printf "%s\n" "$DATE:PROGRESS: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
	# Function and section headers for the script
	
	passed) \
	[ "$LOGLEVEL" = "VERBOSE" ] &&
	printf $format $NOTBOLD $GREENBG $BLACKFG "PASSED  :$STATUS_MESSAGE" ;
	printf "%s\n" "$DATE:PASSED: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;
	# Sanity checks and "good" information
	graphical) \
	[ "$GUI" = "ENABLED" ] &&
	showUIDialog "$STATUS_MESSAGE" ;;
	
	debug) \
	[ "$LOGLEVEL" = "DEBUG" ] &&
	printf $format $NOTBOLD $WHITEBG $BLACKFG  "DEBUG  :$STATUS_MESSAGE" ;
	printf "%s\n" "$DATE:DEBUG: $STATUS_MESSAGE" >> "${SCRIPTLOG:?}" ;;

	
esac
return 0
} # END StatusMessage()


die() { # die Function
StatusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE
declare LASTDIETYPE="$1" LAST_MESSAGE="$2" LASTEXIT="$3"
declare LASTDIETYPE="${LASTDIETYPE:="UNTYPED"}"
if [ ${LASTEXIT:="192"} -gt 0 ] ; then
        StatusMessage error "$LASTDIETYPE :$LAST_MESSAGE:EXIT:$LASTEXIT"
        # Print specific error message in red
else
        StatusMessage verbose "$LASTDIETYPE :$LAST_MESSAGE:EXIT:$LASTEXIT"
        # Print specific error message in white
fi
	StatusMessage verbose "COMPLETED:$SCRIPT IN $SECONDS SECONDS"
	"$killall" "System Events"
exit "${LASTEXIT}"      # Exit with last status or 192 if none.
return 1                # Should never get here
} # END die()


CleanUp() { # -- Clean up of our inportant sessions variables and functions.
StatusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE
StatusMessage verbose "TIME: $SCRIPT ran in $SECONDS seconds"
unset -f ${!check*}
[ "${ENABLECOLOR:-"ENABLECOLOR"}" = "YES"  ] && printf '\033[0m' # Clear Color

if [ "$PPID" == 1 ] ; then # LaunchD is always PID 1 in 10.4+
	: # Future LaunchD code
fi
if [ $DRY_RUN == "NO" ]; then
	$rm /tmp/dsclcommands
else
	$open -e /tmp/dsclcommands
fi
exec 2>&- # Reset the error redirects
return 0
} # END CleanUp()

ShowUsage(){
	StatusMessage header "FUNCTION: #       $FUNCNAME" ; unset EXITVALUE
	printf "%s\n\t" "USAGE:"
	printf "%s\n\t" 
	printf "%s\n\t" " OUTPUT:"
	printf "%s\n\t" " -v | # Turn on verbose output"
	printf "\033[%s;%s;%sm%s\033[0m\n\t" "1" "44" "37" " -C | # Turn on colorized output"
	printf "\033[0m"
	printf "%s\n\t" " -u | # Turn on graphical display box support"
	printf "%s\n\t" " OTHER TASKS:"
	printf "%s\n\t" " -f | </path/to/import.csv>	# Read configuration from a csv file."
	printf "%s\n\t" " -a # Add users in all groups from Directory Service node"
	printf "%s\n\t" " -d | <DirectoryService>	# Directory Service i.e \"/LDAPv3/127.0.0.1\""
	printf "%s\n\t" " -g | <groupshortname>	# Group shortname i.e \"its_admin\""
	printf "%s\n\t" " -w | /path/to/export.csv	# Path to write the post processed CSV"
	printf "%s\n\t" " -h | # Print this usage message and quit"
	printf "%s\n\t"
	printf "%s\n\t" " EXAMPLE SYNTAX:"
	printf "%s\n\t" " -- Augment users in group its_admin:"
	printf "%s\n\t" " sudo $0 -Cv -g its_admin -d /LDAPv3/127.0.0.1"
	printf "%s\n\t" " -- Augment users in file old.csv after ldap lookups of name:"
	printf "%s\n\t" " sudo $0 -Cv -f ./old.csv -w ./new.csv -d /LDAPv3/127.0.0.1"
	printf "%s\n\t" " -- Augment all groups in directory service node specified"
	printf "%s\n\t" " sudo $0 -Cv -a -d /LDAPv3/127.0.0.1"
	printf "%s\n"
	return 0
}


checkLineEndings(){
	declare -i FUNCSECONDS="$SECONDS" # Capture start time
	declare FILE_TO_CHECK="$1"
	StatusMessage header  "FUNCTION: #      ${FUNCNAME}" ; unset EXITVALUE
	if [ -f "$FILE_TO_CHECK" ] ; then
		if ! $perl -ne "exit 1 if m/\r\n/;" "$FILE_TO_CHECK" ; then
			StatusMessage notice \
			"Incorrect line endings detected (probobly due to Mircosoft edit)"
			StatusMessage notice \
			"Backup: $CSV_FILE.bak"
			$cp -f "$FILE_TO_CHECK" "$FILE_TO_CHECK".bak
			StatusMessage verbose 'Resetting line endings \r/\n/ to \n'
			$perl -i -pe 's/\r/\n/g' "$FILE_TO_CHECK"
		elif ! $perl -ne "exit 1 if m/\r/;" "$FILE_TO_CHECK" ; then
			StatusMessage notice \
			"Incorrect line endings detected (DOS?) fixing backup: $FILE_TO_CHECK.bak"
			$cp -f "$FILE_TO_CHECK" "$FILE_TO_CHECK".bak
			StatusMessage verbose 'Resetting line endings \r/\n/'
			$perl -i -pe 's/\r/\n/g' "$FILE_TO_CHECK"

		fi
	else
		StatusMessage error "File: $FILE_TO_CHECK does not exist"
		die ERROR "Invalid file specified: $FILE_TO_CHECK"
	fi
	StatusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds to EXIT:$EXITVALUE"
}
CheckCommands() { # CHECK_CMDS Required Commands installed check using the REQCMDS varible.
declare -i FUNCSECONDS="$SECONDS" # Capture start time
StatusMessage header  "FUNCTION: #      ${FUNCNAME}" ; unset EXITVALUE
declare REQCMDS="$1"
for RQCMD in ${REQCMDS:?} ; do
        if [  -x "$RQCMD" ] ; then
                StatusMessage passed "PASSED: $RQCMD is executable"
        else
        # Export the command Name to the die status message can refernce it"
                export RQCMD ; return 1
        fi
        done
return 0
declare -i FUNCTIME=$(( ${SECONDS:?} - ${FUNCSECONDS:?} ))
[ "${FUNCTIME:?}" != 0 ] &&
StatusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds to EXIT:$EXITVALUE"
} # END CheckCommands()


CheckSystemVersion() { 
# CHECK_OS Read the /Sys*/Lib*/CoreSer*/S*Version.plist value for OS version
StatusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
declare OSVER="$1"
case "${OSVER:?}" in
	10.0* | 10.1* | 10.2* | 10.3* | 10.4*) \
	die ERROR "$FUNCNAME: Unsupported OS version: $OSVER." 192 ;;
	
    10.5*) \
		StatusMessage passed "CHECK_OS: OS check: $OSVER successful!";
		return 0;;
	
	10.6*) \
		StatusMessage passed "CHECK_OS: OS check: $OSVER successful!";
		return 0;;
	*) \
	die ERROR "CHECK_OS:$LINENO Unsupported OS:$OSVER unknown error" 192 ;;
esac
StatusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds to EXIT:$EXITVALUE"
return 1
} # END checkSYSTEM_VERSION()
CreateHomeDirectories(){
	:
}
UpdateAugmentsFromGroup(){
	StatusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE

	declare GROUP_NAME="$1"
	OLD_IFS="$IFS"
	IFS=$'\n'
	for LINE in `$mbr_enum "$GROUP_NAME"` ; do

	declare -x SHORT_NAME="$(printf "$LINE" |
	 					$awk -F'^' '{print $1;exit}')"
	if [ "${SHORT_NAME:-"null"}" = "null" ] ; then
		StatusMessage error "Skipping line: $LINE due to null field"
	fi
	declare -x REAL_NAME="$(printf "$LINE" |
						$awk -F'^' '{print $2;exit}')"
	declare -xi UNIQUE_ID="$(printf "$LINE" |
						$awk -F'^' '{print $3;exit}')"
	
	declare -x UUID="$($dsmemberutil getuuid -u $UNIQUE_ID)"
	StatusMessage progress "Processing $SHORT_NAME:$REAL_NAME:$UNIQUE_ID:$uuid"

	declare -x CURRENT_NFSHOME_DIRECTORY="$($dscl /Search -read "/Users/$SHORT_NAME" NFSHomeDirectory | awk '{print $NF;exit}')"

	if [ "$CURRENT_NFSHOME_DIRECTORY" = "$HOME_PATH/$SHORT_NAME" ] ; then
		StatusMessage error "User: $SHORT_NAME is already configured"
		continue
	else
		StatusMessage notice "User: $SHORT_NAME is not configured"
	fi

	echo "" | $awk -v home_url="$HOME_URL" \
	  -v home_path="$HOME_PATH" -v sn="$SHORT_NAME" -v ln="$REAL_NAME" -v uid="$UNIQUE_ID" -v group="$GROUP_NAME" -v uuid="$UUID" -v pgid="$PGID" '
	BEGIN {
		print "auth diradmin $OD_PASS" >> "/tmp/dsclcommands"
	}
	{
		printf("create /Augments/Users:%s RealName \"%s\"\n", sn, ln) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s GeneratedUID %s\n", sn, uuid) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s HomeDirectory <home_dir><url>%s</url><path>%s</path></home_dir>\n", sn, home_url, sn) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s NFSHomeDirectory %s/%s\n", sn, home_path, sn) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s UniqueID %s\n", sn, uid) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s PrimaryGroupID %s\n", sn, pgid) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s Keywords \"%s\"\n", sn, group) >> "/tmp/dsclcommands"
	}'
	done
	StatusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds to EXIT:$EXITVALUE"
}

UpdateAugmentsFromFile(){
	StatusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
	for LINE in `$cat "${EXPORT_FILE:?}"` ; do
		declare SHORT_NAME="$(printf "$LINE" | awk -F ',' '{print $NF}')"
	if $id $SHORT_NAME &>/dev/null ; then
		declare REAL_NAME="$($dscl -url /Search -read "/Users/$SHORT_NAME" RealName |
						$awk '/RealName/{
						getline
						gsub(" ","")
						gsub("%20"," ")
						print}')"
		declare -i UNIQUE_ID="$($dscl -url /Search -read "/Users/$SHORT_NAME" UniqueID |
					$awk '/UniqueID/{
						print $NF
						exit}')"

		declare UUID="$(dsmemberutil getuuid -u $UNIQUE_ID)"
		declare GROUP_NAME="$(printf "$LINE" | $awk -F ',' '{print $1}' | tr '[:upper:]' '[:lower:]' )"

		echo "" | $awk -v home_url="$HOME_URL" \
		  -v home_path="$HOME_PATH" -v sn="$SHORT_NAME" -v ln="$REAL_NAME" -v uid="$UNIQUE_ID" -v group="$GROUP_NAME" -v uuid="$UUID" -v pgid="$PGID" '
	BEGIN {
		print "auth diradmin c@rd1n@ls" >> "/tmp/dsclcommands"
	}
	 {
		printf("create /Augments/Users:%s RealName \"%s\"\n", sn, ln) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s GeneratedUID %s\n", sn, uuid) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s HomeDirectory <home_dir><url>%s</url><path>%s</path></home_dir>\n", sn, home_url, sn) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s NFSHomeDirectory %s/%s\n", sn, home_path, sn) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s UniqueID %s\n", sn, uid) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s PrimaryGroupID %s\n", sn, pgid) >> "/tmp/dsclcommands"
		printf("create /Augments/Users:%s Keywords \"%s\"\n", sn, keyword) >> "/tmp/dsclcommands"
	}' 
			if [ "$ADD_USERS_TO_GROUPS" = 'YES' ] ; then
				StatusMessage progress "Adding $SHORT_NAME to group $GROUP_NAME"
				$dseditgroup -o edit -n "$DIRECTORY_SERVICE" -u "$OD_ADMIN" -P "$OD_PASS" -a "$SHORT_NAME" -t user "$GROUP_NAME"
			fi
	else
		StatusMessage error "User: $SHORT_NAME is not a valid user account"
	fi
	done
	StatusMessage verbose "TIME:$FUNCNAME:Took $FUNCTIME seconds to EXIT:$EXITVALUE"
}


PreProcessCSV(){
	StatusMessage header "FUNCTION: #	${FUNCNAME}" ; unset EXITVALUE
	declare CSV_FILE="$1"
	OLDIFS="$IFS"
	printf "" > "$EXPORT_FILE"
	IFS=$'\n'
	for LINE in `$cat "${CSV_FILE:?}"` ; do 
		# CMM47201_201020,940552,Ritthaler
		declare CLASS="$(printf "$LINE" | $awk -F',' '{print $1;exit}')"
		declare IDNO="$(printf "$LINE" | $awk -F',' '{print $2;exit}')"
		declare LAST_NAME="$(printf "$LINE" | $awk -F',' '{print $3;exit}' | $awk '{print $1;exit}')"
		if [ ${#IDNO} -le 7 ] ;then
			declare IDNO="0$IDNO"
		fi
		if [ ${#IDNO} -le 8 ] ;then
			declare IDNO="0$IDNO"
		fi
		if [ ${#IDNO} -le 9 ] ;then
			declare IDNO="0$IDNO"
		fi
		declare SLU_ID="$($ldapsearch -H $LDAP_SERVER -D "cn=$YOUR_USERNAME,$YOUR_OU" -x -w "$YOUR_PASSWORD" -b 'o=example' -LLL "(&(sn=$LAST_NAME*)(workforceID=$IDNO))" cn workforceID | awk '/^cn:/{print $NF;exit}')"
		echo $CLASS,$IDNO,$LAST_NAME,${SLU_ID:-"null"}
		echo $CLASS,$IDNO,$LAST_NAME,${SLU_ID:-"null"} >> "$EXPORT_FILE"
	done
	IFS="$OLDIFS"
}
# Check script options
StatusMessage header "GETOPTS: Processing script $# options:$@"
# ABOVE: Check to see if we are running as a postflight script,the installer  creates $SCRIPT_NAME
if [ $# = 0 ]  ; then 
	StatusMessage verbose "No options given"
	ShowUsage && exit 1
fi
# If we are not running postflight and no parameters given, print usage to stderr and exit status 1
while getopts vCau:f:g:w:d: SWITCH ; do
        case $SWITCH in
		a ) export ALL_GROUPS="YES" ;;
                v ) export LOGLEVEL="VERBOSE" ;;
		d ) export DIRECTORY_SERVICE="$OPTARG" ;; 
                C ) export ENABLECOLOR="YES" ;;
                u ) export GUI="ENABLED" ;;
        	w ) export EXPORT_FILE="$OPTARG" ;;
			f ) export CSV_FILE="$OPTARG" ;;
		g ) export GROUP_NAME="$OPTARG" ;;
		h ) ShowUsage && exit 1 ;;
	esac
done # END getopts
StatusMessage header "Starting Main Routine $SCRIPT_NAME"

CheckSystemVersion "$OSVER"
CheckCommands "$REQ_CMDS"

#if [ $DRY_RUN == "NO" ]; then
	if [ -f /tmp/dsclcommands ] ;then
		$rm /tmp/dsclcommands
	fi
#	$mkfifo /tmp/dsclcommands
#fi


if [ ${#GROUP_NAME} -gt 0 ] ; then
	StatusMessage progress "Processing Single group $GROUP_NAME"
	UpdateAugmentsFromGroup "$GROUP_NAME"
fi
if [ "$ALL_GROUPS" = YES ] ; then
	StatusMessage progress "Processing all groups in $DIRECTORY_SERVICE"
	declare -ax OD_GROUPS=(`$dscl "$DIRECTORY_SERVICE" -list /Groups`)
	for GROUP_NAME in ${OD_GROUPS[@]} ; do
		case "$GROUP_NAME" in
			staff ) continue ;;
			admin ) continue ;;
			com.apple.limited_admin ) continue ;;
		esac
		StatusMessage progress "Processing group: $GROUP_NAME"
		UpdateAugmentsFromGroup "$GROUP_NAME"
	done
fi
if [ "${#CSV_FILE}" -gt 0 ] ; then
	StatusMessage progress "Processing all users in $CSV_FILE"

		checkLineEndings "$CSV_FILE"
		PreProcessCSV "$CSV_FILE"
		if  [ "${#EXPORT_FILE}" -gt 0 ] ; then
			UpdateAugmentsFromFile "$EXPORT_FILE"
		fi
fi
if [ "$HOME_SERVER" = "${HOST_NAME:-"$HOSTNAME"}" ] ; then
	CreateHomeDirectories
fi
$dscl "$DIRECTORY_SERVICE" < /tmp/dsclcommands
CleanUp && exit 0
