#!/bin/bash
set -eu
  # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
  # set -e -- option will cause a bash script to exit immediately when a command fails
  # set -o -- exit also on non-existing command, print also BASH settings
  # set -u -- this option causes the bash shell to treat unset variables as an error and exit immediately.
  # set -x -- the -x option causes bash to print each command before executing it. This can be a great help when trying to debug a bash script failure. Note that arguments get expanded before a command gets printed, which will cause our logs to contain the actual argument values that were present at the time of execution!
  # set -E -- traps are pieces of code that fire when a bash script catches certain signals. Aside from the usual signals (e.g. SIGINT, SIGTERM, …), traps can also be used to catch special bash signals like EXIT, DEBUG, RETURN, and ERR. However, reader Kevin Gibbs pointed out that using -e without -E will cause an ERR trap to not fire in certain scenarios.
###########################
# Usage: clean up RDF in files and fix some misstakes, make each RDF to be technically correct to have it ready for jena-apache’s rdfxml --validate
#   fixRDF_before_validateRDFs.sh -h # get help; see also function usage()
# dependency: sed
# dependency: file

# for this_file in `ls *coldb*get_2510001-2810000*.rdf | sort --version-sort`; do echo "# Insert </rdf:RDF> to $this_file"; echo '</rdf:RDF><!-- manually inserted 20200618 -->' >> "$this_file"; done
file_search_pattern="Thread-*data.biodiversitydata.nl*.rdf"
file_search_pattern="Test_sed*.rdf"
file_search_pattern="Threads_import_*_20201116.rdf"
file_search_pattern="Thread-*_jacq.org_20211108-1309.rdf"

INSTRUCT_TO_PRINT_ONLY_RDF_COMPARISON=0

exclamation_mark='!';
n=0;

setup_colors() {
  # 0 - Normal Style; 1 - Bold; 2 - Dim; 3 - Italic; 4 - Underlined; 5 - Blinking; 7 - Reverse; 8 - Invisible;

  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' 
    BOLD='\033[1m' ITALIC='\033[3m'
    BLUE='\033[0;34m' BLUE_BOLD='\033[1;34m' BLUE_ITALIC='\033[3;34m' 
    CYAN='\033[0;36m' CYAN_BOLD='\033[1;36m' CYAN_ITALIC='\033[3;36m' 
    GREEN='\033[0;32m' GREEN_BOLD='\033[1;32m' GREEN_ITALIC='\033[3;32m' 
    ORANGE='\033[0;33m' ORANGE_BOLD='\033[1;33m' ORANGE_ITALIC='\033[3;33m' 
    PURPLE='\033[0;35m' PURPLE_BOLD='\033[1;35m' PURPLE_ITALIC='\033[3;35m' 
    RED='\033[0;31m' RED_BOLD='\033[1;31m' RED_ITALIC='\033[3;31m' 
    YELLOW='\033[1;33m' YELLOW_BOLD='\033[1;33m' YELLOW_ITALIC='\033[3;33m'
  else
    NOFORMAT='' 
    BOLD='' ITALIC=''
    BLUE='' BLUE_BOLD='' BLUE_ITALIC='' 
    CYAN='' CYAN_BOLD='' CYAN_ITALIC='' 
    GREEN='' GREEN_BOLD='' GREEN_ITALIC='' 
    ORANGE='' ORANGE_BOLD='' ORANGE_ITALIC='' 
    PURPLE='' PURPLE_BOLD='' PURPLE_ITALIC='' 
    RED='' RED_BOLD='' RED_ITALIC='' 
    YELLOW='' YELLOW_BOLD='' YELLOW_ITALIC=''
  fi
}
setup_colors

function file_search_pattern_default () {
  printf "Thread-[0-9][0-9]_*_%s-[0-9][0-9][0-9][0-9].rdf" $(date '+%Y%m%d')
}
export file_search_pattern_default

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
          echo -e "# ${RED}Error: Neither command datediff or dateutils.ddiff could not be found. Please install package dateutils.${NOFORMAT}"
          doexit=1
        fi
        if ! command -v sed &> /dev/null 
        then
          echo -e "# ${RED}Error: command sed (stream editor) could not be found. Please install package sed.${NOFORMAT}"
          doexit=1
        fi
        if ! command -v bc &> /dev/null 
        then
          echo -e "# ${RED}Error: command bc (arbitrary precision calculator) could not be found. Please install package bc.${NOFORMAT}"
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
export -f get_timediff_for_njobs_new 
get_timediff_for_njobs_new --test

