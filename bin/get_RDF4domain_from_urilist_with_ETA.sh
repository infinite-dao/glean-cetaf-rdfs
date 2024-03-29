#!/bin/bash
set -eu
  # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
  # set -e -- option will cause a bash script to exit immediately when a command fails
  # set -o -- exit also on non-existing command, print also BASH settings
  # set -u -- this option causes the bash shell to treat unset variables as an error and exit immediately.
  # set -x -- the -x option causes bash to print each command before executing it. This can be a great help when trying to debug a bash script failure. Note that arguments get expanded before a command gets printed, which will cause our logs to contain the actual argument values that were present at the time of execution!
  # set -E -- traps are pieces of code that fire when a bash script catches certain signals. Aside from the usual signals (e.g. SIGINT, SIGTERM, …), traps can also be used to catch special bash signals like EXIT, DEBUG, RETURN, and ERR. However, reader Kevin Gibbs pointed out that using -e without -E will cause an ERR trap to not fire in certain scenarios.
# Usage: download RDF files in parallel based on a text urilistfile and compress eventually harvested RDFs
#   get_RDF4domain_from_urilist.sh -h # get help; see also function usage()
# dependency: parallel (2016 )
# dependency: dateutils
# dependency: date
# dependency: sed
# dependency: grep
# dependency: wget
# dependency: shuf
# dependency: gzip
# dependency: awk


DOMAINNAME='jacq.org'
# DOMAINNAME='data.nhm.ac.uk'

URI_LIST_FILE="urilist_$DOMAINNAME.txt"
N_JOBS=10
do_exit=0

DATETIME_NOW_YmdHM=$(date '+%Y%m%d-%H%M')
# DATETIME_NOW_YmdHM_NANOSECONDS=$(date --rfc-3339 'ns')
# 
DEBUGLOGFILE=get_RDF4domain_from_urilist_debug.log
export DEBUGLOGFILE # get it accessible in getrdf_with_urlstatus_check() (?and other functions)

PROGRESS_LOGFILE=""
test_mode=''
randomize_urilist=''

function logfile_alternative () {
  x_placeholder="XXXXXXXX";
  x_placeholder=`printf '%*.*s\n' 0 ${#N_JOBS} "${x_placeholder}"`
  logfile_alternative=`printf "Thread-%s_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.log" $x_placeholder`
}


this_wd="$PWD"
cd "${this_wd}"

if ! command -v parallel &> /dev/null
then
    echo -e "\e[31m# Error: Command parallel could not be found. Please install it.\e[0m"
    do_exit=1
fi

if ! command -v datediff &> /dev/null &&  ! command -v dateutils.ddiff &> /dev/null
then
  echo -e "\e[31m# Error: Neither command datediff or dateutils.ddiff could not be found. Please install package dateutils.\e[0m"
  do_exit=1
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
    do_exit=1
fi


if [[ $do_exit -gt 0 ]];then
  exit
fi

