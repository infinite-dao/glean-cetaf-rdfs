#!/bin/bash
# Import inside the docker fuseki-app
#   (use only absolute paths)
# dependencies: /jena-fuseki/bin/s-post
# dependencies: RDF must be valid and clean, no unicode errors (use ./validateRDFs.sh)
# dependencies: RDF must be converted to *.trig.gz (use ./convertRDF4import_normal-files.sh)
# dependencies: docker image fuseki-app
# dependencies: sed
# dependencies: awk
# Usage example: /import-data/bin/import_rdf2trig.gz4docker-fuseki-app.sh -d 'xxx.jacq.org' -s 'Thread-*20211117-1006.rdf._normalized.ttl.trig.gz'

if grep -q docker /proc/1/cgroup; then 
    echo -e  "# \e[32mOK\e[0m inside docker "
else
   echo -e  "# \e[31mError:\e[0m script is executet on host but needs to run inside docker (stop)."
   echo -e  "#        You can enter the docker container by «docker exec -it containername bash», e.g. docker exec -it fuseki-app bash"
   exit
fi

SPARQL_END_POINT_DATASET="CETAF-IDs"
datetime_now=$(date '+%Y%m%d-%H%M%S')
URN_DOMAINNAME='id.snsb.info'
GRAPH='default'

# LOGFILE="Thread-import-trig_data.biodiversitydata.nl_0000001-7963204${datetime_now}.log"
# FILE_SEARCH_PATTERN="Thread-*_coldb.mnhn.fr_*2020-06-*.rdf._normalized.ttl.trig.gz"
# FILE_SEARCH_PATTERN="Thread-*_data.biodiversitydata.nl*.rdf._normalized.ttl.trig.gz"
# 
# LOGFILE="Thread-import-trig_jacq.org_${datetime_now}.log"
# FILE_SEARCH_PATTERN="Thread_*tub.jacq.org*.rdf._normalized.ttl.trig.gz"
# THIS_WD="/import-data/rdf/tub-jacq-org"
# 
# FILE_SEARCH_PATTERN="Thread_*lagu.jacq.org*.rdf._normalized.ttl.trig.gz"
# # FILE_SEARCH_PATTERN_NOT="Thread_*lagu.jacq.org*.rdf._normalized.ttl.trig.gz"
# THIS_WD="/import-data/rdf/tmpimport-jacq"

# LOGFILE="Thread-import-herbarium.bgbm.org_${datetime_now}.log"
# FILE_SEARCH_PATTERN="Thread*herbarium.bgbm.org*.rdf._normalized.ttl.trig.gz"
# THIS_WD="/import-data/rdf/tmpimport-bgbm"

LOGFILE="Import_Thread-kew.org_${datetime_now}.log"
FILE_SEARCH_PATTERN="Thread*.kew*_2020-0[89]-[12]*.rdf._normalized.ttl.trig.gz"
THIS_WD="/import-data/rdf/tmpimport-kew"

# LOGFILE="Import_Thread-snsb.info_${datetime_now}.log"
# FILE_SEARCH_PATTERN="Threads*import*_normalized.ttl.one_lines_filtered.trig"
# FILE_SEARCH_PATTERN="SNSB_import_*_*.rdf.normalized.ttl.filtered.trig"
# FILE_SEARCH_PATTERN="SNSB_import_[3-5]_*.rdf.normalized.ttl.filtered.trig"
# THIS_WD="/import-data/rdf/tmpimport-snsb.info"


FILE_SEARCH_PATTERN="Thread-*_jacq.org_20211117-1006.rdf._normalized.ttl.trig.gz"
FILE_SEARCH_PATTERN="JACQ-*_*.rdf._normalized.ttl.trig.gz"
THIS_WD="/import-data/rdf/tmpimport-jacq_20211206"

FILE_SEARCH_PATTERN="Thread-*finnland.fi_20211206-1647.rdf._normalized.ttl.trig.gz"
LOGFILE="Import_Thread-finland.fi_${datetime_now}.log"
THIS_WD="/import-data/rdf/Finnland"
URN_DOMAINNAME='finnland.fi'

THIS_WD="${PWD}"


