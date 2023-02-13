#!/usr/bin/env bash
# script based on Maciej Radzikowski’s template from https://betterdev.blog/minimal-safe-bash-script-template/
# Usage: scriptname [-h] [-v] [-f] -p param_value arg1 [arg2...]

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<USAGEMSG # remove the space between << and EOF, this is due to web plugin issue
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] -i institute -t timestamp(s)

After harvesting, do the
- the fixing of stacked RDF sources and proceed with modified files
- the technical validation of RDF
- the normalization of RDF

Available options:
-h, --help           Print this help and exit program.

-i, --institute      Which institute to run through the RDF data, e.g. 
                     - BGBM, Finland, Meise, Naturalis, Paris, RBGE, RBGK, SMNS, SNSB
-t, --timestamps     The timestamp to run for

-v, --verbose        Print process messages
-w, --workdir        Working directory ($PWD)
    --debug          Print script debug infos (commands executed)
    --no-color       Print without colors
USAGEMSG
  exit
}


cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here  
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m' GRAY='\033[0;37m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW='' GRAY=''
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
  verboseflag=0
  keepfiles_flag=0
  institute=''
  timestamps=''
  work_directory=$PWD
  # param=''
  
  # To be able to pass two flags as -ab, instead of -a -b, some additional code would be needed.
  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    --debug) set -x ;;
    -v | --verbose) verboseflag=1 ;;
    --no-color) NO_COLOR=1 ;;
#     -k | --keepfiles) keepfiles_flag=1 ;; #  flag
    
    -i | --institute)
     institute="${2-}"
      case "${institute}" in # echo 'Naturalis' | sed 's@[a-zA-Z]@[\U&\L&]@g'
      [Bb][Gg][Bb][Mm]) institute=BGBM;;
      [Ff][Ii][Nn][Ll][Aa][Nn][Dd]) institute=Finland;;
      [Mm][Ee][Ii][Ss][Ee]) institute=Meise;;
      [Nn][Aa][Tt][Uu][Rr][Aa][Ll][Ii][Ss]) institute=Naturalis;;
      [Pp][Aa][Rr][Ii][Ss]) institute=Paris;;
      [Rr][Bb][Gg][Ee]) institute=RBGE;;
      [Rr][Bb][Gg][Kk]) institute=RBGK;;
      [Ss][Mm][Nn][Ss]) institute=SMNS ;;
      [Ss][Nn][Ss][Bb]) institute=SNSB;;
      *) die "${ORANGE}Not yet implemented for institute: $institute (stop)"
      esac
     shift
     ;;
    -t | --timestamps)
     timestamps="${2-}"
      case "${timestamps}" in # 20221102-1706
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]) timestamps="$timestamps";;
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]*[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]) timestamps="$timestamps";;
      *) die "${ORANGE}Not the expected time stamp(s), e.g. 20221102-1706, but it was given: $timestamps(stop)"
      esac
     shift
     ;;
    -w | --workdir) work_directory="${2-}"; shift ;;
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
  # [[ -z "${param-}" ]] && die "Missing required parameter: param"
#   [[ ${#args[@]} -lt 2 ]] && msg "${RED}Got done list, but the compare list is missing and was not specified (stopped).${NOFORMAT}" && usage
  [[ -z "${institute-}" ]] && [[ -z "${timestamps-}" ]] && die "${ORANGE}Missing institute, e.g. BGBM, Naturalis, Meise, RBGE aso. AND time stamp, e.g. 20221102-1706${NOFORMAT} (stop)"
  [[ -z "${institute-}" ]] &&  die "${ORANGE}Missing required parameter institute—one of: BGBM, Finland, Meise, Naturalis, Paris, RBGE, RBGK, SMNS, SNSB${NOFORMAT} (stop)"
  [[ -z "${timestamps-}" ]] && die "${ORANGE}Missing required parameter timestamps, e.g. 20221102-1706${NOFORMAT} (stop)"
  ! [[ -d ${work_directory-} ]] && die "${ORANGE}Working directory can not be entered, was not found: ${work_directory}${NOFORMAT} (stop)"

  return 0
}

setup_colors
parse_params "$@"

# msg "${ORANGE}DEBUG: Read parameters:${NOFORMAT}"
# msg "${ORANGE}DEBUG: - listflag:  ${listflag}${NOFORMAT}"
# msg "${ORANGE}DEBUG: - arguments: ${args[*]-}${NOFORMAT}"
# msg "${ORANGE}DEBUG: - param:     ${param}${NOFORMAT}"

# script logic here