function usage() { 
 logfile_alternative;
  echo    "# ############ Download RDF from List of URIs #################" 1>&2; 
  echo -e "# Usage: \e[34m${0##*/}\e[0m [-u urilist_special.txt] [-j 10] [-d '$DOMAINNAME']" 1>&2; 
  echo -e "#   What does \e[34m${0##*/}\e[0m do?" 1>&2; 
  echo    "#   Download RDF files in parallel from a list of URLs reading a text file into the current working directory." 1>&2; 
  echo    "#   The script will prompt before running except when you use the log file mode with option: -l" 1>&2; 
  echo    "# Options:" 1>&2; 
  echo    "#   -h  .......................... show this help usage" 1>&2; 
  echo -e "#   -d \e[32m'id.snsb.info'\e[0m ............ domainname of this harvest (default: $DOMAINNAME)" 1>&2; 
  echo    "#   -j 15 ........................ number of parallel jobs (default: $N_JOBS)" 1>&2; 
  echo -e "#   -l ........................... logfile mode, without command prompt (into \e[32m$logfile_alternative\e[0m)" 1>&2; 
  echo    "#      Note that each Thread has its own log file, logging URI, and" 1>&2; 
  echo    "#      status code(s) of requests." 1>&2; 
  echo    "#   -t ........................... test mode: run 200 entries only" 1>&2; 
  echo -e "#   -u \e[32murilist_special.txt\e[0m ....... an uri list file (default: \e[32m$URI_LIST_FILE\e[0m)" 1>&2; 
  echo    "#      Note that $URI_LIST_FILE can be a csv export including a column:" 1>&2; 
  echo    "#      only an intact very first http(s)://URL in a line is used, also" 1>&2; 
  echo    "#      comments or strings behind the URL are filtered out." 1>&2; 
  echo    "#   -r ........................... randomize order from URI list" 1>&2; 
  echo    "# " 1>&2; 
  echo    "# Examples:" 1>&2; 
  echo    "#   Running normally with prompt before starting (progress to STDOUT)" 1>&2; 
  echo -e "#     \e[34m${0##*/}\e[0m -d id.snsb.info       # setting the domainname will search urilist in: \e[32m${URI_LIST_FILE/$DOMAINNAME/\\e[7mid.snsb.info\\e[0;32m}\e[0m" 1>&2; 
  echo -e "#     \e[34m${0##*/}\e[0m -u snsb_20201102_occurrenceID.csv -d id.snsb.info " 1>&2; 
  echo    "#   Running in log file mode (immediately without a prompt!!)" 1>&2; 
  echo -e "#     \e[34m${0##*/}\e[0m -u snsb_20201102_occurrenceID.csv -l -d id.snsb.info & " 1>&2; 
  echo    "#     run in test mode (~200 jobs; do not add -l or -t at the end: it will not be processed correctly)" 1>&2; 
  echo -e "#     \e[34m${0##*/}\e[0m -u snsb_20201102_occurrenceID.csv -l -t -d id.snsb.info & " 1>&2; 
  echo    "# " 1>&2; 
  echo    "# To interrupt all the downloads in progress you have to:" 1>&2; 
  echo -e "#   (1) kill process ID (PID) of \e[34m${0##*/}\e[0m, find it by:" 1>&2; 
  echo -e "#       \e[1;34mps\e[0m\e[1m -fp \$( \e[1;34mpgrep\e[0m\e[1m -d, --full ${0##*/} )\e[0m " 1>&2; 
  echo -e "#   (2) kill process ID (PID) of \e[34m/usr/bin/perl parallel\e[0m, find it by:" 1>&2; 
  echo -e "#       \e[1;34mps\e[0m\e[1m -fp \$( \e[1;34mpgrep\e[0m\e[1m -d, --full parallel )\e[0m " 1>&2; 
  echo    "# ################################################################" 1>&2; 
  # exit 1; 
}