LOGFILE="Import_inside_Thread-XX-data.rbge.org.uk_20220228ff_${datetime_now}.log"
URN_DOMAINNAME='data.rbge.org.uk'

LOGFILE="Import_Thread-jacq.org_${datetime_now}.log"
URN_DOMAINNAME='jacq.org'
# LOGFILE=""
# URN_DOMAINNAME=""

i=1; 
# set (i)ndex and (n)umber of files alltogether


function reset_logfile_name () {
  LOGFILE_DEFAULT=`printf "Import_fuseki_%s_${URN_DOMAINNAME}_${datetime_now}.log" X`
  if [[ -z "${LOGFILE// /}"  ]];then LOGFILE=$LOGFILE_DEFAULT; fi
}

function file_search_pattern_default () {
  FILE_SEARCH_PATTERN_DEFAULT=`printf "SNSB_import_*_%s_*normalized*.trig.gz" $(date '+%Y%m%d')`
}
file_search_pattern_default

function testdependencies () {
  local doexit=0
  if ! command -v ruby &> /dev/null
  then
      echo -e "\e[31m# Error: Command ruby could not be found. This is needed for s-post. Please install it, e.g.: \e[0mapt-get update; apt-get install -y --no-install-recommends ruby-full";
      doexit=1;
  fi
  if ! command -v sed &> /dev/null
  then
      echo -e "\e[31m# Error: Command sed could not be found. This is needed for regular expressions. Please install it, e.g.: \e[0mapt-get update; apt-get install -y --no-install-recommends sed";
      doexit=1;
  fi
  if ! command -v zcat &> /dev/null
  then
      echo -e "\e[31m# Error: Command zcat could not be found. This is needed for s-post. Please install it (perhaps gzip tools or so)\e[0m";
      doexit=1;
  fi
  if [[ $doexit -gt 0 ]]; then exit; fi
}

function test_max_filesize () {
  # Description: Warns about the maximal file size in the set. If it could be to large and continue can result in failure.
  # dependency FILE_SEARCH_PATTERN
  # dependency FILE_SEARCH_PATTERN_NOT
  # dependency THIS_WD
  local this_max_file_size_and_file=""
  local this_max_size_value=0
  local this_max_size_filename=""
  local this_max_file_size_may_be_too_large=0
  local this_msg_large_files=""
  local this_yesOrNo=""

  if [[ -z "${FILE_SEARCH_PATTERN_NOT// /}" ]]; then
    this_max_file_size_and_file=`find "${THIS_WD}" -maxdepth 1 -type f -iname "${FILE_SEARCH_PATTERN##*/}" -exec stat --format='%s:%N' '{}' ';' \
      | sed --regexp-extended 's@/.+/([^/]+)@\1@' \
      | sort --version-sort --reverse \
      | sed --silent '1p' `
    # 19611976:'Thread-3_finnland.fi_20211206-1647.rdf._normalized.ttl.trig.gz'
    # 19583180:'Thread-2_finnland.fi_20211206-1647.rdf._normalized.ttl.trig.gz'
    # 19563767:'Thread-8_finnland.fi_20211206-1647.rdf._normalized.ttl.trig.gz'
    # 19552737:'Thread-1_finnland.fi_20211206-1647.rdf._normalized.ttl.trig.gz'
  else
    this_max_file_size_and_file=`find "${THIS_WD}" -maxdepth 1 -type f -iname "${FILE_SEARCH_PATTERN##*/}" \
      -and -not -iname "${FILE_SEARCH_PATTERN_NOT##*/}" -exec stat --format='%s:%N' '{}' ';' \
      | sed --regexp-extended 's@/.+/([^/]+)@\1@' \
      | sort --version-sort --reverse \
      | sed --silent '1p' `
  fi

  this_max_size_value=`echo $this_max_file_size_and_file | awk -v FPAT="([^:]+)|('[^']+')" '{ print $1 }'`
  this_max_size_filename=`echo $this_max_file_size_and_file | awk -v FPAT="([^:]+)|('[^']+')" '{ print $2 }'`

  if [[ `echo "$this_max_size_filename" | grep -i "trig.gz'"`  ]];then
    if [[ $( expr $this_max_size_value + 0 ) -ge 20000000 ]]; then
      this_msg_large_files="# \e[31mWarning:\e[0m the compressed file size is greater 20’000’000 bytes: $this_max_size_value, see $this_max_size_filename"; 
      this_msg_large_files="${this_msg_large_files}\n# consider splitting the files for smoother import"; 
      this_max_file_size_may_be_too_large=1;
    fi
  else 
    if [[ $( expr $this_max_size_value + 0 ) -ge 400000000 ]]; then
      this_msg_large_files="# \e[31mWarning:\e[0m the uncompressd file size is greater 400’000’000 bytes: $this_max_size_value, see $this_max_size_filename"; 
      this_msg_large_files="${this_msg_large_files}\n# consider splitting the files for smoother import"; 
      this_max_file_size_may_be_too_large=1;
    fi
  fi

  if [[ $this_max_file_size_may_be_too_large -gt 0 ]]; then
    echo -e "$this_msg_large_files"
    echo -ne "# \e[1mDo you want to continue?\e[0m “yes” or “no” (default: no)]: \e[0m"
    read this_yesOrNo
    case $this_yesOrNo in
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
  fi
}
test_max_filesize