this_exit_code=0
( # ( cd … ) 
  cd "${work_directory}"

  case $verboseflag in
  1)
    msg "# ${institute}: ${GREEN}Time stamp(s):${NOFORMAT} ${timestamps}"
    msg "# ${institute}: ${GREEN}Working directory:${NOFORMAT} ${work_directory}"
  ;;
  esac

  if [[ "${timestamps%% *}" == "${timestamps}" ]]; then
    msg "# ${institute}: ${GREEN}Files to process (first 5 samples):${NOFORMAT}"
    printf "  %s\n" $( ls Thread-*${timestamps%% *}.rdf.gz | head -n 5 )
  else
    msg "# ${institute}: ${GREEN}Files to process (first + last 5 samples, with multiple time stamps):${NOFORMAT}"
    printf "  %s\n" $( ls Thread-*${timestamps%% *}.rdf.gz | head -n 5 ) # first
    printf "  …\n"
    printf "  %s\n" $( ls Thread-*${timestamps##* }.rdf.gz | head -n 5 ) # last
  fi

  read -n 1 -p "  Go on? (continue: yes or enter; n, no → stop)? " answer
  [[ -z "$answer" ]] && answer="Yes" # set 'Yes' on hitting enter (without input)
  
  case $answer in
  [Yy][Ee][Ss]|[Yy]|[Jj][Aa]|[Jj]) printf "  (${GREEN}continue${NOFORMAT})\n" ;;
  *) die "  ${NOFORMAT}(${RED}stop${NOFORMAT})";;
  esac

  for this_timestamp in ${timestamps};do 
    file_prefix_pattern=Thread-*${this_timestamp}
    rdf_source_pattern="${file_prefix_pattern}.rdf.gz";
    rdf_modified_pattern="${file_prefix_pattern}_modified.rdf.gz";
    rdf_modified_normalized_pattern="${file_prefix_pattern}_modified.rdf.normalized.ttl.trig.gz";
    this_timestamp_reportfile=$(date '+%Y%m%d-%Hh%Mm%Ss') ;
    
    msg "# ${institute}: ---------------------------------------------";
    msg "# ${institute}: ${GREEN}start fix RDF  ${NOFORMAT}${rdf_source_pattern} …";
    
    if ! [[ $( find . -maxdepth 1 -mindepth 1 -iname "${rdf_source_pattern-}" ) ]]; then msg "# ${ORANGE}${rdf_source_pattern-} not found${NOFORMAT} (skipped)"; continue; fi
    
    echo 'yes' > answer-yes.txt;
    /opt/jena-fuseki/import-sandbox/bin/fixRDF_before_validateRDFs.sh -s "${rdf_source_pattern}"  < answer-yes.txt > fixRDF_before_validateRDFs_${institute}_${this_timestamp_reportfile}.log 2>&1 
    
    msg "# ${institute}: ${GREEN}validate RDF   ${NOFORMAT}${rdf_modified_pattern} …";
    # for this_timestamp in 20221024-1401 20221024-1425;do 
    
    echo 'yes' > answer-yes.txt;
    /opt/jena-fuseki/import-sandbox/bin/validateRDFs.sh -s "$rdf_modified_pattern" -l "validate_RDF_${institute}-${this_timestamp_reportfile}.log" < answer-yes.txt  > validate_RDF_${institute}-processing-${this_timestamp_reportfile}.log 2>&1 
    printf "#   count of warn:  %d " $( grep --count --ignore-case 'warn'  validate_RDF_${institute}-${this_timestamp_reportfile}.log ) || this_exit_code=$?
    printf "  # %s\n" validate_RDF_${institute}-${this_timestamp_reportfile}.log
    
    case $this_exit_code in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
      msg "#   ${ORANGE}exit code ${this_exit_code} $(kill -l $this_exit_code)${NOFORMAT} (?grep …)" ;;
    esac

    printf "#   count of error: %d " $( grep --count --ignore-case 'error' validate_RDF_${institute}-${this_timestamp_reportfile}.log ) || this_exit_code=$?
    case $this_exit_code in [1-9]|[1-9][0-9]|[1-9][0-9][0-9])
      msg "#   ${ORANGE}exit code ${this_exit_code} $(kill -l $this_exit_code)${NOFORMAT} (?grep …)" ;;
    esac
    printf "  # %s\n" validate_RDF_${institute}-${this_timestamp_reportfile}.log

    msg "# ${institute}: ${GREEN}normalize      ${NOFORMAT}${rdf_modified_normalized_pattern} …" # all *warn-or-error.log(.gz) should be included in validate logs, so they can be removed
    [ $(ls *_modified.rdf*warn-or-error.log* 2> /dev/null | wc -l) -gt 0 ] && rm *_modified.rdf*warn-or-error.log*
    ! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
    /opt/jena-fuseki/import-sandbox/bin/convertRDF4import_normal-files_${institute}.sh -s "$rdf_modified_pattern" < answer-yes.txt  > convertRDF4import_normal-files-processing-${this_timestamp_reportfile}.log 2>&1 
    msg "# ${institute}: ${GREEN}Done.${NOFORMAT}"
    msg "# ${institute}: ${GREEN}Use the listing command to see created files:${NOFORMAT}"
    msg "#  ${BLUE}ls -l ${file_prefix_pattern}*${NOFORMAT}"
    msg "#  ${BLUE}ls -l ${file_prefix_pattern}* | sort --key=9.42  ${GRAY}# sort by file addendum${NOFORMAT}"
    msg "#  ${BLUE}ls -l ${file_prefix_pattern}* | sort --debug --key=9.42  ${GRAY}# sort debugging to see where sort is focused on${NOFORMAT}"
    msg "#  ${BLUE}head --lines 20 fixRDF_before_validateRDFs_${institute}_${this_timestamp_reportfile}.log   ${GRAY}# log of fixing RDF, all files: ${BLUE}ls fixRDF_before_validateRDFs*.log${NOFORMAT}"
    msg "#  ${BLUE}head --lines 20 validate_RDF_${institute}-processing-${this_timestamp_reportfile}*.log     ${GRAY}# log of validation, all files: ${BLUE}ls validate_RDF*.log${NOFORMAT}"
    msg "#  ${BLUE}head --lines 20 validate_RDF_${institute}-${this_timestamp_reportfile}*.log                ${GRAY}# log of validation itself${NOFORMAT}"
    msg "#  ${BLUE}head --lines 20 convertRDF4import_normal-files-processing-${this_timestamp_reportfile}.log ${GRAY}# log of normalization, all files: ${BLUE}ls convertRDF4import_normal*.log${NOFORMAT}"
    
  done
) # ( cd … )

# script logic end
