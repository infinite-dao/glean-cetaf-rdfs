#!/usr/bin/env bash
# script based on Maciej Radzikowski’s template from https://betterdev.blog/minimal-safe-bash-script-template/
# Usage: script [-h] [-v] [-f] -p param_value arg1 [arg2...]

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

param_searchpattern=Thread-XX_*_$(date '+%Y%m' -d 'now')[0-9][0-9]-[0-9][0-9][0-9][0-9].log.gz
param_urilist=urilist_*$(date '+%Y%m' -d 'now')[0-9][0-9]*.tsv


usage() {
  cat << EOF # remove the space between << and EOF, this is due to web plugin issue
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-s searchpattern] [-u urilist]

Report a summary of a harvest process, based on logged times, and count errors

Available options:
-h, --help           Print this help and exit program.

-s, --searchpattern  A special search pattern of log files, default:
                     ${param_searchpattern}
-u, --urilist        The urilist the harvest is based on, default:
                     ${param_urilist}
    --debug          Print script debug infos (commands executed)
    --no-color       Print without colors
EOF
  exit
}


cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

msg_inline() {
  echo -n >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  # verboseflag=0
  # searchpattern=Thread-XX_*_$(date '+%Y%m' -d 'now')[0-9][0-9]-[0-9][0-9][0-9][0-9].log.gz
  param_searchpattern=Thread-XX_*_$(date '+%Y%m' -d 'now')[0-9][0-9]-[0-9][0-9][0-9][0-9].log.gz
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    --debug) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -s | --searchpattern) param_searchpattern="${2-}" ;
      shift;; #  param TODO is not working
    -u | --urilist) param_urilist="${2-}"; shift;; #  param
    
    #-p | --param) # example named parameter
    #  param="${2-}"
    #  shift
    #  ;;
    -?*) die "Unknown option: $1 (stop)" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  [[ -z "${param_searchpattern-}" ]] && die "Missing required parameter: searchpattern"
    # param_searchpattern=Thread-XX_*_$(date '+%Y%m' -d 'now')[0-9][0-9]-[0-9][0-9][0-9][0-9].log.gz

  # [[ -z "${param-}" ]] && die "Missing required parameter: param"
  # [[ ${#args[@]} -eq 0 ]] && searchpattern=Thread-XX_*_$(date '+%Y%m' -d 'now')[0-9][0-9]-[0-9][0-9][0-9][0-9].log.gz

  return 0
}

setup_colors
parse_params "$@"

# msg "${ORANGE}DEBUG: Read parameters:${NOFORMAT}"
# msg "${ORANGE}DEBUG: - arguments: ${args[*]-}${NOFORMAT}"
# msg "${ORANGE}DEBUG: - param_urilist:     ${param_urilist}${NOFORMAT}"
# msg "${ORANGE}DEBUG: - param_searchpattern:     ${param_searchpattern}${NOFORMAT}"

# script logic here

# TODO urilist
this_exit_code=0
this_log_is_gz_flag=0
msg "# ${GREEN}write this_temporary_list.txt${NOFORMAT} …"
# msg "# ${GREEN}search for pattern ${param_searchpattern}${NOFORMAT} …"
echo "" > this_temporary_list.txt;
echo "| URI List (Log File)   |   Date Time     |  Notes and Time |" >> this_temporary_list.txt;
echo "|-----------------------|-----------------|-------------------------------------------------------------------|" >> this_temporary_list.txt;