function usage() { 
  reset_logfile_name;
  echo -e "# ######################################################" 1>&2; 
  echo -e "# Import TriG-normalized format inside Docker fuseki-app" 1>&2; 
  echo -e "# Note that you cannot overwrite data with s-post, you have to delete them before." 1>&2; 
  echo -e "# Usage: \e[32m${0##*/}\e[0m [-s 'SNSB_import_[3-5]_*.normalized*.trig.gz']" 1>&2; 
  echo    "#   -h  ................................................ show this help usage" 1>&2; 
  echo -e "#   -d  \e[32m'CETAF-IDs-test-graphs'\e[0m ............. data set to import to (default: $SPARQL_END_POINT_DATASET)" 1>&2; 
  echo -e "#   -u  \e[32m'data.nhm.ac.uk'\e[0m .................... URN domainname of this harvest (default: $URN_DOMAINNAME)" 1>&2; 
  echo -e "#   -g  \e[32m'Paris_MNHN'\e[0m ........................ optional graph name to import into (by standard it is imported to the default graph)" 1>&2; 
  echo -e "#   -s  \e[32m'SNSB_import_*file-search-pattern*.trig.gz'\e[0m .... optional specific search pattern" 1>&2; 
  echo -e "#       Note: better use quotes for pattern with asterisk '*pattern*'" 1>&2; 
  echo -e "#       (default: '${FILE_SEARCH_PATTERN_DEFAULT}')" 1>&2; 
  echo -e "#   -l \e[32m'special_logfile_20201101.log'\e[0m ....... logfile output" 1>&2; 
  echo -e "#       (default: $LOGFILE_DEFAULT)" 1>&2; 
  echo -e "#   -w \e[32m'/import-data/rdf/tmpimport-kew'\e[0m ..... working directory" 1>&2; 
  echo -e "#       (default: $THIS_WD)" 1>&2; 
  testdependencies;
  exit 1; 
}

