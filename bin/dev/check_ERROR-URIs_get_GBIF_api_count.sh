#!/usr/bin/env bash
# script based on Maciej Radzikowski’s template from https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
today_date=$(date '+%Y%m%d')
this_work_directory=${PWD}
this_temporary_work_directory=${PWD}/check_uri_errorcodes
this_default_error_log_file=$( cd ${PWD} && ls Thread-*error.log -lt 2>/dev/null | head -n 1 | grep --only-matching 'Thread-X*[^ ]*_error.log' ) && this_exit_code=$?
[[ -z "${this_default_error_log_file-}" ]] && this_default_error_log_file="no default found, you have to provide one"

check_dependencies() {
  local exit_flag=0
  
  if ! [[ -x "$(command -v grep)" ]]; then
    printf "${ORANGE}Command${NOFORMAT} grep ${ORANGE}not found: Please install it.${NOFORMAT}\n"; exit_flag=1;
  fi

  if ! [[ -x "$(command -v jq)" ]]; then
    printf "${ORANGE}Command${NOFORMAT} jq ${ORANGE}not found: Please install it.${NOFORMAT}\n"; exit_flag=1;
  fi
  
  if ! [[ -x "$(command -v sed)" ]]; then
    printf "${ORANGE}Command${NOFORMAT} sed ${ORANGE}not found: Please install it.${NOFORMAT}\n"; exit_flag=1;
  fi

  case $exit_flag in [1-9]) printf "${ORANGE}(stop)${NOFORMAT}\n"; exit 1;; esac
}

usage() {
  cat << EOF # remove the space between << and EOF, this is due to web plugin issue
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [--error_log_file logfile]

Analyse an error log file from harvesting process, extract those URIs and
check them with the GBIF API responses (JSON) to get the information if the
occurrence ID was stored at GBIF or not. We check the count variable of the GBIF occurrenceId responses.

Use this script from the directory level where harvesting took place.
It will make a sub directory ${this_temporary_work_directory} if it does not exist.

Available options:
-h, --help           Print this help and exit program.

-e, --error_log_file The error log file to analyse from (expected pattern «ls -ltr Thread-X*[^\ ]*_[0-9]*-[0-9]*_error.log»)
                     (default: $this_default_error_log_file)
-k, --keepfiles      Keep temporary JSON files (default is to remove them)

-v, --verbose        Print process messages
    --debug          Print script debug infos (print commands executed)
    --no-color       Print without colors
EOF

  check_dependencies
  exit
}


cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here

  if [[ -d "${this_temporary_work_directory}" ]] &&  [[ ${cleanup_execute_flag} -gt 0 ]] ;then
    cd "${this_temporary_work_directory}"
    if [[ $( ls "${today_date}_"*.json 2>/dev/null | wc -l ) -gt 0 ]];then
      if [[ $keepfiles_flag -eq 0 ]]; then
        case $verbose_flag in 1) msg "${GREEN}Clean up — Remove single JSON files …${NOFORMAT}" ;; esac
        rm "${today_date}_"*.json
      else
        case $verbose_flag in
        1) msg "${GREEN}Clean up — Keep all JSON files, see «ls ${today_date}_*.json» …${NOFORMAT}" ;;
        esac
      fi
    fi
    if [[ -e "${this_temporary_urilist_json_count_file}" ]];then
      msg "${GREEN}Clean up — Info: remaining files in ${NOFORMAT}./${this_temporary_work_directory##*/}${GREEN} (first 5 entries): …${NOFORMAT}"
      ls -lt 2>/dev/null | head -n 6 && this_exit_code=$?
    fi

    cd "${this_work_directory}"
  fi
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

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  keepfiles_flag=0
  cleanup_execute_flag=1
  verbose_flag=0
  this_error_log_file=$( ls Thread-*error.log -lt 2>/dev/null | head -n 1 | grep --only-matching 'Thread-X*[^ ]*_error.log' ) && this_exit_code=$?
  this_error_log_timestamp=""
  this_temporary_urilist_file=urilist_uri_errors_from_${today_date}_error.log
  this_temporary_urilist_json_count_file=urilist_uri_errors_from_${today_date}_gbif_count_json.log
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    --debug) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -e | --error_log_file) # parameter
      this_error_log_file="${2-}"
      shift
      ;;
    -h | --help) cleanup_execute_flag=0; usage ;;    
    -k | --keepfiles) keepfiles_flag=1 ;; #  flag
    -v | --verbose) verbose_flag=1 ;;
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
  [[ -z "${this_error_log_file-}" ]] &&  cleanup_execute_flag=0 && die "${ORANGE}Missing required parameter: error_log_file ~ no error log file: ${this_error_log_file} ${NOFORMAT}(${RED}stop${NOFORMAT})"
  [[ ! -e "${this_error_log_file}" ]] && cleanup_execute_flag=0 && die "${ORANGE}Error log file: «${this_error_log_file}» not found ${NOFORMAT}(${RED}stop${NOFORMAT})"
  this_error_log_timestamp=$(echo "$this_error_log_file" | grep --extended-regexp --only-matching  '[[:digit:]]{8}-[[:digit:]]{4}' ) && this_exit_code=$?
  
  case $this_exit_code in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
    msg "${ORANGE}Something is wrong from getting the right log time stamp ($this_error_log_timestamp)? Exit code: ${this_exit_code} $(kill -l $this_exit_code)${NOFORMAT} (?grep …)" ;;
  esac
  [[ -z "${this_error_log_timestamp-}" ]] && cleanup_execute_flag=0 && die "${ORANGE}Could not read time stamp of log file: $this_error_log_timestamp ${NOFORMAT}(${RED}stop${NOFORMAT})"

  this_temporary_urilist_file=urilist_uri_errors_from_${this_error_log_timestamp}_error.log
  this_temporary_urilist_json_count_file=urilist_uri_errors_from_${this_error_log_timestamp}_gbif_count_json.log
  
  # [[ ${#args[@]} -eq 0 ]] && msg "${RED}Missing both files not yet specified to compare from: the done-list and compare-list (stopped).${NOFORMAT}" && usage
  # [[ ${#args[@]} -lt 2 ]] && msg "${RED}Got done list, but the compare list is missing and was not specified (stopped).${NOFORMAT}" && usage

  check_dependencies
  
  n_uris=$( cat "${this_work_directory}/${this_error_log_file}" | grep --only-matching --extended-regexp 'https?://[^ ]*' | wc -l )

  return 0
}

