#!/bin/bash
# Usage: validate RDF files technically
#   validateRDFs.sh -h # get help; see also function usage()
# dependency: apache-jena-x.xx.x/bin


########################### Settings
apache_jena_bin=$([ -d "~/Programme/apache-jena-4.1.0/bin" ] && echo "~/Programme/apache-jena-4.1.0/bin" || echo "~/apache-jena-4.1.0/bin" )
if ! [ -d "${apache_jena_bin}" ];then
  echo -e "# \e[33m${apache_jena_bin}\e[0m does not exists to run rdfxml with!"
  echo    "# Download it from jena.apache.org and set path in \$apache_jena_bin accordingly."
  echo    "# (stop)"
  exit 1; 
fi                           

logfile="validate_RDF_kew_"` date '+%Y-%m-%d_%Hh%Mm%Ss' `".log"
logfile="validate_RDF_coldb.mnhn.fr_pvascular_"` date '+%Y-%m-%d_%Hh%Mm%Ss' `".log"
logfile="validate_RDF_kew_0400000-0410002_"` date '+%Y-%m-%d_%Hh%Mm%Ss' `".log"
logfile="validate_RDF_coldb.mnhn.fr_1000001-1200003_2020-09-08_"` date '+%Y-%m-%d_%Hh%Mm%Ss' `".log"
logfile="validate_RDF_id.snsb.info_"` date '+%Y-%m-%d_%Hh%Mm%Ss' `".log"
logfile="validate_RDF_"` date '+%Y-%m-%d_%Hh%Mm%Ss' `".log"

# file_search_pattern="Thread-*coldb.mnhn.fr*.rdf"
file_search_pattern="Thread*.rdf"
file_search_pattern="Thread*specimens.kew.org*2020-08-1*.rdf"
file_search_pattern="Thread*herbarium.bgbm.org*2020-08-1*.rdf"
file_search_pattern="Thread*jacq.org*.rdf.bak.repaired.rdf"
file_search_pattern="Thread*kew.org*.rdf"
file_search_pattern="Thread*kew.org*_0400000-0410002*.rdf"
file_search_pattern="Thread*coldb.mnhn.fr*_1000001-1200003_2020-09-08*.rdf"
file_search_pattern="Threads_import_*_20201116.rdf"
###########################

function file_search_pattern_default () {
  file_search_pattern_default=`printf "Threads_import_*_%s.rdf" $(date '+%Y%m%d')`
}
file_search_pattern_default

function usage() { 
  echo -e "############ Validate RDF (using apache jena binary) #################" 1>&2; 
  echo -e "# Usage: \e[32m${0##*/}\e[0m [-s 'Thread*file-search-pattern*.rdf']" 1>&2; 
  echo    "#   -h  ...................................... show this help usage" 1>&2; 
  echo -e "#   -s  \e[32m'Thread*file-search-pattern*.rdf'\e[0m .... optional specific search pattern" 1>&2; 
  echo -e "#       Note: better use quotes for pattern with asterisk '*pattern*' (default: ${file_search_pattern_default})" 1>&2; 
  echo -e "# It uses \e[32m${apache_jena_bin}/rdfxml\e[0m --validate RDF_file.rdf" 1>&2; 
  echo -e "# Log file would be ${logfile}" 1>&2; 
  exit 1; 
}

function processinfo () {
# # # # 
if [[ $debug_mode -gt 0  ]];then
echo -e  "\e[32m############  Validate RDF (\e[31mdebug mode\e[35m) ####\e[0m"
else
echo -e  "\e[32m############  Validate RDF #################\e[0m"
fi
echo     "############ Validate RDF #################"
echo     "# Check it via ${apache_jena_bin}/rdfxml "
echo     "# Log goes to:     '${logfile}' ..."
echo     "# Read directory:  '${this_wd}' ..."
echo -ne "\e[32m# Do you want to validate ${n} files with search pattern: «${file_search_pattern}» ?\n# [\e[32myes\e[32m or \e[31mno\e[32m (default: no)]: \e[0m"
}


this_wd="$PWD"
i=1; n=`find "${this_wd}" -maxdepth 1 -type f -iname "${file_search_pattern##*/}" | sort --version-sort | wc -l `
# set (i)ndex and (n)umber of files alltogether

while getopts ":s:h" options; do
    case "${options}" in
        h)
            usage; exit 0;
            ;;
        s)
            file_search_pattern=${OPTARG}
            if   [[ -z ${file_search_pattern// /} ]] ; then 
              file_search_pattern_default; file_search_pattern="$file_search_pattern_default" ; 
              shift
            else
              shift 2
            fi
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))


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


echo "" > "$logfile" # empty log file

# check all RDFs
for this_file in `find "${this_wd}" -maxdepth 1 -type f -iname "${file_search_pattern##*/}" | sort --version-sort`; do
  printf "# Process %03d of %03d in %s\n" $i $n "${this_file##*/}"; 
  [ -f "$this_file" ] && echo -en "\n${this_file##*/} :: " >> "$logfile" && ${apache_jena_bin}/rdfxml --validate "$this_file" &>> "$logfile"
  i=$((i + 1 ))
done
echo "" >> "$logfile" # final line break

echo     "# Done. Check log file ${logfile} ..."
echo     "cat ${logfile} # read the entire file"
n_warn_or_errors=`grep --ignore-case  'warn\|error' ${logfile} | wc -l`
if [[ $n_warn_or_errors -gt 0 ]];then
printf   "# \e[33m%d warnings or errors\e[0m found using the following command\n" $n_warn_or_errors
else
printf   "# \e[32mNo or %d warnings or errors found, using the following command\e[0m\n" $n_warn_or_errors
fi
echo     "grep --ignore-case --context=1 'warn\|error' ${logfile} # search for “warn” or “error”"
