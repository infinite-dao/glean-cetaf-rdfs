#!/bin/bash
set -eu
  # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
  # set -e -- option will cause a bash script to exit immediately when a command fails
  # set -o -- exit also on non-existing command, print also BASH settings
  # set -u -- this option causes the bash shell to treat unset variables as an error and exit immediately.
  # set -x -- the -x option causes bash to print each command before executing it. This can be a great help when trying to debug a bash script failure. Note that arguments get expanded before a command gets printed, which will cause our logs to contain the actual argument values that were present at the time of execution!
  # set -E -- traps are pieces of code that fire when a bash script catches certain signals. Aside from the usual signals (e.g. SIGINT, SIGTERM, …), traps can also be used to catch special bash signals like EXIT, DEBUG, RETURN, and ERR. However, reader Kevin Gibbs pointed out that using -e without -E will cause an ERR trap to not fire in certain scenarios.
########################### Settings
# Usage: validate RDF files technically
#   validateRDFs.sh -h # get help; see also function usage()
# dependency: ~/apache-jena-x.xx.x/bin (in the home directory)

########################### Settings
apache_jena_bin=""

# # # # 
# find latest version of apache jena assume apache_jena_bin in: ~/Programme OR ~ OR /opt/jena-fuseki/import-sandbox/bin
# TODO check find ~ -maxdepth 1  -iname 'apache-jena*' | sort --version-sort --reverse
apache_jena_folder=$(find ~/Programme -maxdepth 1 -type d -iname 'apache-jena*' 2>/dev/null | sort --version-sort --reverse | head -n 1)
if [[ -z ${apache_jena_folder// /} ]];then
  apache_jena_folder=$(find ~ -maxdepth 1 -type d -iname 'apache-jena*' 2>/dev/null | sort --version-sort --reverse | head -n 1);
fi
if [[ -z ${apache_jena_folder// /} ]];then
  apache_jena_folder=$(find /opt/jena-fuseki/import-sandbox/bin -maxdepth 1 -type d -iname 'apache-jena*' 2>/dev/null | sort --version-sort --reverse | head -n 1);
fi

if ! [[ -z ${apache_jena_folder// /} ]];then apache_jena_bin="${apache_jena_folder}/bin"; fi


if ! [ -d "${apache_jena_bin}" ];then
  echo -e "# apache_jena_bin \e[33m${apache_jena_bin}\e[0m does not exists to run rdfxml with!"
  echo    "# We searched in ~/Programme OR " ~ " OR /opt/jena-fuseki/import-sandbox/bin"
  echo    "# Locate it manually and set the right value in this script (see \$apache_jena_bin)."
  echo    "# Or download it from jena.apache.org to one of the above paths"
  echo    "# (stop)"
  exit 1;
fi
# # # # 

logfile="validate_RDF_kew_"` date '+%Y%m%d-%Hh%Mm%Ss' `".log"
logfile="validate_RDF_coldb.mnhn.fr_pvascular_"` date '+%Y%m%d-%Hh%Mm%Ss' `".log"
logfile="validate_RDF_kew_0400000-0410002_"` date '+%Y%m%d-%Hh%Mm%Ss' `".log"
logfile="validate_RDF_id.snsb.info_"` date '+%Y%m%d-%Hh%Mm%Ss' `".log"
logfile="validate_RDF_data.rbge.org.uk_20220228_"` date '+%Y%m%d-%Hh%Mm%Ss' `".log"
logfile="validate_RDF_coldb.mnhn.fr_xx_20220321_"` date '+%Y%m%d-%Hh%Mm%Ss' `".log"
logfile="validate_RDF_coldb.mnhn.fr_xx_20220404_"` date '+%Y%m%d-%Hh%Mm%Ss' `".log"
logfile="validate_RDF_mjg-jacq.org_"` date '+%Y%m%d-%Hh%Mm%Ss' `".log"

# file_search_pattern="Thread-*coldb.mnhn.fr*.rdf"
file_search_pattern="Thread*.rdf"
file_search_pattern="Thread*specimens.kew.org*2020-08-1*.rdf"
file_search_pattern="Thread*herbarium.bgbm.org*2020-08-1*.rdf"
file_search_pattern="Thread*jacq.org*.rdf.bak.repaired.rdf"
file_search_pattern="Thread*kew.org*.rdf"
file_search_pattern="Thread*kew.org*_0400000-0410002*.rdf"
file_search_pattern="Thread*coldb.mnhn.fr*_1000001-1200003_2020-09-08*.rdf"
file_search_pattern="Threads_import_*_20201116.rdf"
file_search_pattern="Thread-*_jacq.org_20211108-1309.rdf"
###########################
this_wd="$PWD";
cd "$this_wd"; 

n=`find "${this_wd}" -maxdepth 1 -type f -iname "${file_search_pattern##*/}" | sort --version-sort | wc -l `

function file_search_pattern_default () {
  printf "Thread-[0-9]*-*%s*_modified.rdf.gz" $(date '+%Y%m%d')
}
export file_search_pattern_default

function default_log_file () {
  printf "validate_RDF_$(date '+%Y%m%d-%Hh%Mm%Ss').log"
}
export default_log_file

function usage() { 
  echo -e "############ \e[32mValidate RDF\e[0m (using apache jena binary) #################" 1>&2; 
  echo -e "# This script uses \e[34m${apache_jena_bin}/rdfxml\e[0m --validate RDF_file.rdf" 1>&2; 
  echo -e "# " 1>&2; 
  echo -e "# Usage: \e[34m${0##*/}\e[0m [-s 'Thread-*_modified.rdf.gz' ] [-l 'validate_RDF_specific-file-case.log' ]" 1>&2; 
  echo    "#   -h  ...................................... show this help usage" 1>&2; 
  echo -e "#   -s  \e[32m'Thread*file-search-pattern*.rdf'\e[0m ...... optional specific search pattern" 1>&2; 
  echo -e "#       Note: the pattern set by the script now, is \e[32m'${file_search_pattern}'\e[0m (i.e. ${n} files)" 1>&2; 
  echo -e "#       you must use quotes around '*pattern*' (default: '$(file_search_pattern_default)')" 1>&2; 
  echo -e "#   -l  \e[32m'validate_RDF_specific-file-case.log'\e[0m .. optional a specific log file to write to in this directory" 1>&2; 
  echo -e "#       (default: '\e[32m$(default_log_file)\e[0m')" 1>&2; 
  exit 1; 
}


function processinfo () {
  # # # # 
  if [[ $debug_mode -gt 0  ]];then
  echo -e  "# ###########  \e[32mValidate RDF (\e[31mdebug mode\e[35m)\e[0m ####"
  else
  echo -e  "# ###########  \e[32mValidate RDF\e[0m #################"
  fi
  echo -e  "# \e[32mCheck it via:    \e[0m${apache_jena_bin}/rdfxml "
  echo -e  "# \e[32mRead directory:  \e[0m'${this_wd}' ..."
  echo -e  "# \e[32mLog goes to:     \e[0m'${logfile}' (see also script variable \$logfile) ..."
  if [[ $n -eq 0 ]];then
  echo -e  "# \e[33mWarning: there were \e[0m${n}\e[33m files found. Better check directory or search pattern:\e[0m"
  echo -e  "# \e[32m\e[0m  \e[3m${file_search_pattern}\e[0m (\e[33mis it right? \e[32mWe stop here\e[0m)"
  exit 0
  else
  echo -e  "# \e[32mDo you want to validate \e[0m${n}\e[32m files with search pattern:\e[0m"
  echo -ne "# \e[32m\e[0m  \e[3m${file_search_pattern}\e[0m \e[32m ?\e[0m\n# [\e[32myes\e[0m or \e[33mno\e[0m (default: no)]: "
  fi
}
export processinfo

# set (i)ndex and (n)umber of files alltogether

# s: → option s needs an argument
while getopts "hl:s:" options; do
    case "${options}" in
        h)
            usage;
            ;;
        l)
            this_logfile="${OPTARG}"
            if [[ $this_logfile =~ ^- ]];then # the next option was given without this option having an argument
              echo -e "\e[33mOption Error:\e[0m option -l requires an argument, please specify e.g. \e[3m-l 'special-logfile.log'\e[0m or let it run without -l option (default: '\e[32m$(default_log_file)\e[0m')."; exit 1;
            fi
            logfile=$( [[ -z ${this_logfile// /} ]] && echo "$(default_log_file)" || echo "$this_logfile" );
            ;;
        s)
            # TODO problems when file_search_pattern is not wrapped by quotes
            this_file_search_pattern=${OPTARG} 
            if [[ $this_file_search_pattern =~ ^- ]];then # the next option was given without this option having an argument
              echo -e "\e[33mOption Error:\e[0m option -s requires an argument, please specify e.g. \e[3m-s 'Thread*file-search-pattern*.rdf.gz'\e[0m or let it run without -s option (default: '\e[32m$(file_search_pattern_default)\e[0m')."; exit 1;
            fi
            file_search_pattern=$( [[ -z ${this_file_search_pattern// /} ]] && echo "$(file_search_pattern_default)" || echo "$this_file_search_pattern" );
            ;;
        *)
            usage;
            ;;
    esac
done

i=1; n=`find "${this_wd}" -maxdepth 1 -type f -iname "${file_search_pattern##*/}" | sort --version-sort | wc -l `

# echo "# Debug"
# echo "find \"${this_wd}\" -maxdepth 1 -type f -iname \"${file_search_pattern##*/}\""


processinfo
read yesorno
case $yesorno in
  [yY]|[yY][Ee][Ss])
    echo -e "# \e[32mContinue\e[0m ..."
  ;;
  [nN]|[nN][oO])
    echo -e "# \e[33mStop\e[0m";
    exit 1
  ;;
  *) 
  if [[ -z $yesorno ]];then
    echo -e "# No input (\e[33mstop\e[0m)"
  else 
    echo -e "# \e[33mInvalid input:\e[0m «${yesorno}» — expect \e[3my\e[0m, \e[3myes\e[0m or \e[3mn\e[0m, \e[3mno\e[0m (\e[33mstop\e[0m)"
  fi
  exit 1
  ;;
esac


echo "" > "$logfile" # empty log file

# check all RDFs
cd "${this_wd}"
for this_file in `find . -maxdepth 1 -type f -iname "${file_search_pattern##*/}" | sort --version-sort`; do
  printf "# \e[32mProcess %03d of %03d\e[0m in %s\n" $i $n "${this_file##*/}"; 
  # this_file_is_gz=$([ $(echo "$this_file" | grep ".\bgz$") ] && echo 1  || echo 0 )
  # rdfxml can handle *.gz
  [ -f "$this_file" ] && echo -en "\nValidate ${this_file##*/} :: " >> "$logfile" && ${apache_jena_bin}/rdfxml --validate "$this_file" 2>&1 | tee --append "$logfile" 
  ! [ -f "$this_file" ] && echo -en "\nWarning ${this_file##*/} not found " >> "$logfile"

  i=$((i + 1 ))
done
echo "" >> "$logfile" # final line break

echo -e  "# \e[32mDone\e[0m. Check log file ${logfile} ..."
echo -e  "\e[34mcat\e[0m ${logfile} \e[2m# read the entire file\e[0m"
n_warnings=`grep --ignore-case --count '\bwarn\b' ${logfile}`
n_errors=`grep --ignore-case --count '\berror\b' ${logfile}`

if [[ $(( $n_warnings + $n_errors + 0)) -eq 0 ]];then
printf   "# \e[32mNo warnings or errors found, using the following command\e[0m\n" 
echo -e  "\e[34mgrep\e[0m --ignore-case --context=1 'warn\\|error' ${logfile} \e[2m# search for “warn” or “error”\e[0m"
else
  if [[ $n_warnings -gt 0 ]];then
printf   "# \e[33m%d warnings\e[0m found using the following command\n" $n_warnings
echo -e  "\e[34mgrep\e[0m --ignore-case --context=1 '\\\bwarn\\\b' ${logfile} \e[2m# search for “warn(ings)” \e[0m"
  fi
  if [[ $n_errors -gt 0 ]];then
printf   "# \e[33m%d errors\e[0m found using the following command\n" $n_errors
echo -e  "\e[34mgrep\e[0m --ignore-case --context=1 '\\\berror\\\b' ${logfile} \e[2m# search for “error(s)” \e[0m"
  fi
fi