setup_colors
parse_params "$@"

# msg "${ORANGE}DEBUG: Read parameters:${NOFORMAT}"
# msg "${ORANGE}DEBUG: - listflag:  ${listflag}${NOFORMAT}"
# msg "${ORANGE}DEBUG: - arguments: ${args[*]-}${NOFORMAT}"
# msg "${ORANGE}DEBUG: - param:     ${param}${NOFORMAT}"

# script logic here

# ls Thread-*error.log -lt | less
# -rw-r--r-- 1 aplank aplank      13773 Nov 10 15:13 Thread-XX_herbarium.bgbm.org_20221110-1227_error.log
# -rw-r--r-- 1 aplank importdata 180610 Oct 13 17:01 Thread-XX_herbarium.bgbm.org_20221013-1628_error.log  - checked → urilist_error_404_20221013-1628_gbif_count_json.log
# -rw-r--r-- 1 aplank importdata   7018 Aug  1 13:50 Thread-XX_herbarium.bgbm.org_20220801-1152_error.log

if [[ $n_uris -eq 0 ]];then 
  cleanup_execute_flag=0; die "${ORANGE}$n_uris URIs found using grep pattern «https?://[^ ]*» in ${this_error_log_file} ${NOFORMAT}(${RED}stop${NOFORMAT})";
else 
  msg "${GREEN}$n_uris URIs found in ${NOFORMAT}${this_error_log_file}${GREEN} …${NOFORMAT}"
  read -n 1 -p "  Go on? (continue: yes or enter; n, no → stop)? " answer
  [[ -z "$answer" ]] && answer="Yes" # set 'Yes' on hitting enter (without input)
  
  case $answer in
  [Yy][Ee][Ss]|[Yy]|[Jj][Aa]) printf "  (continue)\n" ;;
  *)
  cleanup_execute_flag=0;  die "  ${NOFORMAT}(${RED}stop${NOFORMAT})";;
  esac
fi
if [[ ! -d ${this_temporary_work_directory} ]];then
  msg "${GREEN}Make temporary ${this_temporary_work_directory} …${NOFORMAT}"
  read -n 1 -p "  Go on? (continue: yes or enter; n, no → stop)? " answer
  [[ -z "$answer" ]] && answer="Yes" # set 'Yes' on hitting enter (without input)
  
  case $answer in
  [Yy][Ee][Ss]|[Yy]|[Jj][Aa])  printf "  (continue)\n"; mkdir --parents "${this_temporary_work_directory}" ;;
  *)
  cleanup_execute_flag=0; die " ${NOFORMAT}(${RED}stop${NOFORMAT})";;
  esac
fi 

case $verbose_flag in 1) msg "${GREEN}Get URI list from ${NOFORMAT}$this_error_log_file" ;; esac

cat "${this_work_directory}/${this_error_log_file}" | grep --only-matching --extended-regexp 'https?://[^ ]*' > ${this_temporary_work_directory}/${this_temporary_urilist_file}



msg "${GREEN}Process $n_uris URIs from ${NOFORMAT}./${this_temporary_work_directory##*/}/${this_temporary_urilist_file}${GREEN} and get GBIF’s api responses (saved to JSON files) …${NOFORMAT}"
msg "${GREEN}Process $n_uris count variables out of GBIF’s api JSON (see ${NOFORMAT}$this_error_log_file${GREEN})${NOFORMAT}"