function processinfo () {
  reset_logfile_name
  echo     "#############################################################"
  echo     "# Import TriG-normalized format inside Docker fuseki-app ..."
  echo     "# Steps before:"
  echo     "# * to check RDF use   validateRDF.sh "
  echo     "# * to convert RDF use convertRDF4import_normal-files.sh "
  echo     "# * manully delete old data (you cannot overwrite data with s-post on import)" 1>&2; 
  echo     "# Now ..."
  echo  -e "# * we import via \e[34mruby s-post\e[0m (we can use compressed *.trig.gz or uncompressed files for it)"
  echo  -e "# * we import to SPARQL end point http://localhost:3030/\e[32m${SPARQL_END_POINT_DATASET}\e[0m"
  echo  -e "# Read directory:  \e[32m${THIS_WD}\e[0m ..."
  echo  -e "# Import GRAPH:    \e[32m${GRAPH}\e[0m ..."
  echo  -e "# Data set:        \e[32m${SPARQL_END_POINT_DATASET}\e[0m ..."
  echo  -e "# Log file:        \e[32m/import-data/${LOGFILE}\e[0m"
  testdependencies;

  if [[ -z "${FILE_SEARCH_PATTERN_NOT// /}" ]]; then
    if [[ $n -eq 0 ]];then
  echo -ne "# \e[31mNothing found to import (${n} files)\e[0m using search pattern (within ${THIS_WD}):\n#   «\e[32m${FILE_SEARCH_PATTERN}\e[0m»\n# [stop here]\n";
  exit 1
    else
  echo -ne "# Do you want to import \e[32m${n}\e[0m files with search pattern: «\e[32m${FILE_SEARCH_PATTERN}\e[0m» ?\n# [yes or no (default: no)]: "
    fi
  else
    if [[ $n -eq 0 ]];then
  echo -ne "# \e[31mNothing found to import (${n} files)\e[0m using search pattern (within ${THIS_WD}):\n#   «\e[32m${FILE_SEARCH_PATTERN}\e[0m» but not «\e[33m${FILE_SEARCH_PATTERN_NOT}\e[0m»\n# [stop here]\n";
  exit 1
    else
  echo -ne "# Do you want to import \e[32m${n}\e[0m files with search pattern: «\e[32m${FILE_SEARCH_PATTERN}\e[0m» but not «\e[33m${FILE_SEARCH_PATTERN_NOT}\e[0m»?\n# [\e[32myes\e[0m or \e[31mno\e[0m (default: no)]: \e[0m"
    fi
  fi
}