function usage() { 
  echo    "################ Fix RDF before validateRDF.sh #####################"
  echo -e "# Clean up and fix each of previousely merged RDFs from a download" 1>&2; 
  echo -e "# stack to be each valid RDF files. The file’s search patterns and" 1>&2; 
  echo -e "# fixing aso. is considered in development stage, so checking its" 1>&2; 
  echo -e "# right functioning is still of essence." 1>&2; 
  echo    "# -----------------------------------------------------------------"
  echo -e "# Usage: ${GREEN}${0##*/}${NOFORMAT} [-s 'Thread*file-search-pattern*.rdf']" 1>&2; 
  echo    "#   -h  ...................................... show this help usage" 1>&2; 
  echo    "#   -p  ..... print only RDF header comparison (no file processing)" 1>&2; 
  echo -e "#   -s  ${GREEN}'Thread*file-search-pattern*.rdf'${NOFORMAT} .... optional specific search pattern" 1>&2; 
  echo -e "#       Note: better use quotes for pattern with asterisk '*pattern*'" 1>&2; 
  echo -e "#       and use a narrow search pattern that really matches the RDF ${BOLD}source files only${NOFORMAT}" 1>&2; 
  echo -e "#       (default: '${GREEN}$(file_search_pattern_default)${NOFORMAT}')" 1>&2; 
  echo    "# -----------------------------------------------------------------"
  echo -e "# Eventually the processed files ${GREEN}…${BLUE}_modified${GREEN}.rdf${NOFORMAT} are get zip-ed to save space." 1>&2; 
  exit 1; 
}

function processinfo () {
if [[ $INSTRUCT_TO_PRINT_ONLY_RDF_COMPARISON -gt 0 ]];then
  echo     "################ Fix RDF before validateRDF.sh (print rdf header comparison) #####################"
  echo -e  "# Print only rdf header comparison"
  echo -e  "# Read directory:  ${GREEN}${this_wd}${NOFORMAT} ..."
  echo -e  "# Process for search pattern:  ${GREEN}$file_search_pattern${NOFORMAT} ..."
  if [[ ${n} -gt 0 ]];then
  echo -ne "# Do you want to print out rdf header comparison for ${GREEN}${n}${NOFORMAT} files with search pattern: «${GREEN}${file_search_pattern}${NOFORMAT}» ?\n# [${GREEN}yes${NOFORMAT} or ${RED}no${NOFORMAT} (default: no)]: ${NOFORMAT}"
  else 
  echo -ne "# ${NOFORMAT}By using search pattern: «${GREEN}${file_search_pattern}${NOFORMAT}» the number of processed files is ${RED}${n}${NOFORMAT}.\n"
  echo -ne "# ${RED}(Stop) We stop here; please check or add the correct search pattern, directory and/or data.${NOFORMAT}\n";
  exit 1;
  fi
else
  echo     "################ Fix RDF before validateRDF.sh #####################"
  echo -e  "# Working directory:             ${GREEN}${this_wd}${NOFORMAT} ..."
  echo -e  "# Files get processed as:        ${GREEN}…${BLUE}_modified${GREEN}.rdf${NOFORMAT} finally compressed to ${GREEN}*.rdf.gz${NOFORMAT} ..."
  echo -e  "# Original files are kept untouched and eventually compressed to: ${GREEN}*.rdf.gz${NOFORMAT} ..." # final line break
  echo -e  "# Do processing for search pattern: ${GREEN}$file_search_pattern${NOFORMAT} ..."
  if [[ ${n} -gt 0 ]];then
  echo -ne "# Do you want to process ${GREEN}${n}${NOFORMAT} files with above search pattern?\n# [${GREEN}yes${NOFORMAT} or ${RED}no${NOFORMAT} (default: no)]: ${NOFORMAT}"
  else 
  echo -ne "# ${NOFORMAT}By using above search pattern the number of processed files is ${RED}${n}${NOFORMAT}.\n# ${RED}(Stop) We stop here; please check or add the correct search pattern, directory and/or data.${NOFORMAT}\n";
  exit 1;
  fi
fi
}