cd "${this_temporary_work_directory}"
i_uri=1;
for this_uri in $( cat ${this_temporary_urilist_file} );do 
  this_domain=$( echo "$this_uri" | sed --regexp-extended 's@https?://([^/]+)/.+@\1@' )
  case $this_domain in
    herbarium.bgbm.org|data.rbge.org.uk|specimens.kew.org) this_id_file_part=${this_uri##*/} ;; 
    coldb.mnhn.fr) 
      this_id_file_part=$( echo "$this_uri" | sed --regexp-extended 's@https?://coldb.mnhn.fr/catalognumber/mnhn/[a-z]+/([^ ]+)$@\1@; s@/@slash@g; ' ) ;; 
    data.biodiversitydata.nl) 
      this_id_file_part=$( echo "$this_uri" | sed --regexp-extended 's@https?://data.biodiversitydata.nl/naturalis/specimen/([^ ]+)$@\1@; s@/@slash@g; ' ) ;; 
    id.smns-bw.org) 
      this_id_file_part=$( echo "$this_uri" | sed --regexp-extended 's@https?://id.smns-bw.org/smns/collection/([0-9]+/[^ ]+)$@\1@; s@/@slash@g; ' ) ;; 
    id.snsb.info)   
      this_id_file_part=$( echo "$this_uri" | sed --regexp-extended 's@https?://id.snsb.info/snsb/collection/([0-9]+/[^ ]+)$@\1@; s@/@slash@g; ' ) ;; 
    *) this_id_file_part=${this_uri##*/} ;;
  esac
  # check http and https
  
  case $i_uri in 1) printf "" > "${this_temporary_urilist_json_count_file}" ;; esac
  for this_protocol in http https; do
    # msg "Process $this_protocol …"
    this_uri_protocol=$( echo $this_uri  | sed --regexp-extended "s@https?(://)@${this_protocol}\1@" ) && this_exit_code=$?
    this_id_jsonfile_protocol=$(  printf "%s_${this_protocol}_%s.json"  $today_date $this_id_file_part )
    this_gbif_occurrence_api_protocol="https://api.gbif.org/v1/occurrence/search?occurrenceId=$this_uri_protocol"
    this_count_protocol=0
    case $verbose_flag in
    1)  printf "${GREEN}%d of %d (save to %s) …${NOFORMAT}\n" $i_uri  $n_uris "$this_id_jsonfile_protocol" ;;
    *)  if [[ $(( $i_uri % 100 )) -eq 0 ]] && [[ "${this_protocol-}" == "http" ]] ;then printf ". %04d\n" $i_uri ; else printf "."; fi ;;
    esac
    case $verbose_flag in
    1)  wget --no-check-certificate --quiet --show-progress --output-document="$this_id_jsonfile_protocol"  "${this_gbif_occurrence_api_protocol}" ;;
    *)  wget --no-check-certificate --quiet                 --output-document="$this_id_jsonfile_protocol"  "${this_gbif_occurrence_api_protocol}" ;;
    esac
    this_count_protocol=$( cat "$this_id_jsonfile_protocol" | jq  " . | .count " ) && this_exit_code=$?
    case $this_exit_code in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
      msg "${ORANGE}Something is wrong with JSON processing ($this_id_jsonfile_protocol)? Exit code: ${this_exit_code} $(kill -l $this_exit_code)${NOFORMAT}" ;;
    esac
    
    case $this_count_protocol in # get occurrenceID from http or https to log file
      [1-9])  this_gbif_occurrenceIDs_protocol=$( cat "$this_id_jsonfile_protocol" | jq --raw-output ' . | .results | (map(.occurrenceID) | join("; ") )' ) 
      printf "%d of %d (saved %s, %s) … count: %s … occurrenceID: %s\n" \
        $i_uri  $n_uris "$this_id_jsonfile_protocol"  "$this_gbif_occurrence_api_protocol"  "$this_count_protocol" "$this_gbif_occurrenceIDs_protocol" \
        >> "${this_temporary_urilist_json_count_file}"
      ;; 
      *)  printf "%d of %d (saved %s, %s) … count: %s\n" \
        $i_uri  $n_uris "$this_id_jsonfile_protocol"  "$this_gbif_occurrence_api_protocol"  "$this_count_protocol" \
        >> "${this_temporary_urilist_json_count_file}"
      ;; 
    esac
    if [[ $keepfiles_flag -eq 0 ]];then
    case $this_count_protocol  in 0) rm  "$this_id_jsonfile_protocol" ;; esac
    fi
  done # this_protocol
  
  if [[ $i_uri -eq $n_uris ]];then printf " %04d\n" $i_uri; fi
  i_uri=$(( i_uri + 1 ))
done

msg "${GREEN}# Done. Show the first 20 entries of GBIF’s count responses in ${NOFORMAT}${this_temporary_work_directory}${GREEN} use:${NOFORMAT}"
msg "cat ./${this_temporary_work_directory##*/}/${this_temporary_urilist_json_count_file} | sort --key=9.1brn | head --lines=20 | column -t"
msg "${GREEN}# Checking in debug sort mode use:${NOFORMAT}"
msg "cat ./${this_temporary_work_directory##*/}/${this_temporary_urilist_json_count_file} | sort --debug --key=9.1brn | head --lines=20"

# script logic end (execute cleanup from track command)