function processinfo () {
logfile_alternative
echo     "############ Download RDF from List of URIs #################"
if [[ -z ${randomize_urilist// /} ]] ; then
echo     "# It will download simply URIs by appending RDFs in parallel to something:"
else
echo  -e "# It will download \e[32m*randomized*\e[0m URIs by appending RDFs in parallel to something:"
fi
echo -e  "#   \e[32mThread-2_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.rdf\e[0m"
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


if [[ ${#} -eq 0 ]]; then
    usage; exit 0;
fi

# read command line options (those with a colon require a mandatory option argument)
while getopts "d:hj:u:lrt" o; do
    case $o in
        d)
            DOMAINNAME=${OPTARG}
            if   [[ -z ${DOMAINNAME// /} ]] ; then echo "error: $DOMAINNAME cannot be empty" >&2; usage; exit 1; fi
            logfile_alternative
            # export DOMAINNAME
            ;;
        h)
            usage; exit 0;
            ;;
        j)
            N_JOBS=${OPTARG}
            re='^[0-9]+$'
            if ! [[ $N_JOBS =~ $re ]] ; then echo "error: $N_JOBS cannot be the number of parallel jobs" >&2; usage; exit 1; fi
            export N_JOBS # export to make it accessible in function getrdf_with_urlstatus_check()
            ;;
        l)
            if [[ -n "${OPTARG:-}" ]]; then
              PROGRESS_LOGFILE=${OPTARG}
            fi
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
            usage; exit 0;
            ;;
    esac
done
shift "$((OPTIND-1))"

# TODO check zero padding of Thread-01_
# $(printf "%.6d" "$myvar")
# $(printf "%.${#N_JOBS}d" "$this_job_counter")


# process all variables first

if [[ -z ${randomize_urilist// /} ]] ; then
  if   [[ -z ${test_mode// /} ]] ; then
    TOTAL_JOBS=`cat "$URI_LIST_FILE" | sed --regexp-extended '/^[[:space:]]*https?:/!d' | wc -l`
  else
    TOTAL_JOBS=`head -n200 "$URI_LIST_FILE" | sed --regexp-extended '/^[[:space:]]*https?:/!d' | wc -l`
  fi
else
  if   [[ -z ${test_mode// /} ]] ; then
    TOTAL_JOBS=`cat "$URI_LIST_FILE" | shuf | sed --regexp-extended '/^[[:space:]]*https?:/!d' | wc -l`
  else
    TOTAL_JOBS=`head -n200 "$URI_LIST_FILE" | shuf | sed --regexp-extended '/^[[:space:]]*https?:/!d' | wc -l`
  fi
fi

get_info_and_http_return_codes() {
  # usage: get_info_and_http_return_codes 'output log from wget or curl something containing HTTP return codes'
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
    # echo "$this_wget_log" | sed --silent "1 { s@\$@ Codes: unknown. ${this_error_messages}@;p}"
    echo "$this_wget_log" | sed --silent --regexp-extended "/--[0-9]+-[0-9]+-[0-9]+ .+https?:/{ s@\$@ Codes: unknown. ${this_error_messages}@; p; q;}"
  else
    # echo "$this_wget_log" | sed --silent "1 { s@\$@ Codes: ${this_return_codes}@;p}"
    echo "$this_wget_log" | sed --silent --regexp-extended "/--[0-9]+-[0-9]+-[0-9]+ .+https?:/{ s@\$@ Codes: ${this_return_codes}@; p; q;}"
  fi
}
export -f get_info_and_http_return_codes # export needed otherwise /usr/bin/bash: get_timediff_for_njobs_new: command not found

get_timediff_for_njobs_new () {
  # Description: calculate estimated time to finish n jobs and the estimated total time
  # # # # # 
  # Usage:
  # get_timediff_for_njobs_new --test # to check for dependencies (datediff)
  # get_timediff_for_njobs_new begintime nowtime ntotaljobs njobsnowdone
  # get_timediff_for_njobs_new "2021-12-06 16:47:29" "2021-12-09 13:38:08" 696926 611613
  # # # # # # # # # # # # # # # # # # 
  # echo '('`date +"%s.%N"` ' * 1000)/1' | bc # get milliseconds
  # echo '('`date +"%s.%N"` ' * 1000000)/1' | bc # get nanoseconds
  # echo $( date --rfc-3339 'ns' ) | ( read -rsd '' x; echo ${x@Q} ) # escaped
    
  local this_command_timediff
  
  # read if test mode to check commands
  while [[ "$#" -gt 0 ]]
  do
    case $1 in
      -t|--test)
        doexit=0
        if ! command -v datediff &> /dev/null &&  ! command -v dateutils.ddiff &> /dev/null
        then
          echo -e "# \e[31mError: Neither command datediff or dateutils.ddiff could not be found. Please install package dateutils.\e[0m"
          doexit=1
        fi
        if ! command -v sed &> /dev/null 
        then
          echo -e "# \e[31mError: command sed (stream editor) could not be found. Please install package sed.\e[0m"
          doexit=1
        fi
        if ! command -v bc &> /dev/null 
        then
          echo -e "# \e[31mError: command bc (arbitrary precision calculator) could not be found. Please install package bc.\e[0m"
          doexit=1
        fi
        if [[ $doexit -gt 1 ]];then
          exit;
        else
          return 0 # (return 0 seems success?) and exit function
        fi
      ;;
      *)
      break
      ;;
    esac
  done
  
  if ! command -v datediff &> /dev/null
  then
    # echo "Command dateutils.ddiff found"
    this_command_timediff="dateutils.ddiff"
  elif ! command -v dateutils.ddiff &> /dev/null
    then
      # echo "Command datediff found"
      this_command_timediff="datediff"
  fi

  # START estimate time to do 
  # convert also "2022-06-30_14h56m10s" to "2022-06-30 14:56:10"
  this_given_start_time=$( echo $1 | sed -r 's@([[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2})[_[:space:]-]([[:digit:]]{2})h([[:digit:]]{2})m([[:digit:]]{2})s@\1 \2:\3:4@' )
  this_given_now_time=$(   echo $2 | sed -r 's@([[:digit:]]{4}-[[:digit:]]{2}-[[:digit:]]{2})[_[:space:]-]([[:digit:]]{2})h([[:digit:]]{2})m([[:digit:]]{2})s@\1 \2:\3:4@' )
  
  local this_unixnanoseconds_start_timestamp=$(date --date="$this_given_start_time" '+%s.%N')
  local this_unixnanoseconds_now=$(date --date="$this_given_now_time" '+%s.%N')
  local this_unixseconds_todo=0
  local this_n_jobs_all=$(expr $3 + 0)
  local this_i_job_counter=$(expr $4 + 0)
  # echo "scale=10; 1642073008.587244684 - 1642028400.000000000" | bc -l
  local this_timediff_unixnanoseconds=`echo "scale=10; $this_unixnanoseconds_now - $this_unixnanoseconds_start_timestamp" | bc -l`
  # $(( $this_unixnanoseconds_now - $this_unixnanoseconds_start_timestamp ))
  local this_n_jobs_todo=$(( $this_n_jobs_all - $this_i_job_counter ))
  local this_msg_estimated_sofar=""

  # echo -e "\033[2m# DEBUG Test mode: all together $this_n_jobs_all ; counter $this_i_job_counter\033[0m"
  if [[ $this_n_jobs_all -eq $this_i_job_counter ]];then # done
    this_unixseconds_todo=0
    # njobs_done_so_far=`$this_command_timediff "@$this_unixnanoseconds_start_timestamp" "@$this_unixnanoseconds_now" -f "all $this_i_job_counter done, duration %dd %0Hh:%0Mm:%0Ss"`
    this_msg_estimated_sofar="nothing left to do"
  else
    # this_unixseconds_todo=$(( $this_timediff_unixnanoseconds * $this_n_jobs_todo / $this_i_job_counter ))
    # this_unixseconds_todo=$(( $this_timediff_unixnanoseconds * $this_n_jobs_todo / $this_i_job_counter ))
    this_unixseconds_todo=`echo "scale=0; $this_timediff_unixnanoseconds * $this_n_jobs_todo / $this_i_job_counter" | bc -l`
    
    job_singular_or_plural=$([ $this_n_jobs_todo -gt 1 ]  && echo jobs  || echo job )
    if [[ $this_unixseconds_todo -ge $(( 60 * 60 * 24 * 2 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo $job_singular_or_plural to do, estimated end %0ddays %0Hh:%0Mmin:%0Ssec"`
    elif [[ $this_unixseconds_todo -ge $(( 60 * 60 * 24 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo $job_singular_or_plural to do, estimated end %0dday %0Hh:%0Mmin:%0Ssec"`
    elif [[ $this_unixseconds_todo -ge $(( 60 * 60 * 1 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo $job_singular_or_plural to do, estimated end %0Hh:%0Mmin:%0Ssec"`
    elif [[ $this_unixseconds_todo -lt $(( 60 * 60 * 1 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo $job_singular_or_plural to do, estimated end %0Mmin:%0Ssec"`
    fi
  fi
  
  this_unixseconds_done=`printf "%.0f" $(echo "scale=0; $this_unixnanoseconds_now - $this_unixnanoseconds_start_timestamp" | bc -l)`
  this_unixseconds_total=`printf "%.0f" $(echo "scale=0; $this_unixseconds_done + $this_unixseconds_todo" | bc -l)`  
  if [[ $this_unixseconds_total -ge $(( 60 * 60 * 24 * 2 )) ]];then
    this_msg_time_total=`$this_command_timediff "@0" "@$this_unixseconds_total" -f "total time: %0ddays %0Hh:%0Mmin:%0Ssec"`
  elif [[ $this_unixseconds_total -ge $(( 60 * 60 * 24 )) ]];then
    this_msg_time_total=`$this_command_timediff "@0" "@$this_unixseconds_total" -f "total time: %0dday %0Hh:%0Mmin:%0Ssec"`
  elif [[ $this_unixseconds_total -ge $(( 60 * 60 * 1 )) ]];then
    this_msg_time_total=`$this_command_timediff "@0" "@$this_unixseconds_total" -f "total time: %0Hh:%0Mmin:%0Ssec"`
  elif [[ $this_unixseconds_total -lt $(( 60 * 60 * 1 )) ]];then
    this_msg_time_total=`$this_command_timediff "@0" "@$this_unixseconds_total" -f "total time: %0Mmin:%0Ssec"`
  fi
  if ! [[ $this_unixseconds_todo -eq 0 ]];then this_msg_time_total="estimated $this_msg_time_total"; fi
  
  #echo "from $this_n_jobs_all, $njobs_done_so_far; $this_msg_estimated_sofar"
  echo "${this_msg_estimated_sofar} (${this_msg_time_total})"
  # END estimate time to do 
}
export -f get_timediff_for_njobs_new # export needed otherwise /usr/bin/bash: get_timediff_for_njobs_new: command not found
get_timediff_for_njobs_new --test


getrdf_with_urlstatus_check() {
  # Description: function for use with command `parallel` to get the URL status code (200 OK, 404 NOT FOUND aso.)
  # # # # # 
  # Usage: (it has 7 or 8 arguments)
  # Usage: getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} uri domainname $time_now $time_started [PROGRESS_LOGFILE]
  # # # # # 
  # dependency: get_info_and_http_return_codes
  # dependency: get_timediff_for_njobs
  # dependency: parallel
  # dependency: wget
  # dependency: sed
  # dependency: dateutils (diff)
  # # # # # 
  # echo "# DEBUG ${FUNCNAME[0]}, line ${LINENO}, arguments: $@"

  local this_job_number=$1   # {%}
  local this_job_counter=$2  # {#}
  local this_jobs_total=$3   # ${TOTAL_JOBS}
  local this_uri="$4"        # {} (is the uri)
  local this_domainname="$5"
  local this_datetime_now="$6"
  local this_datetime_started="$7"
  local this_progress_logfile="$8" # optional
  local this_n_digits=${#N_JOBS}
  local this_zeropadded_job_number=$(printf "%.${this_n_digits}d" "$this_job_number")
  
  # local this_zeropadded_job_number=$(printf "%.2d" "$this_job_number")
  # START estimate time to do
  # starttime nowtime ntotaljobs nowjobsdone
  local this_estimated_todo=`get_timediff_for_njobs_new "$this_datetime_started" "$(date --rfc-3339 'ns')" "$this_jobs_total" "$this_job_counter"`
  # $exec_datediff "@0" "@$this_unixsecond_todo" -f "estimated todo %dd %Hh:%Mm:%Ss"
  # END estimate time to do 

  local this_loginfo=""  
  # local this_return_codes=""
  local this_debug_mode=0  # default 0, or 1 adds info to terminal
  if [[ $this_debug_mode -gt 0 ]];then
    echo $(date) >> "$DEBUGLOGFILE"
    echo "this_n_digits: $this_n_digits" >> "$DEBUGLOGFILE"
    echo "N_JOBS: $N_JOBS" >> "$DEBUGLOGFILE"
    echo "this_zeropadded_job_number: $this_zeropadded_job_number" >> "$DEBUGLOGFILE"
  fi
  this_loginfo=$(printf '%s file job %02d (step %06d of %06d, %s)' Thread-${this_zeropadded_job_number}_${this_domainname}_${this_datetime_now}.rdf "${this_job_number}" "${this_job_counter}" "${this_jobs_total}" "${this_estimated_todo}")
  #   echo $(date --date="2021-12-06 16:47:29" '+%s')
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
    # wget_log=$( { wget --header='Accept: application/rdf+xml' --max-redirect 4 -O - "$this_uri" >> "Thread-${this_zeropadded_job_number}_${this_domainname}_${this_datetime_now}.rdf"; } 2>&1  )
  wget_log=$( { wget --header='Accept: application/rdf+xml' --no-check-certificate --max-redirect 4 -O - "$this_uri" >> "Thread-${this_zeropadded_job_number}_${this_domainname}_${this_datetime_now}.rdf"; } 2>&1  )

  echo "$wget_log" >> "Thread-${this_zeropadded_job_number}_${this_domainname}_${this_datetime_now}.log"

  download_info="${this_loginfo} "`get_info_and_http_return_codes "$wget_log"`
  
  if   [[ -z ${this_progress_logfile// /} ]] ; then
    echo "${download_info}"
  else # output to log file
    echo "${download_info}" >> "${this_progress_logfile}"
    if [[ `echo "${download_info}" | grep --ignore-case 'ERROR' ` ]]; then
      echo "${download_info}" >> "${this_progress_logfile%.*}_error.log"
    fi
  fi
  if [[ $this_debug_mode -gt 0 ]];then echo "DEBUG: ${download_info} … ${this_progress_logfile}" >> "$DEBUGLOGFILE"; fi
}
export -f getrdf_with_urlstatus_check # export needed otherwise /usr/bin/bash: getrdf_with_urlstatus_check: command not found

# DEBUG (in pure bash without datediff package)
# datetime_start=`date --rfc-3339 'seconds'`; unix_seconds_start=$(date +"%s")
# datetime_end=`date --rfc-3339 'seconds'`;   unix_seconds_end=$(date +"%s")
#   date -u -d "0 ${unix_seconds_end} sec -  ${unix_seconds_start} sec - $(date -u -d "$datetime_start - 1 day" +"%j") days" +"%j days (minus 1 day) %Hh%Mm%Ss"

if   [[ -z ${PROGRESS_LOGFILE// /} ]] ; then
  # echo "# DEBUG script line ${LINENO}: PROGRESS_LOGFILE: zero "
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
  datetime_start=`date --rfc-3339 'ns'` ; # unix_seconds_start=$(date +"%s")
  datetime_start_quoted=`date --rfc-3339 'ns' | ( read -rsd '' x; echo ${x@Q} )`; # unix_seconds_start=$(date +"%s")

  if [[ -z ${randomize_urilist// /} ]] ; then
    # echo "# DEBUG script line ${LINENO}: randomize_urilist: zero … "
    if   [[ -z ${test_mode// /} ]] ; then
      # echo "# DEBUG script line ${LINENO}: randomize_urilist: zero; test mode"
      cat "$URI_LIST_FILE" | sed --regexp-extended 's@\r@@g; /^https?:/!d; s@^(https?://[^[:space:]]+).*$@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW_YmdHM}" "${datetime_start_quoted}"
      # extract only the (https?://…)
    else
      # echo "# DEBUG script line ${LINENO}: randomize_urilist: zero; no test mode"
      echo "# Running in test mode ($TOTAL_JOBS jobs)" 
      # head -n200 "$URI_LIST_FILE" | sed --regexp-extended '/^https?:/!d;s@\r@@g' | parallel -j$N_JOBS echo {%} {#} ${TOTAL_JOBS} {}
      head -n200 "$URI_LIST_FILE" | sed --regexp-extended 's@\r@@g; /^https?:/!d; s@^(https?://[^[:space:]]+).*$@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW_YmdHM}" "${datetime_start_quoted}"
      # extract only the (https?://…)
    fi
  else
    # echo "# DEBUG script line ${LINENO}: randomize_urilist: not zero …"
    if   [[ -z ${test_mode// /} ]] ; then
      # echo "# DEBUG script line ${LINENO}: randomize_urilist: not zero; test mode"
      cat "$URI_LIST_FILE" | shuf | sed --regexp-extended 's@\r@@g; /^https?:/!d; s@^(https?://[^[:space:]]+).*$@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW_YmdHM}" "${datetime_start_quoted}"
      # extract only the (https?://…)
    else
      # echo "# DEBUG script line ${LINENO}: randomize_urilist: not zero; no test mode"
      echo "# Running in test mode ($TOTAL_JOBS jobs)" 
      # head -n200 "$URI_LIST_FILE" | sed --regexp-extended '/^https?:/!d;s@\r@@g' | parallel -j$N_JOBS echo {%} {#} ${TOTAL_JOBS} {}
      head -n200 "$URI_LIST_FILE" | shuf | sed --regexp-extended 's@\r@@g; /^https?:/!d; s@^(https?://[^[:space:]]+).*$@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW_YmdHM}" "${datetime_start_quoted}"
      # extract only the (https?://…)
    fi
  fi
  
  datetime_end=`date --rfc-3339 'ns'` ;
  # datetime_end_escaped=`date --rfc-3339 'ns'` | ( read -rsd '' x; echo ${x@Q} ); 
  # take end time
  # unix_seconds_end=$(date +"%s")
  # echo `date -u -d "0 ${unix_seconds_end} sec -  ${unix_seconds_start} sec - $(date -u -d "$datetime_start - 1 day" +"%j") days" +"Done. $TOTAL_JOBS jobs took %j days (minus 1 day) %Hh%Mm%Ss"`
  echo $( date --date="$datetime_start" '+# Started: %Y-%m-%d %H:%M:%S%:z' )
  echo $( date --date="$datetime_end"   '+# Ended:   %Y-%m-%d %H:%M:%S%:z' )
  #   echo "# Started: $datetime_start" 
  #   echo "# Ended:   $datetime_end"   
  
  $exec_datediff "$datetime_start" "$datetime_end" -f "# Done. $TOTAL_JOBS jobs took %dd  %0Hh:%0Mm:%0Ss using $N_JOBS parallel connections" 
  echo -e "# Hint: use \e[1;34mzgrep\e[0m or \e[1;34mzcat\e[0m … | \e[1;34mtail\e[0m    to search or list file content on gz text files" 
  echo    "# Substitute potential \r (carriage return) to get sed properly working …"
  sed --in-place 's@\r@@g' $(echo "Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.rdf")
  echo    "# Compress all files Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.rdf …"
  gzip --verbose $(echo "Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.rdf")
  echo    "# Compress all files Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.log …"
  gzip --verbose $(echo "Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.log")

else   # PROGRESS_LOGFILE and log into file
  # echo "# DEBUG script line ${LINENO}: PROGRESS_LOGFILE not zero"
  logfile_alternative; PROGRESS_LOGFILE=$logfile_alternative
  datetime_start=`date --rfc-3339 'ns'` ;
  datetime_start_quoted=`date --rfc-3339 'ns' | ( read -rsd '' x; echo ${x@Q} )`;
  
  unix_seconds_start=$(date +"%s")
  # take start time
  if   [[ -z ${test_mode// /} ]] ; then
    # echo "# DEBUG script line ${LINENO}: PROGRESS_LOGFILE not zero; test mode zero"
    echo    "# To interrupt all the downloads in progress you have to:" 1>&2; 
    echo -e "#   (1) kill process ID (PID) of \e[34m${0##*/}\e[0m, find it by:" 1>&2; 
    echo -e "#       \e[1;34mps\e[0m\e[1m -fp \$( \e[1;34mpgrep\e[0m\e[1m -d, --full ${0##*/} )\e[0m " 1>&2; 
    echo -e "#   (2) kill process ID (PID) of \e[34m/usr/bin/perl parallel\e[0m, find it by:" 1>&2; 
    echo -e "#       \e[1;34mps\e[0m\e[1m -fp \$( \e[1;34mpgrep\e[0m\e[1m -d, --full parallel )\e[0m " 1>&2; 
    echo -e "# ------------------------------" 1>&2; 
    echo -e "# Running $TOTAL_JOBS jobs. See running progress in log files (become later …log.gz!):" 1>&2;
    echo -e "  tail ${PROGRESS_LOGFILE}       # logging all progress or" 1>&2;
    echo -e "  tail ${PROGRESS_LOGFILE%.*}_error.log # loggin errors only: 404 500 aso."  1>&2

    processinfo             &>> "${PROGRESS_LOGFILE}"
    echo " yes"             &>> "${PROGRESS_LOGFILE}"
    if [[ -z ${randomize_urilist// /} ]] ; then
      # echo "# DEBUG script line ${LINENO}: PROGRESS_LOGFILE not zero; test mode zero; randomize_urilist zero"
      cat "$URI_LIST_FILE" | sed --regexp-extended 's@\r@@g; /^https?:/!d; s@^(https?://[^[:space:]]+).*$@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW_YmdHM}" "${datetime_start_quoted}" "${PROGRESS_LOGFILE}"
    else
      # echo "# DEBUG script line ${LINENO}: PROGRESS_LOGFILE not zero; test mode zero; randomize_urilist not zero"
      cat "$URI_LIST_FILE" | shuf | sed --regexp-extended 's@\r@@g; /^https?:/!d; s@^(https?://[^[:space:]]+).*$@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW_YmdHM}" "${datetime_start_quoted}" "${PROGRESS_LOGFILE}"
    fi
  else
    # echo "# DEBUG script line ${LINENO}: PROGRESS_LOGFILE not zero; test mode not zero"
    echo    "# To interrupt all the downloads in progress you have to:" 1>&2; 
    echo -e "#   (1) kill process ID (PID) of \e[34m${0##*/}\e[0m, find it by:" 1>&2; 
    echo -e "#       \e[1;34mps\e[0m\e[1m -fp \$( \e[1;34mpgrep\e[0m\e[1m -d, --full ${0##*/} )\e[0m " 1>&2; 
    echo -e "#   (2) kill process ID (PID) of \e[34m/usr/bin/perl parallel\e[0m, find it by:" 1>&2; 
    echo -e "#       \e[1;34mps\e[0m\e[1m -fp \$( \e[1;34mpgrep\e[0m\e[1m -d, --full parallel )\e[0m " 1>&2; 
    echo -e "# ------------------------------" 1>&2; 
    echo -e "# Running in TEST MODE ($TOTAL_JOBS jobs). See running progress in log files (become later …log.gz!):" 1>&2;
    echo -e "  tail ${PROGRESS_LOGFILE}       # logging all progress or" 1>&2;
    echo -e "  tail ${PROGRESS_LOGFILE%.*}_error.log # loggin errors only: 404 500 aso." 1>&2;
    processinfo             &>> "${PROGRESS_LOGFILE}"
    echo " yes"             &>> "${PROGRESS_LOGFILE}"
    if [[ -z ${randomize_urilist// /} ]] ; then
      # echo "# DEBUG script line ${LINENO}: PROGRESS_LOGFILE not zero; test mode not zero; randomize_urilist zero"
      head -n200 "$URI_LIST_FILE" | sed --regexp-extended 's@\r@@g; /^https?:/!d; s@^(https?://[^[:space:]]+).*$@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW_YmdHM}" "${datetime_start_quoted}" "${PROGRESS_LOGFILE}"
    else
      # echo "# DEBUG script line ${LINENO}: PROGRESS_LOGFILE not zero; test mode not zero; randomize_urilist not zero"
      head -n200 "$URI_LIST_FILE" | shuf | sed --regexp-extended 's@\r@@g; /^https?:/!d; s@^(https?://[^[:space:]]+).*$@\1@' | parallel -j$N_JOBS getrdf_with_urlstatus_check {%} {#} ${TOTAL_JOBS} {} "${DOMAINNAME}" "${DATETIME_NOW_YmdHM}" "${datetime_start_quoted}" "${PROGRESS_LOGFILE}"
    fi
  fi
  # date --date="2022-01-13 13:22:54.219314212+01:00" '+%Y%m%d-%H%M%S'
  datetime_end=`date --rfc-3339 'seconds'` ; 
  # datetime_end_escaped=`date --rfc-3339 'seconds'` | ( read -rsd '' x; echo ${x@Q} ); 
  # take end time
  echo $( date --date="$datetime_start" '+# Started: %Y-%m-%d %H:%M:%S%:z' ) >> "${PROGRESS_LOGFILE}"
  echo $( date --date="$datetime_end"   '+# Ended:   %Y-%m-%d %H:%M:%S%:z' ) >> "${PROGRESS_LOGFILE}"
  # echo "# Started: $datetime_start" >> "${PROGRESS_LOGFILE}"
  # echo "# Ended:   $datetime_end"   >> "${PROGRESS_LOGFILE}"
  $exec_datediff "$datetime_start" "$datetime_end" -f "# Done. $TOTAL_JOBS jobs took %dd  %0Hh:%0Mm:%0Ss using $N_JOBS parallel connections" >> "${PROGRESS_LOGFILE}"
  echo -e "# Hint: use zgrep or zcat … | tail   to search or list file content on gz text files"  >> "${PROGRESS_LOGFILE}"
  echo    "# Substitute potential \r (carriage return) to get sed properly working …" >> "${PROGRESS_LOGFILE}"
  sed --in-place 's@\r@@g' $(echo "Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.rdf") &>> "${PROGRESS_LOGFILE}"
  echo    "# Compress all files Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.rdf …" >> "${PROGRESS_LOGFILE}"
  gzip --verbose $(echo "Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.rdf") &>> "${PROGRESS_LOGFILE}"
  echo    "# Compress all files Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.log …" >> "${PROGRESS_LOGFILE}"
  gzip --verbose $(echo "Thread-*_${DOMAINNAME}_${DATETIME_NOW_YmdHM}.log") &>> "${PROGRESS_LOGFILE}"
  # unix_seconds_end=$(date +"%s")
  # echo `date -u -d "0 ${unix_seconds_end} sec -  ${unix_seconds_start} sec - $(date -u -d "$datetime_start - 1 day" +"%j") days" +"Done. $TOTAL_JOBS jobs took %j days (minus 1 day) %Hh%Mm%Ss"` >> "${PROGRESS_LOGFILE}"
fi