this_wd="$PWD"
cd "$this_wd"

if [[ ${#} -eq 0 ]]; then
    usage; exit 0;
fi

while getopts "s:hp" o; do
    case "${o}" in
        h)
            usage; exit 0;
            ;;
        s)
            # TODO problems when file_search_pattern is not wrapped by quotes
            this_file_search_pattern=${OPTARG} 
            if [[ $this_file_search_pattern =~ ^- ]];then # the next option was given without this option having an argument
              echo -e "${ORANGE}Option Error:${NOFORMAT} option -s requires an argument, please specify e.g. ${ITALIC}-s 'Thread*file-search-pattern*.rdf.gz'${NOFORMAT} or let it run without -s option (default: '${GREEN}$(file_search_pattern_default)${NOFORMAT}')."; exit 1;
            fi
            file_search_pattern=$( [[ -z ${this_file_search_pattern// /} ]] && echo "$(file_search_pattern_default)" || echo "$this_file_search_pattern" );
            ;;
        p)
            INSTRUCT_TO_PRINT_ONLY_RDF_COMPARISON=1
            ;;
        *)
            usage; exit 0;
            ;;
    esac
done
shift "$((OPTIND-1))"

# echo "# DEBUG Options passed …"
# echo "find \"${this_wd}\" -maxdepth 1 -type f -iname \"${file_search_pattern##*/}\" | sort --version-sort | wc -l "

i=1; n=`find "${this_wd}" -maxdepth 1 -type f -iname "${file_search_pattern##*/}" | wc -l `
# echo "# find passed …"
# set (i)ndex and (n)umber of files alltogether

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
# echo "# Read passed …"

datetime_start=`date --rfc-3339 'ns'` ; # unix_seconds_start=$(date +"%s")
datetime_start_quoted=`date --rfc-3339 'ns' | ( read -rsd '' x; echo ${x@Q} )`; # unix_seconds_start=$(date +"%s")

# check all RDFs
if [[ $INSTRUCT_TO_PRINT_ONLY_RDF_COMPARISON -eq 0 ]];then
for this_file in `ls $file_search_pattern | sort --version-sort`; do
  printf "# ${GREEN}Process %03d of %03d in ${ITALIC}%s${GREEN} …${NOFORMAT}\n" $i $n "${this_file##*/}";
  
  if [[ $i -gt 1 ]];then
    printf "#    ";  get_timediff_for_njobs_new "$datetime_start" "$(date --rfc-3339 'ns')" "$n" "$((i - 1))"
  fi
  
  this_file_mimetype=$(file --mime-type "${this_file}" | sed -r 's@.*: ([^:]+)@\1@')
  this_file_modified="${this_file%.*}_modified.rdf";
  this_file_headers_extracted="${this_file%.*}_rdfRDF_headers_extracted.rdf"

  # check if this_file is compressed
  if [[ "$this_file_mimetype" == "application/gzip" ]];then
    this_file_modified="${this_file%.*.gz}_modified.rdf";
    this_file_headers_extracted="${this_file%.*.gz}_rdfRDF_headers_extracted.rdf"
    
    stat --printf="#    ${GREEN}Read out comperessd${NOFORMAT} ${ITALIC}%n${NOFORMAT} (%s bytes) using ${BLUE}zcat${NOFORMAT} …" "${this_file}"; printf " > ${ITALIC}%s${NOFORMAT} …\n" "${this_file_modified}";
    zcat "$this_file" > "$this_file_modified"
    
  else
    # assume text/xml
    if ! [[ "${this_file_mimetype}" == "text/xml" ]];then
      echo -e "#    ${RED}Error:${NOFORMAT} Please fix wrong file type: $this_file_mimetype, we expects file type “text/xml” (skip to next step)";
      continue;
    else
    printf "#    ${GREEN}Copy anew${NOFORMAT} ${ITALIC}%s${NOFORMAT} for processing …\n" "${this_file_modified}";
      cp --force "$this_file" "$this_file_modified"
      printf "#    ${GREEN}Compress source file${NOFORMAT} ${ITALIC}%s${NOFORMAT} (to keep storage minimal)…\n#    " "${this_file}";
      gzip --verbose "$this_file"
    fi
  fi
  
  if ! [[ -e "${this_file_modified}" ]]; then
    echo -e "#    ${RED}Error:${NOFORMAT} File not found to process: $this_file_modified (skip to next step)";
    continue;
  else
    sed --in-place 's@\r@@g' "${this_file_modified}" # to get sed properly working remove \r
  fi
  
  this_file_modified_mimetype=$(file --mime-type "${this_file_modified}" | sed -r 's@.*: ([^:]+)@\1@')
  # if ! [[ "${this_file_modified_mimetype}" == "text/xml" ]];then
  #   echo -e "#    ${RED}Error:${NOFORMAT} Please fix wrong file type: ${this_file_modified_mimetype}, we expects file type “text/xml” (skip to next step)";
  #   continue;
  # fi
  case "${this_file_modified_mimetype}" in
    "text/xml") # expected
    ;;
    "text/html")
    echo -e "#    ${GREEN}File seems interupted or seems to have HTML in it (file type: ${this_file_modified_mimetype})${NOFORMAT}" 
    ;;
    *)
    echo -e "#    ${RED}Error:${NOFORMAT} Please fix wrong file type: ${this_file_modified_mimetype}, we expects file type “text/xml” (skip to next step)";
    continue;
    ;;
  esac
    
  echo -e "#    ${GREEN}Extract all${NOFORMAT} <rdf:RDF …> to ${ITALIC}${this_file_headers_extracted}${NOFORMAT} ... " 

  # TODO check correct functioning
  sed --regexp-extended --quiet \
  '/<rdf:RDF/,/>/{ 
    s@[[:space:]]*<rdf:RDF[[:space:]]+@@; 
    s@\bxmlns:@\n ~ xmlns:@g;
    s@(\n ~ xmlns:[^[:space:]]+)[[:space:]]+@\1@g; # trim trailing space
    s@[[:space:]]*>[[:space:]]*@@; 
    /\n ~ xmlns:/!d; 
    /^[[:space:]\n]*$/d; s@~ @\n  @g; 
    p; 
  }' \
  "$this_file_modified" \
  | sort --unique \
  | sed --regexp-extended --quiet  '/^[[:space:]]+$/d;/^$/d;p;' \
  | sed "1i\<rdf:RDF
  \$a\>\n<\!-- *Initially* extracted RDF-headers from\n     ${this_file} -->" \
    > "${this_file_headers_extracted}"

  # # # # # # # # 
  # Start modifications
  if [[ $(grep --max-count=1 '<!DOCTYPE html' "${this_file_modified}") ]]; then
    echo -e "#    ${GREEN}fix RDF ${NOFORMAT}(separate DOCTYPE html) ... " 
    sed --regexp-extended --in-place '/<!DOCTYPE html/,/<\/html>/ {
      /<!DOCTYPE html/ {s@<!DOCTYPE html@\n&@; }
      /<\/html>/ {s@<\/html>@\n&\n<!-- DOCTYPE html replaced -->\n@; }
    }; ' "${this_file_modified}"
    echo -e "#    ${GREEN}fix RDF ${NOFORMAT}(delete DOCTYPE html things) ... " 
    sed --regexp-extended --in-place ' /<!DOCTYPE html/,/<\/html>/{ /<\/html>/!d; s@</html>@<!-- DOCTYPE html replaced -->@; }  ' "${this_file_modified}" #
  fi

  n_of_illegal_iri_character_in_urls=`sed -nr '/"https?:\/\/[^"]+[][\x20\xef\x80\xa1\xef\x80\xa2\^\x60\x5c]+[^"]*"/{p}' "${this_file_modified}" | wc -l`
  if [[ $n_of_illegal_iri_character_in_urls -gt 0 ]];then
    printf   "${GREEN}#    fix ${RED}illegal or bad IRI characters${GREEN} in %s URLs within \"http...double quotes\"...${NOFORMAT}\n" $n_of_illegal_iri_character_in_urls;
    sed --regexp-extended --in-place '
    # fix some characters that should be encoded (see https://www.ietf.org/rfc/rfc3986.txt)
    /"https?:\/\/[^"]+[][\x20\xef\x80\xa1\xef\x80\xa2\^\x60\x5c]+[^"]*"/ { # replace characters that are not allowed in URL
      :label.circumflex;          s@"(https?://[^"\^]+)\^@"\1%5E@; tlabel.circumflex;
      :label.urispace;            s@"(https?://[^\x20"]+)[\x20]@"\1%20@;  tlabel.urispace;
      :label.uriaccentgrave;      s@"(https?://[^\x60"]+)[\x60]@"\1%60@; tlabel.uriaccentgrave;
      :label.backslash;           s@"(https?://[^\x5c"]+)[\x5c]@"\1%5C@; tlabel.backslash;
      :label.leftsquaredbracket;  s@"(https?://[^\x5b"]+)[\x5b]@"\1%5B@; tlabel.leftsquaredbracket;
      :label.rightsquaredbracket; s@"(https?://[^\x5d"]+)[\x5d]@"\1%5D@; tlabel.rightsquaredbracket;
      :label.xefx80xa1;           s@"(https?://[^"\xef\x80\xa1]+)[\xef\x80\xa1]@"\1%EF%80%A1@; tlabel.xefx80xa1;
      :label.xefx80xa2;           s@"(https?://[^"\xef\x80\xa2]+)[\xef\x80\xa2]@"\1%EF%80%A2@; tlabel.xefx80xa2;
    }
 ' "${this_file_modified}"
  fi
  
  n_of_comments_with_double_minus=`grep --ignore-case '<!--.*[^<][^!]--[^>].*-->' "${this_file_modified}" | wc -l`
  if [[ $n_of_comments_with_double_minus -gt 0 ]];then
    printf   "${GREEN}#    fix ${RED}comments with double minus not permitted${GREEN} in %s URLs ...${NOFORMAT}\n" $n_of_comments_with_double_minus;
    sed --regexp-extended --in-place '
    /<!--.*[^<][^!]--[^>].*-->/ {# rdfparse Fatal Error:  (line 75 column 113): The string "--" is not permitted within comments.
      :label.uri_doubleminus_in_comment; s@[[:space:]](https?://.+)--([^>]* -->)@ \1%2D%2D\2@; tlabel.uri_doubleminus_in_comment; # if (s)ubstitution successful (t)ested, go back to label cycle
    }
 ' "${this_file_modified}"
  fi

  if [[ $(grep --max-count=1 'rdf:resource="[^"]\+$' "${this_file_modified}" ) ]];then
    printf   "${GREEN}#    fix ${RED}line break in IRI${GREEN} within «${ITALIC}rdf:resource=\"http...line break\"${GREEN} ...\n${NOFORMAT}";
    sed --regexp-extended --in-place '/rdf:resource="[^"]+$/,/"/{N; s@[[:space:]]*\n[[:space:]]*@@; }' "${this_file_modified}"
  fi
  

  echo -e "#    ${GREEN}fix common errors ${NOFORMAT}(also check or fix decimalLatitude decimalLongitude data type) ... " 
  sed --regexp-extended --in-place '
    s@(<)([[:alpha:]]+:)(decimalLongitude|decimalLatitude)(>)([^<>,]*),([^<>,]*)(</\2\3>)@\1\2\3 rdf:datatype="http://www.w3.org/2001/XMLSchema#decimal"\4\5.\6\7@g;
    s@(<)([[:alpha:]]+:)(decimalLongitude|decimalLatitude)(>)([^<>,]*)(</\2\3>)@\1\2\3 rdf:datatype="http://www.w3.org/2001/XMLSchema#decimal"\4\5\6@g;
    # add datatype to <dcterms:decimalLatitude> or <dcterms:decimalLatitude>
  
    s@(rdf:resource|rdf:about)=\"(https?://[^"]+)\2"@\1="\2"@;
    s@<(dwc:materialSampleID)>(https?://[^<>]+)\2</\1>@<\1>\2</\1>@;
    # remove double http…http… (some JACQ had such data)
    
    s@& @\&amp; @g;
    s@&([^ ;]+) @\&amp;\1 @g
    # fix non-encoded & to &amp;
    
    s@https://([^/ ]+):443/@https://\1/@g;
    # fix https :443 => default HTTPS port should be ommited (tells apache/bin/turtle --validate)  
  ' "${this_file_modified}"
  
  echo -e "#    ${GREEN}fix RDF ${NOFORMAT}(tag ranges: XML-head; XML-stylesheet; DOCTYPE rdf:RDF aso.) ... " 
  
  # better separate multiline replacements into processing steps (instead of merging all sed replacements together)
  sed --regexp-extended --in-place '
  s@</rdf:RDF> *<\?xml[^>]+\?>@<!-- rdf-closing and xml replaced -->@;
  0,/<rdf:RDF/!{
    /<rdf:RDF/,/>/ { # Note: it can have newline <rdf:RDF[\n or [:space:]+] …>
      :label_rdfRDF_in_multiline; N;  /<rdf:RDF[^>]+[^]]>/!b label_rdfRDF_in_multiline;
      s@<rdf:RDF[^>]+[^]]>@<!-- rdf:RDF REPLACED -->@g;
    }
  }
  # replace all <rdf:RDF…> but the first
  ' "${this_file_modified}"
  
  sed --regexp-extended --in-place '
  # remove comments that may be there before first starting <?xml…>
  0,/<\?xml/ {  
    /<\?xml/! d  # delete all comments before first <?xml
    /^.+<\?xml/ { s@^.+(<\?xml)@\1@ }
  } 
  
  # replace all DOCTYPE rdf
  /<!DOCTYPE rdf:RDF/,/\[/ {     
      :label_DOCTYPE; N;   /<!DOCTYPE rdf:RDF.+\]>/!b label_DOCTYPE;  
      s@(<!DOCTYPE rdf:RDF.+\]>)@<!-- DOCTYPE rdf:RDF REPLACED -->@
  }
  
  # 0,/<rdf:RDF/!{
  #   /<rdf:RDF/,/>/ { # Note: it can have newline <rdf:RDF[\n or [:space:]+] …>
  #     :label_rdfRDF_in_multiline; N;  /<rdf:RDF[^>]+[^]]>/!b label_rdfRDF_in_multiline;
  #     s@<rdf:RDF[^>]+[^]]>@<!-- rdf:RDF REPLACED -->@g;
  #   }
  # }
  # replace all <rdf:RDF…> but the first
  0,/<\?xml/!{
    /<\?xml/,/\?>/ {
      # TODO check on xml with <!xml[newline] (N; causes rdf:RDF not to replace)
      # :label_xml_declaration_not_single_line; N; /\?>/!b label_xml_declaration_not_single_line;
      s@(<\?xml[^>]+\?>)@<!-- xml replaced -->@g 
    }
  };
  # replace all <?xml…> but the first
  
  
  /<\?xml-stylesheet/,/\?>/ {
    :label_xmlstylesheet_declaration_not_single_line; N; /\?>/!b label_xmlstylesheet_declaration_not_single_line;
    s@(<\?xml-stylesheet[^>]+\?>)@<!-- xml-stylesheet replaced -->@g 
  }
  # s@(<\?xml-stylesheet [^>]+\?>)@<!-- xml-stylesheet replaced -->@
  # TODO check proper replacement /<\?xml-stylesheet /,/\?>/{ };
  # replace all stylesheet
  
  s@</rdf:RDF>@@; $ a\ </rdf:RDF>
  # replace all </rdf:RDF…> but append at the very last line

  # TODO check why regex patterns after this point fail sometimes, e.g. default port replacement
  ' "${this_file_modified}"
  
  echo -e "#    ${GREEN}substitude first <rdf:RDF > ${NOFORMAT}(use extracted headers from ${this_file_headers_extracted})... " 
  this_rdf_header_all_extracted=$( sed --regexp-extended --quiet  '/<rdf:RDF/,/>/{ :rdf_anchor;N; /<rdf:RDF[^>]*>/!b rdf_anchor; s@\n@\\n@g;  p; }' "${this_file_headers_extracted}" )
  sed --regexp-extended --in-place "
  0,/<rdf:RDF/{
    /<rdf:RDF/{
      :rdf_anchor;N; /<rdf:RDF[^>]*>/${exclamation_mark}b rdf_anchor;
      s@(<rdf:RDF[^>]*>)@${this_rdf_header_all_extracted}\n<!-- RDF header from first harvested RDF file --><!-- \1 -->@;
    }
  }
  " "${this_file_modified}"
  i=$((i + 1))
