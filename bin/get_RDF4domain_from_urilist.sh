#!/bin/bash
# This script is somewhat deprecated, better use get_RDF4domain_from_urilist_with_ETA.sh (20220404)

# Usage: download RDF files in parallel based on a text listfile 
#   get_RDF4domain_from_urilist.sh -h # get help; see also function usage()
# dependency: parallel
# dependency: dateutils
# dependency: date
# dependency: sed
# dependency: grep
# dependency: wget
# dependency: shuf


URI_LIST_FILE='urilist.txt'
# DOMAINNAME='data.nhm.ac.uk'
DOMAINNAME='jacq.org'
N_JOBS=5
DATETIME_NOW=$(date '+%Y%m%d-%H%M')

unset LOGFILE PROGRESS_LOGFILE test_mode randomize_urilist

function logfile_alternative () {
  x_placeholder="XXXXXXXX";
  x_placeholder=`printf '%*.*s\n' 0 ${#N_JOBS} "${x_placeholder}"`
  logfile_alternative=`printf "Thread-%s_${DOMAINNAME}_${DATETIME_NOW}.log" $x_placeholder`
}


this_wd="$PWD"
cd "${this_wd}"


if ! command -v parallel &> /dev/null
then
    echo -e "\e[31m# Error: Command parallel could not be found. Please install it.\e[0m"
    exit
fi

if ! command -v datediff &> /dev/null &&  ! command -v dateutils.ddiff &> /dev/null
then
  echo -e "\e[31m# Error: Neither command datediff or dateutils.ddiff could not be found. Please install package dateutils.\e[0m"
  exit
else
  if ! command -v datediff &> /dev/null
  then
    # echo "Command dateutils.ddiff found"
    exec_datediff="dateutils.ddiff"
  elif ! command -v dateutils.ddiff &> /dev/null
    then
      # echo "Command datediff found"
      exec_datediff="datediff"
  fi
fi

if ! command -v sed &> /dev/null
then
    echo -e "\e[31m# Error: Command sed (stream editor) could not be found. Please install it.\e[0m"
    exit
fi


function usage() { 
 logfile_alternative;
  echo    "# ################################################################" 1>&2; 
  echo -e "# Usage: \e[34m${0##*/}\e[0m [-u urilist_special.txt] [-j 10] [-d 'data.nhm.ac.uk']" 1>&2; 
  echo -e "#   What does \e[34m${0##*/}\e[0m do?" 1>&2; 
  echo    "#   Download RDF files in parallel from a list of URLs reading a text file into the current working directory." 1>&2; 
  echo    "#   The script will prompt before running except when you use the log file mode with option: -l" 1>&2; 
  echo    "# Options:" 1>&2; 
  echo    "#   -h  .......................... show this help usage" 1>&2; 
  echo -e "#   -d \e[32m'id.snsb.info'\e[0m ............ domainname of this harvest (default: data.nhm.ac.uk)" 1>&2; 
  echo    "#   -j 10 ........................ number of parallel jobs (default: 5)" 1>&2; 
  echo -e "#   -l ........................... logfile mode, without command prompt (into $logfile_alternative)" 1>&2; 
  echo    "#      Note that each Thread has its own log file logging URI and" 1>&2; 
  echo    "#      status code(s) of requests." 1>&2; 
  echo    "#   -t ........................... test mode: run 200 entries only" 1>&2; 
  echo -e "#   -u \e[32murilist_special.txt\e[0m ....... an uri list file (default: urilist.txt)" 1>&2; 
  echo    "#      Note that urilist.txt can be a csv export including a column:" 1>&2; 
  echo    "#      only an intact very first http(s)://URL in a line is used, also" 1>&2; 
  echo    "#      comments or strings behind the URL are filtered out." 1>&2; 
  echo    "#   -r ........................... randomize order from URI list" 1>&2; 
  echo    "# " 1>&2; 
  echo    "# Examples:" 1>&2; 
  echo    "#   Running normally with prompt before starting (progress to STDOUT)" 1>&2; 
  echo -e "#     \e[34m${0##*/}\e[0m -d id.snsb.info              # using default urilist.txt, set domainname only" 1>&2; 
  echo -e "#     \e[34m${0##*/}\e[0m -u snsb_20201102_occurrenceID.csv -d id.snsb.info " 1>&2; 
  echo    "#   Running in log file mode (immediately without a prompt!!)" 1>&2; 
  echo -e "#     \e[34m${0##*/}\e[0m -u snsb_20201102_occurrenceID.csv -l -d id.snsb.info & " 1>&2; 
  echo    "#     run in test mode (~200 jobs; do not add -l or -t at the end: it will not be processed correctly)" 1>&2; 
  echo -e "#     \e[34m${0##*/}\e[0m -u snsb_20201102_occurrenceID.csv -l -t -d id.snsb.info & " 1>&2; 
  echo    "# " 1>&2; 
  echo    "# To interrupt all the downloads in progress you have to:" 1>&2; 
  echo -e "#   (1) kill process ID (PID) of \e[34m${0##*/}\e[0m, find it by: « ps -fp \$(pgrep -d, --full ${0##*/}) »" 1>&2; 
  echo -e "#   (2) kill process ID (PID) of \e[34m/usr/bin/perl parallel\e[0m, find it by: « ps -fp \$(pgrep -d, --full parallel)' »" 1>&2; 
  echo    "# ################################################################" 1>&2; 
  exit 1; 
}

