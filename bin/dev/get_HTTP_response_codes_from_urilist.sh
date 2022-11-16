#!/usr/bin/env bash
# script based on Maciej Radzikowski’s template from https://betterdev.blog/minimal-safe-bash-script-template/

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat << EOF # remove the space between << and EOF, this is due to web plugin issue
Usage: $(basename "${BASH_SOURCE[0]}") [-h] urilist.txt

Get http_code response and url_effective of URIs provided in a textfile.

The URIs can have any protocol type but could also have “<“ or “>” wrapped around, like <http://…>

Available options:
-h, --help           Print this help and exit program.
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

# msg_inline() {
#   echo -n >&2 -e "${1-}"
# }


die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  # default values of variables set from params
  # param=''
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    --debug) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -?*) die "Unknown option: $1 (stop)" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required params and arguments
  # [[ -z "${param-}" ]] && die "Missing required parameter: param"
  [[ ${#args[@]} -eq 0 ]] && msg "${RED}Missing uri list file. Please provide a text file (stop here).${NOFORMAT}" && usage 

  return 0
}

setup_colors
parse_params "$@"

# msg "${ORANGE}DEBUG: Read parameters:${NOFORMAT}"
# msg "${ORANGE}DEBUG: - listflag:  ${listflag}${NOFORMAT}"
# msg "${ORANGE}DEBUG: - arguments: ${args[*]-}${NOFORMAT}"
# msg "${ORANGE}DEBUG: - param:     ${param}${NOFORMAT}"

# script logic here
urilist="${args[0]}"

if ! [[ -e "$urilist" ]];then
  die "${RED}File not existing: $urilist or not found. Please provide the right one (stop)${NOFORMAT}"
fi

#### Notice:
# grep can find digits but the pattern may not match: this evaluates as exit code 1 
# (and using set -e it stops the entire script, so testing it within if (…) OR (command-with-exit-code 1 || exit_code=$? ) is safe; redirect 2>/dev/null does not help to continue the script)
this_exit_code=0;
n_uri=$( grep --count "[[:alpha:]]\+://" "$urilist" ) \
  || this_exit_code=$?

if [[ $this_exit_code -gt 0 ]];then
  msg "${ORANGE}WARNING:${NOFORMAT} Something is wrong, ${BLUE}grep${NOFORMAT} returned exit code ${ORANGE}${this_exit_code}${NOFORMAT}. Are these ${n_uri} correct URIs? First lines are:"
  head -n 5 "${urilist}"
  # die "Stop here."
fi

i_uri=1 l_digits=${#n_uri}
for uri in $(sed --silent --regexp-extended '/[[:alpha:]]+:\/\// { s@[[:space:]]*<?([[:alpha:]]+://[^[:space:],]+)>?\b.*$@\1@; p }' "$urilist");do
  first_http_code=$(curl --silent --connect-timeout 8 --output /dev/null $uri -I -w "%{http_code}" | sed ':a;N;$!ba;s/\n/ /g' ) || echo 0

  printf "URI %0${l_digits}d of %0${l_digits}d:\n" $i_uri $n_uri;
  echo "           url: " $uri "… http_code $first_http_code;"
  # then follow to real location
  echo " url_effective: " $(curl --location --silent --connect-timeout 8 --output /dev/null $uri -I -w "%{url_effective} … http_code %{http_code};" | sed ':a;N;$!ba;s/\n/ /g' )

  i_uri=$(( i_uri + 1 ))
done
msg "Done"