done


echo "# -----------------------"
if [[ $(echo "$file_search_pattern" | grep ".\bgz$") ]]; then
echo -e  "# ${GREEN}Done. Original data are kept in ${NOFORMAT}${file_search_pattern}${GREEN} ...${NOFORMAT}" # final line break
else
echo -e  "# ${GREEN}Done. Original data are kept in ${NOFORMAT}${file_search_pattern}.gz${GREEN} ...${NOFORMAT}" # final line break
fi

echo -e  "# ${GREEN}Each RDF file should be prepared for validation and could then be imported from this point on.${NOFORMAT}" # final line break
echo -e  "# ${GREEN}Check also if the RDF-head is equal to the extracted ones, e.g. in ${NOFORMAT}${this_file_headers_extracted}${GREEN} ...${NOFORMAT}" # final line break
echo -e  "# ${GREEN}You can use command pr to print the RDF headers side by side:${NOFORMAT}" # final line break
fi # $INSTRUCT_TO_PRINT_ONLY_RDF_COMPARISON

# file_search_pattern='Thread-*x500000-coldb.mnhn.fr_202203[0-9][0-9]-[0-9][0-9][0-9][0-9].rdf'
# TODO check correct functioning

# this_file_search_pattern=$([ $(echo "$file_search_pattern" | grep ".\bgz$") ] \
#   && echo "${file_search_pattern}" \
#   || echo "${file_search_pattern}.gz")