function processinfo () {
logfile_alternative
echo     "############ Download RDF from List of URIs #################"
if [[ -z ${randomize_urilist// /} ]] ; then
echo     "# It will download simply URIs by appending RDFs in parallel to something:"
else
echo  -e "# It will download \e[32m*randomized*\e[0m URIs by appending RDFs in parallel to something:"
fi
echo -e  "#   \e[32mThread-2_${DOMAINNAME}_${DATETIME_NOW}.rdf\e[0m"
echo -e  "# After finishing you can proceed with \e[32mfixRDF_before_validate.sh\e[0m"
if [[ -z ${PROGRESS_LOGFILE// /} ]];then
echo     "# Use -l to run in logfile mode (without this promt!!) This would log automatically into:"
echo -e  "#   \e[32m${logfile_alternative}\e[0m"
fi
echo     "# --------------------------------------------------------------"

if [[ -f "$URI_LIST_FILE" ]];then
  echo -e  "# Process \e[32m$TOTAL_JOBS\e[0m URIs using \e[32m${URI_LIST_FILE}\e[0m ..."
elif [[ -d "$URI_LIST_FILE" ]];then
  echo -e  "\e[31m# Error: default uri list was given as directory: ${URI_LIST_FILE} please provide a file ...\e[0m"; usage;exit 1;
else
  echo -e  "\e[31m# Error: default uri list file ${URI_LIST_FILE} was not found ...\e[0m"; usage;exit 1;
fi

echo -e  "# Number of parallel threads: .. \e[32m${N_JOBS}\e[0m"
if [[ -z ${PROGRESS_LOGFILE// /} ]];then
echo -e  "# Progress of this script is given to \e[32mSTDOUT\e[0m."
else
echo     "# Log progress to: ............. ${PROGRESS_LOGFILE}"
fi
echo     "# --------------------------------------------------------------"
echo -ne "# Do you want to proceed with downloading?\n# [\e[32myes\e[0m or \e[31mno\e[0m (default: no)]: "

}

# read command line options (those with a colon require a mandatory option argument)
while getopts "d:h:j:u:lrt" o; do
    case $o in
        d)
            DOMAINNAME=${OPTARG}
            if   [[ -z ${DOMAINNAME// /} ]] ; then echo "error: $DOMAINNAME cannot be empty" >&2; usage; exit 1; fi
            logfile_alternative
            ;;
        h)
            usage; exit 0;
            ;;
        j)
            N_JOBS=${OPTARG}
            re='^[0-9]+$'
            if ! [[ $N_JOBS =~ $re ]] ; then echo "error: $N_JOBS cannot be the number of parallel jobs" >&2; usage; exit 1; fi
            ;;
        l)
            PROGRESS_LOGFILE=${OPTARG}
            if   [[ -z ${PROGRESS_LOGFILE// /} ]] ; then logfile_alternative; PROGRESS_LOGFILE="$logfile_alternative" ; fi
            ;;
        u)
            URI_LIST_FILE=${OPTARG}
            ;;
        t)
            test_mode='yes'
            ;;
        r)
            randomize_urilist='yes'
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# process all variables first

if [[ -z ${randomize_urilist// /} ]] ; then
  if   [[ -z ${test_mode// /} ]] ; then
    TOTAL_JOBS=`cat "$URI_LIST_FILE" | sed --regexp-extended '/^[\s\t]*https?:/!d' | wc -l`
  else
    TOTAL_JOBS=`head -n200 "$URI_LIST_FILE" | sed --regexp-extended '/^[\s\t]*https?:/!d' | wc -l`
  fi
else
  if   [[ -z ${test_mode// /} ]] ; then
    TOTAL_JOBS=`cat "$URI_LIST_FILE" | shuf | sed --regexp-extended '/^[\s\t]*https?:/!d' | wc -l`
  else
    TOTAL_JOBS=`head -n200 "$URI_LIST_FILE" | shuf | sed --regexp-extended '/^[\s\t]*https?:/!d' | wc -l`
  fi
fi

get_info_http_return_codes() {
  # usage: get_info_http_return_codes 'output log from wget or curl something containing HTTP return codes'
  # dependency: awk
  # dependency: grep
  # dependency: wget
  local this_wget_log=$1   # 
  local this_return_codes=''   # 
  # wget output example:
  # HTTP request sent, awaiting response... 308 PERMANENT REDIRECT
  # HTTP request sent, awaiting response... 200 OK
  
  # wget output example on complete error
  # --2021-11-04 11:33:31--  https://w.jacq.org/WW9078905
  # Resolving w.jacq.org (w.jacq.org)... 160.45.63.46
  # Connecting to w.jacq.org (w.jacq.org)|160.45.63.46|:443... connected.
  # ERROR: The certificate of ‘w.jacq.org’ is not trusted.
  # ERROR: The certificate of ‘w.jacq.org’ has expired.

  this_return_codes=$(echo "$this_wget_log" | grep "HTTP request sent, awaiting response..." | awk 'BEGIN{ FS="\\.\\.\\. ";ORS=";"; }{ if ($2 >= 200 && $2 < 400) {print "OK:",$2} else {print "ERROR:",$2}}')
  
  if [[ -z ${this_return_codes// /} ]]; then
    this_error_messages=$(echo "$this_wget_log" | sed --silent '/^ERROR/{N;s@\n@ @;p}')
    echo "$this_wget_log" | sed --silent "1 { s@\$@ Codes: unknown. ${this_error_messages}@;p}"
  else
    echo "$this_wget_log" | sed --silent "1 { s@\$@ Codes: ${this_return_codes}@;p}"
  fi
}
export -f get_info_http_return_codes # to use it in the script

getrdf_with_urlstatus_check() {
  # function for use with parallel
  # usage: getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} uri [PROGRESS_LOGFILE]
  # dependency: get_info_http_return_codes
  # dependency: parallel
  # dependency: wget
  # dependency: sed

  # {%} {#} ${TOTAL_JOBS} uri [PROGRESS_LOGFILE]
  local this_job_number=$1   # {%}
  local this_job_counter=$2  # {#}
  local this_jobs_total=$3   # ${TOTAL_JOBS}
  local this_uri="$4"        # {} (is the uri)
  local this_domainname="$5"
  local this_datetime_now="$6"
  local this_progress_logfile="$7" # optional
  
  local this_loginfo=""  
  # local this_return_codes=""
  local this_debug_mode=0  # default 0, or 1 adds info to terminal
  this_loginfo=$(printf '%s file job %02d (step %06d of %06d)' Thread-${this_job_number}_${this_domainname}_${this_datetime_now}.rdf ${this_job_number} ${this_job_counter} ${this_jobs_total})
  # uri='https://data.nhm.ac.uk/object/a9f64c90-1703-4397-8a31-7a877e3e7d44'
  
  # -----------------
  # getting response-code before is slow; better let wget go ahead and evaluate the log after download
  # this_return_codes=$(wget --spider --server-response $this_uri 2>&1 | grep "HTTP/" | awk 'BEGIN{ ORS=";"; }{ if ($2 >= 200 && $2 < 400) {print "OK:",$2} else {print "ERROR:",$2}}')
  # https://data.nhm.ac.uk/object/a9f64c90-1703-4397-8a31-7a877e3e7d44;OK: 303;OK: 200;
  # https://data.nhm.ac.uk/object/a9f64c90-1703-4397-8a31-7a877e3e7d44-not-existing;ERROR: 404;
  # -----------------
  # using wget including download RDF
  # wget_log=$( { wget --header='Accept: application/rdf+xml' --max-redirect 4 --content-on-error -O - "http://data.nhm.ac.uk/object/4c19e397-de11-47ea-a775-5ae2869edb5d" >> "Thread-test.rdf" ; } 2>&1  )
  # this_return_codes=$(echo "$wget_log" | grep "HTTP request sent, awaiting response..." | awk 'BEGIN{ FS="\\.\\.\\. ";ORS=";"; }{ if ($2 >= 200 && $2 < 400) {print "OK:",$2} else {print "ERROR:",$2}}')
  # echo "$wget_log" | sed --silent "1 { s@\$@ Codes: ${this_return_codes}@;p}"
  # --2020-11-11 12:34:26--  http://data.nhm.ac.uk/object/4c19e397-de11-47ea-a775-5ae2869edb5d Codes: OK: 302 Redirect;OK: 303 SEE OTHER;OK: 200 OK;
  # -----------------
  # wget_log=$( { wget --header='Accept: application/rdf+xml' --max-redirect 4 -O - "$this_uri" >> "Thread-${this_job_number}_${this_domainname}_${this_datetime_now}.rdf"; } 2>&1  )
  wget_log=$( { wget --header='Accept: application/rdf+xml' --no-check-certificate --max-redirect 4 -O - "$this_uri" >> "Thread-${this_job_number}_${this_domainname}_${this_datetime_now}.rdf"; } 2>&1  )

  echo "$wget_log" >> "Thread-${this_job_number}_${this_domainname}_${this_datetime_now}.log"

  download_info="${this_loginfo} "`get_info_http_return_codes "$wget_log"`
  if   [[ -z ${this_progress_logfile// /} ]] ; then
    echo "${download_info}"
  else # output to log file
    echo "${download_info}" >> "${this_progress_logfile}"

    if [[ `echo "${download_info}" | grep --ignore-case 'ERROR' ` ]]; then
      echo "${download_info}" >> "${this_progress_logfile%.*}_error.log"
    fi
  fi
  if [[ $this_debug_mode -gt 0 ]];then
    echo "DEBUG: ${download_info} … ${this_progress_logfile}"
  fi
}
export -f getrdf_with_urlstatus_check # for use with parallel below

# DEBUG (in pure bash without datediff package)
# datetime_start=`date --rfc-3339 'seconds'`; unix_seconds_start=$(date +"%s")
# datetime_end=`date --rfc-3339 'seconds'`;   unix_seconds_end=$(date +"%s")
#   date -u -d "0 ${unix_seconds_end} sec -  ${unix_seconds_start} sec - $(date -u -d "$datetime_start - 1 day" +"%j") days" +"%j days (minus 1 day) %Hh%Mm%Ss"

if   [[ -z ${PROGRESS_LOGFILE// /} ]] ; then
  processinfo
  read yno
  case $yno in
    [yY]|[yY][Ee][Ss])
      echo  "# Continue ..."
    ;;
    [nN]|[nN][oO])
      echo "# Stop";
      exit 1
    ;;
    *) 
      echo "# Invalid or no input (stop)"
      exit 1
    ;;
  esac
  
  # correct start time
  datetime_start=`date --rfc-3339 'seconds'`; # unix_seconds_start=$(date +"%s")

  if [[ -z ${randomize_urilist// /} ]] ; then
    if   [[ -z ${test_mode// /} ]] ; then
      cat "$URI_LIST_FILE" | sed --regexp-extended 's@\r@@g;/^[\s\t]*https?:/!d;s@.*(https?://[^\s\t]+).*@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW}"
      # extract only the (https?://…)
    else
      echo "# Running in test mode ($TOTAL_JOBS jobs)" 
      # head -n200 "$URI_LIST_FILE" | sed --regexp-extended '/^https?:/!d;s@\r@@g' | parallel -j$N_JOBS echo {%} {#} ${TOTAL_JOBS} {}
      head -n200 "$URI_LIST_FILE" | sed --regexp-extended 's@\r@@g;/^[\s\t]*https?:/!d;s@.*(https?://[^\s\t]+).*@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW}"
      # extract only the (https?://…)
    fi
  else
    if   [[ -z ${test_mode// /} ]] ; then
      cat "$URI_LIST_FILE" | shuf | sed --regexp-extended 's@\r@@g;/^[\s\t]*https?:/!d;s@.*(https?://[^\s\t]+).*@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW}"
      # extract only the (https?://…)
    else
      echo "# Running in test mode ($TOTAL_JOBS jobs)" 
      # head -n200 "$URI_LIST_FILE" | sed --regexp-extended '/^https?:/!d;s@\r@@g' | parallel -j$N_JOBS echo {%} {#} ${TOTAL_JOBS} {}
      head -n200 "$URI_LIST_FILE" | shuf | sed --regexp-extended 's@\r@@g;/^[\s\t]*https?:/!d;s@.*(https?://[^\s\t]+).*@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW}"
      # extract only the (https?://…)
    fi
  fi
  
  datetime_end=`date --rfc-3339 'seconds'`; 
  # take end time
  # unix_seconds_end=$(date +"%s")
  # echo `date -u -d "0 ${unix_seconds_end} sec -  ${unix_seconds_start} sec - $(date -u -d "$datetime_start - 1 day" +"%j") days" +"Done. $TOTAL_JOBS jobs took %j days (minus 1 day) %Hh%Mm%Ss"`
  echo "# Started: $datetime_start" 
  echo "# Ended:   $datetime_end"   
  $exec_datediff "$datetime_start" "$datetime_end" -f "# Done. $TOTAL_JOBS jobs took %dd %Hh:%Mm:%Ss" 

else   # PROGRESS_LOGFILE and log into file
  logfile_alternative; PROGRESS_LOGFILE=$logfile_alternative
  datetime_start=`date --rfc-3339 'seconds'`; unix_seconds_start=$(date +"%s")
  # take start time
  if   [[ -z ${test_mode// /} ]] ; then
    echo -e "# Running $TOTAL_JOBS jobs. See progress log files:\n  tail ${PROGRESS_LOGFILE} # logging all progress or\n  tail ${PROGRESS_LOGFILE%.*}_error.log # loggin errors only: 404 500 etc." 
    echo -e "# ------------------------------" 1>&2; 
    echo -e "# To interrupt all the downloads in progress you have to:" 1>&2; 
    echo -e "#   (1) kill process ID (PID) of \e[34m${0##*/}\e[0m, find it by: « ps -fp \$(pgrep -d, --full ${0##*/}) »" 1>&2; 
    echo -e "#   (2) kill process ID (PID) of \e[34m/usr/bin/perl parallel\e[0m, find it by: « ps -fp \$(pgrep -d, --full parallel)' »" 1>&2; 
    processinfo             &>> "${PROGRESS_LOGFILE}"
    echo " yes"             &>> "${PROGRESS_LOGFILE}"
    if [[ -z ${randomize_urilist// /} ]] ; then
      cat "$URI_LIST_FILE" | sed --regexp-extended '/^https?:/!d;s@\r@@g;s@.*(https?://[^ ]+).*@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW}" "${PROGRESS_LOGFILE}"
    else
      cat "$URI_LIST_FILE" | shuf | sed --regexp-extended '/^https?:/!d;s@\r@@g;s@.*(https?://[^ ]+).*@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW}" "${PROGRESS_LOGFILE}"
    fi
  else
    echo -e "# Running in TEST MODE ($TOTAL_JOBS jobs). See progress log files:\n  tail ${PROGRESS_LOGFILE} # logging all progress or\n  tail ${PROGRESS_LOGFILE%.*}_error.log # loggin errors only: 404 500 etc." 
    echo -e "# ------------------------------" 1>&2; 
    echo -e "# To interrupt all the downloads in progress you have to:" 1>&2; 
    echo -e "#   (1) kill process ID (PID) of \e[34m${0##*/}\e[0m, find it by: « ps -fp \$(pgrep -d, --full ${0##*/}) »" 1>&2; 
    echo -e "#   (2) kill process ID (PID) of \e[34m/usr/bin/perl parallel\e[0m, find it by: « ps -fp \$(pgrep -d, --full parallel)' »" 1>&2; 
    processinfo             &>> "${PROGRESS_LOGFILE}"
    echo " yes"             &>> "${PROGRESS_LOGFILE}"
    if [[ -z ${randomize_urilist// /} ]] ; then
      head -n200 "$URI_LIST_FILE" | sed --regexp-extended '/^https?:/!d;s@\r@@g;s@.*(https?://[^ ]+).*@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW}" "${PROGRESS_LOGFILE}"
    else
      head -n200 "$URI_LIST_FILE" | shuf | sed --regexp-extended '/^https?:/!d;s@\r@@g;s@.*(https?://[^ ]+).*@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW}" "${PROGRESS_LOGFILE}"
    fi
  fi

  datetime_end=`date --rfc-3339 'seconds'`; 
  # take end time
  echo "# Started: $datetime_start" >> "${PROGRESS_LOGFILE}"
  echo "# Ended:   $datetime_end"   >> "${PROGRESS_LOGFILE}"
  $exec_datediff "$datetime_start" "$datetime_end" -f "# Done. $TOTAL_JOBS jobs took %dd %Hh:%Mm:%Ss" >> "${PROGRESS_LOGFILE}"
  # unix_seconds_end=$(date +"%s")
  # echo `date -u -d "0 ${unix_seconds_end} sec -  ${unix_seconds_start} sec - $(date -u -d "$datetime_start - 1 day" +"%j") days" +"Done. $TOTAL_JOBS jobs took %j days (minus 1 day) %Hh%Mm%Ss"` >> "${PROGRESS_LOGFILE}"
fi