for this_logfile in ${param_searchpattern};do 
  msg "# check $this_logfile …"
  this_log_is_gz_flag=$(echo "$this_logfile" | grep --count '.gz$') || this_exit_code=$?
  
  # add urilist and log file
  case $this_log_is_gz_flag in
  0) this_last_uripart=$(cat "$this_logfile" | tac | grep --max-count=1 --only-matching 'http[^[:space:]]*' | sed -r 's@https?://@@' ) || this_exit_code=$? ;;
  1) this_last_uripart=$(zcat "$this_logfile" | tac | grep --max-count=1 --only-matching 'http[^[:space:]]*' | sed -r 's@https?://@@' ) || this_exit_code=$? ;;
  esac
  
  echo -n $'\t' >> this_temporary_list.txt
  msg "#   last found URI-part $this_last_uripart …"
  case $this_exit_code in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
    msg "#   ${ORANGE}exit code ${this_exit_code} $(kill -l $this_exit_code)${NOFORMAT} (?cat, ?tac, ?grep, ?sed…)" ;;
  esac
  # add urlilist-file name of found this_last_uripart
  grep --files-with-matches --max-count=1 "$this_last_uripart" ${param_urilist} | tr '\n' ' ' >> this_temporary_list.txt  || this_exit_code=$?
  case $this_exit_code in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
    msg "#   ${ORANGE}exit code ${this_exit_code} $(kill -l $this_exit_code)${NOFORMAT} (?grep)" ;;
  esac
  msg "#   log file $this_logfile …"
  echo -n " ($this_logfile)" >> this_temporary_list.txt;

  # add timestamp
  echo -n $'\t' >> this_temporary_list.txt
  echo -n "$this_logfile" | sed -r 's@Thread.+([[:digit:]]{8}-[[:digit:]]{4}).+@\1@' >> this_temporary_list.txt 

  # add Done. 170148 jobs took 0d 6h:29m:25s …
  # dateutils.ddiff "$datetime_start" "$datetime_end" -f "# Done. $TOTAL_JOBS jobs took %dd %0Hh:%0Mm:%0Ss using $N_JOBS parallel connections"
  echo -n $'\t' >> this_temporary_list.txt
  case $this_log_is_gz_flag in
  0) 
  this_time_started=$( grep --ignore-case  "Started:" "$this_logfile" | sed -r 's@.+Started: +@@') || this_exit_code=$?;
  this_time_ended=$( grep --ignore-case "Ended:" "$this_logfile" | sed -r 's@.+Ended: +@@') || this_exit_code=$?;
  this_done_log_message=$( grep --ignore-case "Done" "$this_logfile" | sed -r 's@0d %Hh:%Mm:%Ss@%dd %0Hh:%0Mm:%0Ss@; s@# Done@\t Done@;') || this_exit_code=$?; 
  ;;
  1) 
  this_time_started=$( zgrep --ignore-case  "Started:" "$this_logfile" | sed -r 's@.+Started: +@@') || this_exit_code=$?;
  this_time_ended=$( zgrep --ignore-case "Ended:" "$this_logfile" | sed -r 's@.+Ended: +@@') || this_exit_code=$?;
  this_done_log_message=$( zgrep --ignore-case "Done" "$this_logfile" | sed -r 's@0d %Hh:%Mm:%Ss@%dd %0Hh:%0Mm:%0Ss@; s@# Done@\t Done@;') || this_exit_code=$?; 
  ;;
  esac
  # fix date time format strings
  if ! ([[ -z "${this_time_started-}" ]] || [[ -z "${this_time_ended-}" ]]);then
    echo -n $(dateutils.ddiff "$this_time_started" "$this_time_ended" -f "$this_done_log_message") >> this_temporary_list.txt
  else
    msg "#   ${ORANGE}Warning:${NOFORMAT} no start or end time found in log file … (?interruption)"
    # get times from file name date and last modified timestamp
    this_time_started=$(echo "$this_logfile" | sed -r "s@.*([[:digit:]]{4})([[:digit:]]{2})([[:digit:]]{2})[-_]([[:digit:]]{2})([[:digit:]]{2}).*log.*@\1-\2-\3 \4:\5:00@") || this_exit_code=$?
    this_time_ended=$( stat --printf="%y" "$this_logfile" | sed -r 's@[.][[:digit:]]+ [+-][[:digit:]]{4}$@@' )  || this_exit_code=$?;
    case $this_log_is_gz_flag in
    0) 
    this_jobs_done=$(cat "$this_logfile" | tac | grep --max-count=1 'step.*http' | sed -r 's@.+step[[:space:]]([[:digit:]]+)[[:space:]]+of[[:space:]]+[[:digit:]]+.+@\1@') || this_exit_code=$?
    this_n_parallel=$(cat "$this_logfile" | tail -n 100 | sed --regexp-extended 's@(Thread-[[:digit:]]+)[-_].*\.rdf.*@\1@g' | sort --unique | wc -l) || this_exit_code=$?
    ;;
    1) 
    this_jobs_done=$(zcat "$this_logfile" | tac | grep --max-count=1 'step.*http' | sed -r 's@.+step[[:space:]]([[:digit:]]+)[[:space:]]+of[[:space:]]+[[:digit:]]+.+@\1@') || this_exit_code=$?
    this_n_parallel=$(zcat "$this_logfile" | tail -n 100 | sed --regexp-extended 's@(Thread-[[:digit:]]+)[-_].*\.rdf.*@\1@g' | sort --unique | wc -l) || this_exit_code=$?
    ;;
    esac
    
    this_done_log_message="Done. $this_jobs_done jobs took %dd  %0Hh:%0Mm:%0Ss using $this_n_parallel parallel connections"
    echo -n $(dateutils.ddiff "$this_time_started" "$this_time_ended" -f "$this_done_log_message") >> this_temporary_list.txt
    echo -n " (no start or end time found, we tried to get it from the file date itself)" >> this_temporary_list.txt
  fi

  if [[ -e "${this_logfile/.log.gz/_error.log}" ]]; then
    echo -n ", having URI-Errors: $(cat "${this_logfile/.log.gz/_error.log}" | wc -l)" >> this_temporary_list.txt; 
  fi
  echo -n $'\t' >> this_temporary_list.txt
  echo -ne "\n" >> this_temporary_list.txt;
done
# cat this_temporary_list.txt | tr '\t' '|' | column -t -s '|' | sed -r '/jobs/{ :label.space; s@(jobs.*)\s{2}@\1 @; tlabel.space; } ; '
# cat this_temporary_list.txt | column -t -s $'\t' | sed -r '/jobs/{ :label.space; s@(jobs.*)\s{2}@\1 @; tlabel.space; } ; '
cat this_temporary_list.txt  | sed -r 's@^[\t]@| @g; s@[\t]$@ |@g; s@[\t]@ | @g;'