n=`find "${this_wd}" -maxdepth 1 -type f -iname "${file_search_pattern##*/}" | wc -l `
i=1
logfile_rdf_headers=fixRDF_before_validateRDFs_compare-headers.sh.log

echo '' > fixRDF_before_validateRDFs_compare-headers.sh.log
for this_file in `ls ${file_search_pattern} | sort --version-sort `; do 

  this_file_modified_is_gz=0
  this_file_is_gz=$([ $(echo "$this_file" | grep ".\bgz$") ] && echo 1  || echo 0 )
  
  if [[ $this_file_is_gz -gt 0 ]];then
    # echo " DEBUG $this_file is gz …"
    this_file_modified="${this_file%.*.gz}_modified.rdf";
    this_file_headers_extracted="${this_file%.*.gz}_rdfRDF_headers_extracted.rdf"
  else
    # echo "# DEBUG $this_file is not gz …"
    this_file_modified="${this_file%.*}_modified.rdf";
    this_file_headers_extracted="${this_file%.*}_rdfRDF_headers_extracted.rdf"
  fi
  
  if [[ -e "${this_file_modified}.gz" ]]; then this_file_modified_is_gz=1; fi
  
  echo    "# -----------------------";
  printf  "# ${GREEN}Compare RDF headers %03d of %03d based on ${ITALIC}%s${NOFORMAT} …${NOFORMAT}\n" $i $n "${this_file##*/}";
  echo -e "# ----------------------- ";

  echo    "# -----------------------" >> $logfile_rdf_headers;
  printf  "# Compare RDF headers %03d of %03d based on %s …\n" $i $n "${this_file##*/}" >> $logfile_rdf_headers;
  echo    "# -----------------------" >> $logfile_rdf_headers;
  i=$((i + 1))
  
  if ! [[ -e "$this_file_headers_extracted" ]]; then
    echo -e "#    ${RED}Error:${NOFORMAT} ${ITALIC}${this_file_headers_extracted}${NOFORMAT} not found (skipping) …"
    continue;
  fi
  
  if ! [[ -e "$this_file_modified" ]]; then
    if ! [[ -e "${this_file_modified}.gz" ]]; then 
    echo -e "#    ${RED}Error:${NOFORMAT} ${ITALIC}${this_file_modified}${NOFORMAT} or ${ITALIC}${this_file_modified}.gz${NOFORMAT} not found (skipping) …"
    echo -e "#    Error: ${this_file_modified} or ${this_file_modified}.gz not found (skipping) …"  >> $logfile_rdf_headers
    continue;
    fi
  fi
  
  echo -e "# ${GREEN}For checking unzippd modified files${NOFORMAT} …"
  echo -e "# For checking unzippd modified files …" >> $logfile_rdf_headers
  echo -e "  ${BLUE}sed${NOFORMAT} --quiet --regexp-extended ${ORANGE}'/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/${exclamation_mark}b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\\\n  \1@g; s@\\\n\\\n@\\\n@g; p;
  }'${NOFORMAT} '${this_file_modified}' \\
  | ${BLUE}pr${NOFORMAT} --page-width 140 --merge --omit-header \\
  '${this_file_headers_extracted}' -"; # final line break
  
  echo -e "  sed --quiet --regexp-extended '/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/${exclamation_mark}b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\\\n  \1@g; s@\\\n\\\n@\\\n@g; p;
  }' '${this_file_modified}' \\
  | pr --page-width 140 --merge --omit-header \\
  '${this_file_headers_extracted}' -" >> $logfile_rdf_headers  ; # final line break

  echo -e "# ${GREEN}For checking zipped modified files${NOFORMAT} …"
  echo -e "# For checking zipped modified files …"  >> $logfile_rdf_headers
  echo -e "  ${BLUE}zcat${NOFORMAT} ${this_file_modified}.gz | ${BLUE}sed${NOFORMAT} --quiet --regexp-extended ${ORANGE}'/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/${exclamation_mark}b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\\\n  \1@g; s@\\\n\\\n@\\\n@g; p;
  }'${NOFORMAT} \\
  | ${BLUE}pr${NOFORMAT} --page-width 140 --merge --omit-header \\
  '${this_file_headers_extracted}' -"; # final line break
  
  echo -e " zcat ${this_file_modified}.gz | sed --quiet --regexp-extended '/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/${exclamation_mark}b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\\\n  \1@g; s@\\\n\\\n@\\\n@g; p;
  }' \\
  | pr --page-width 140 --merge --omit-header \\
  '${this_file_headers_extracted}' -" >> $logfile_rdf_headers  ; # final line break
  echo -e "# ----------------------- ${GREEN}Logged also into ${ITALIC}$logfile_rdf_headers${NOFORMAT} …${NOFORMAT}";