if [[ ${#} -eq 0 ]]; then
    usage; exit 0;
fi

while getopts "hd:g:l:s:u:w:" this_opt; do
    case "${this_opt}" in
        d)
            SPARQL_END_POINT_DATASET=${OPTARG}
            if   [[ -z ${SPARQL_END_POINT_DATASET// /} ]] ; then SPARQL_END_POINT_DATASET=CETAF-IDs ; fi
            ;;
        g)
            GRAPH=${OPTARG}
            if   [[ -z ${GRAPH// /} ]] ; then GRAPH=default ; fi
            ;;
        h)
            usage; exit 0;
            ;;
        l)
            LOGFILE=${OPTARG}
            if   [[ -z ${LOGFILE// /} ]] ; then reset_logfile_name ; fi
            ;;
        s)
            FILE_SEARCH_PATTERN="${OPTARG}"
            if   [[ -z ${FILE_SEARCH_PATTERN// /} ]] ; then file_search_pattern_default; FILE_SEARCH_PATTERN="$FILE_SEARCH_PATTERN_DEFAULT" ; fi
            ;;
        u)
            # URN_DOMAINNAME_OPTION=${OPTARG}
            URN_DOMAINNAME=${OPTARG};
            # echo "# DEBUG getopts … case d: $URN_DOMAINNAME"
            reset_logfile_name;
            if   [[ -z ${URN_DOMAINNAME// /} ]] ; then echo "error: $URN_DOMAINNAME cannot be empty" >&2; usage; exit 1; fi
            ;;
        w)
            THIS_WD=${OPTARG}
            if   [[ -z ${THIS_WD// /} ]] ; then echo "error: $THIS_WD cannot be empty" >&2; usage; exit 1; fi
            ;;
        *)
            usage; exit 0;
            ;;
    esac
done
shift $((OPTIND-1))

if [[ -z "${FILE_SEARCH_PATTERN_NOT// /}" ]]; then
n=`find "${THIS_WD}" -maxdepth 1 -type f -iname "${FILE_SEARCH_PATTERN##*/}" | sort --version-sort | wc -l `
else
n=`find "${THIS_WD}" -maxdepth 1 -type f -iname "${FILE_SEARCH_PATTERN##*/}" -and -not -iname "${FILE_SEARCH_PATTERN_NOT##*/}" | sort --version-sort | wc -l `
fi

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

############################ gzip variant
# docker exec -it fuseki-app bash
# root@ebe5193146fe:/jena-fuseki

  # cd /jena-fuseki/bin/
  # LOGFILE="Thread-import-ttl_data.rbge.org.uk_2020-05-05_with_skiplist_${datetime_now}.log"
  
  # use always absolute paths
  for importDataFile in `if [[ -z "${FILE_SEARCH_PATTERN_NOT// /}" ]];then find "${THIS_WD}" -maxdepth 1 -type f -iname "${FILE_SEARCH_PATTERN##*/}" | sort --version-sort; else find "${THIS_WD}" -maxdepth 1 -type f -iname "${FILE_SEARCH_PATTERN##*/}" -and -not -iname "${FILE_SEARCH_PATTERN_NOT##*/}" | sort --version-sort;fi`; do
    # echo "# s-post ${importDataFile} ..."
    echo     "#----------------------------------------"
    printf   "# Import to GRAPH %s via s-post (%04d of %04d) from %s ...\n" $GRAPH $i $n "${importDataFile}" ; 
    if [[ `echo $FILE_SEARCH_PATTERN | grep -i '\.gz$'` ]]; then
      # 2022-04-28 s-post on its own cannot handle *.gz
      importDataFile_nonGzip=`echo "${importDataFile}" | sed --regexp-extended 's@(.+)\.gz@\1@'`
      importDataFile_temp="${importDataFile_nonGzip}_` date '+%Y-%m-%d_%Hh%Mm%Ss' `.${importDataFile_nonGzip##*.}"
      echo "#   extract temporary file ${importDataFile_temp##/*/} ... "
      zcat "${importDataFile}" > "${importDataFile_temp}"
      # echo "ruby /jena-fuseki/bin/s-post --verbose http://localhost:3030/CETAF-IDs default ${importDataFile_temp} >> /import-data/${LOGFILE}"
      # ruby /jena-fuseki/bin/s-post --verbose http://localhost:3030/${SPARQL_END_POINT_DATASET} default "${importDataFile_temp}" &>> "/import-data/${LOGFILE}"
      echo "#   s-post ... "
      ruby /jena-fuseki/bin/s-post --verbose http://localhost:3030/${SPARQL_END_POINT_DATASET} $GRAPH "${importDataFile_temp}" &>> "/import-data/${LOGFILE}"
      echo "#   remove temporary file  ${importDataFile_temp##/*/} ... "
      rm "${importDataFile_temp}"
    else 
      # echo "# ruby /jena-fuseki/bin/s-post --verbose http://localhost:3030/CETAF-IDs default ${importDataFile} >> /import-data/${LOGFILE}"
      # ruby /jena-fuseki/bin/s-post --verbose http://localhost:3030/${SPARQL_END_POINT_DATASET} default "${importDataFile}" &>> "/import-data/${LOGFILE}"
      echo "#   s-post ... "
      ruby /jena-fuseki/bin/s-post --verbose http://localhost:3030/${SPARQL_END_POINT_DATASET} $GRAPH "${importDataFile}" &>> "/import-data/${LOGFILE}"
    fi
    i=$((i + 1 ))
  done

n_failed_files=`cat "/import-data/${LOGFILE}" | grep "Failed" | wc -l `
n_created_files=`cat "/import-data/${LOGFILE}" | grep "201 Created" | wc -l `
n_ok_files=`cat "/import-data/${LOGFILE}" | grep "200 OK" | wc -l `
echo     "#----------------------------------------"
echo     "# Done. Check the import log file (if status is «200 OK», then it is fine)"

if [[ $n_created_files -gt 0 ]];then
printf   "# \e[32m%02d\e[0m files report status “\e[32m201 Created\e[0m”\n" $n_created_files
fi

if [[ $n_ok_files -eq 0 ]];then
printf   "# \e[33m%02d\e[0m files report status “\e[32m200 OK\e[0m” (something \e[33mis not right\e[0m; better check the logfile)\n" $n_ok_files
else
printf   "# \e[32m%02d\e[0m files report status “\e[32m200 OK\e[0m” (details see in log file below)\n" $n_ok_files
fi
if [[ $n_failed_files -gt 0 ]];then
printf   "# %02d files report status “\e[33mFailed\e[0m” (details see in log file below)\n" $n_failed_files
printf   "# %02d failed files can be checked by:\n#  grep --before-context=1 Failed /import-data/${LOGFILE}\n" $n_failed_files
fi
printf   "# \e[34mcat\e[0m /import-data/\e[32m${LOGFILE}\e[0m\n"
echo     "#########################################"

  # exit # eventually exit the container