done

# gzip all *_modified.rdf
for this_file in `ls ${file_search_pattern} | sort --version-sort `;do
  this_file_is_gz=$([ $(echo "$this_file" | grep ".\bgz$") ]  && echo 1  || echo 0 )
  
  this_file_modified=`[[ $this_file_is_gz -gt 0 ]] \
    && echo "${this_file%.*.gz}_modified.rdf" \
    || echo "${this_file%.*}_modified.rdf"`
  this_file_modified_gz="${this_file_modified}.gz"
  
  if [[ -e "$this_file_modified" ]];then 
    if [[ -e "${this_file_modified_gz}" ]];then 
      echo -e "# ${GREEN}Info:${NOFORMAT} remove old $this_file_modified_gz and replace it …"
      rm "$this_file_modified_gz"
    fi
    printf "# File "; gzip --verbose "$this_file_modified"
  else
    echo -e "# ${BLUE}Warning:${NOFORMAT} expected $this_file_modified but it was not found (skipping)"
    continue
  fi
done

datetime_end=`date --rfc-3339 'seconds'` ;
echo $( date --date="$datetime_start" '+# Time Started: %Y-%m-%d %H:%M:%S%:z' )
echo $( date --date="$datetime_end"   '+# Time Ended:   %Y-%m-%d %H:%M:%S%:z' )

