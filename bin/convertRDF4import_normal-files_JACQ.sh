#!/bin/bash
###########################
# Usage: convert RDF files to normalised zipped files and check for adding ror.org IDs or dcterms:isPartOf etc. or remove technical stuff. It is expected to run these commands on a modified copy of the original RDF-file and have the original RDF-file untouched, so this programm is not intended to create backups.
# # # # # # # # # # # # # #
# dependencies $apache_jena_bin, e.g. in home directory (~/apache-jena-4.2.0/bin) or (/opt/jena-fuseki/import-sandbox/bin) with programs: turtle rdfparse
# dependencies gzip, sed, cat, perl, datediff
# # # # # # # # # # # # # #
# Description: Use RDF and convert to ...
# => n-tuples (rdfparse), normalise, remove empty, fix standard URIs (wikidata etc)
# => trig format (turtle)
# => compression
# +---------------------
# |  *.rdf
# |   `=> rdfparse.ttl
# |    `   (do normalizations of URIs)
# |      `=> normalized.ttl
# |          - turtle --validate    -> *.log file
# |          - turtle --output=trig -> *.trig file
# |            - modify data, add properties (ROR-ID, dcterms:hasPart, dcterms:isPartOf, dcterms:publisher)
# |            `=> gzip *.trig … *.trig.gz
# |      - clean empty (log) files
# |      - give summary
# +---------------------
###########################

debug_mode=0
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

get_timediff_for_njobs_new () {
# Description: calculate estimated time to finish n jobs (here, it only prints the estimate and $njobs_done_so_far is commented out)
# # # # # 
# Usage:
# get_timediff_for_njobs_new --test # to check for dependencies (datediff)
# get_timediff_for_njobs_new begintime nowtime ntotaljobs njobscurrentlydone
# get_timediff_for_njobs_new "2021-12-06 16:47:29" "2021-12-09 13:38:08" 696926 611613
# # # # # # # # # # # # # # # # # # 
# echo '('`date +"%s.%N"` ' * 1000)/1' | bc # get milliseconds
# echo '('`date +"%s.%N"` ' * 1000000)/1' | bc # get nanoseconds
# echo $( date --rfc-3339 'ns' ) | ( read -rsd '' x; echo ${x@Q} ) # escaped
    
  local this_command_timediff
  
  # read if test mode
  while [[ "$#" -gt 0 ]]
  do
    case $1 in
      -t|--test)
        if ! command -v datediff &> /dev/null &&  ! command -v dateutils.ddiff &> /dev/null
        then
          echo -e "# \e[31mError: Neither command datediff or dateutils.ddiff could not be found. Please install package dateutils.\e[0m"
          exit
        else
          return 0 # return [Zahl] und verlasse gesamte Funktion get_timediff_for_njobs_new
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
  local this_unixnanoseconds_start_timestamp=$(date --date="$1" '+%s.%N')
  local this_unixnanoseconds_now=$(date --date="$2" '+%s.%N')
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
    
    # njobs_done_so_far=`$this_command_timediff "@$this_unixnanoseconds_start_timestamp" "@$this_unixnanoseconds_now" -f "$this_i_job_counter done so far %dday(s) %Hh:%Mmin:%Ssec"`
    if [[ $this_unixseconds_todo -ge $(( 60 * 60 * 24 * 2 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo job to do, estimated end %ddays %Hh:%Mmin:%Ssec"`
    elif [[ $this_unixseconds_todo -ge $(( 60 * 60 * 24 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo job to do, estimated end %dday %Hh:%Mmin:%Ssec"`
    elif [[ $this_unixseconds_todo -ge $(( 60 * 60 * 1 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo job to do, estimated end %Hh:%Mmin:%Ssec"`
    elif [[ $this_unixseconds_todo -lt $(( 60 * 60 * 1 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo job to do, estimated end %Mmin:%Ssec"`
    fi
    
  fi
  #echo "from $this_n_jobs_all, $njobs_done_so_far; $this_msg_estimated_sofar"
  echo "$this_msg_estimated_sofar"
  # END estimate time to do 
}
export -f get_timediff_for_njobs_new 
get_timediff_for_njobs_new --test


function file_search_pattern_default () {
  printf "Thread-[0-9]*-*%s*_modified.rdf.gz" $(date '+%Y%m%d')
}
export file_search_pattern_default

function usage() {
  echo -e "# Convert RDF into TriG format (*.trig) format " 1>&2;
  echo -e "# Usage: \e[32m${0##*/}\e[0m [-s 'Thread*file-search-pattern*.rdf']" 1>&2;
  echo    "#   -h  ...................................... show this help usage" 1>&2;
  echo -e "#   -s  \e[32m'Thread*file-search-pattern*.rdf'\e[0m .... optional specific search pattern" 1>&2;
  echo -e "#       Note: better use quotes for pattern with asterisk '*pattern*' (default: '$(file_search_pattern_default)')" 1>&2;
  exit 1;
}


function processinfo () {
# # # #
if [[ $debug_mode -gt 0  ]];then
echo -e  "############  JACQ: Parse and normalize RDF to TriG (\e[31mdebug mode\e[0m) ####"
else
echo -e  "############  JACQ: Parse and normalize RDF to TriG #################"
fi

echo -e  "# \e[32mRecommendations\e[0m before running this script …"
echo -e  "# * to fix and clean amassed RDF before validating it use \e[32mfixRDF_before_validateRDFs.sh\e[0m"
echo -e  "# * to check RDF for technical validity use \e[32mvalidateRDF.sh\e[0m"
echo -e  "# Now ..."
echo -e  "# * we parse RDF, convert to n-tuples, remove empty fields, normalise content (some https -> http etc.)"
if [[ $debug_mode -gt 0  ]];then
echo -e  "# * in debug mode, we \e[33mkeep all processing files\e[0m (*.ttl, *normalized.ttl aso.)"
else
echo -e  "# * we convert all modified data into TriG format (*.trig) and \e[31mclean up all files\e[0m from in between (*_rdfparse.ttl, *_normalized.ttl etc.)"
fi
echo -e  "# * we compress the files with gzip to *.gz"
echo -e  "# * we remove empty log files (only *.log with content is kept)"
echo -e  "# * \e[33mmake sure to add ROR-ID as dwc:institutionID in this script\e[0m"
echo -e  "# Reading directory: \e[32m${this_pwd}\e[0m ..."
echo -ne "# Do you want to parse \e[32m${n}\e[0m files with search pattern:\n#  \e[3;32m${file_search_pattern}\e[0m ?\n"
if [[ $n_parsed -gt 0  ]];then
echo -e  "# All ${n_parsed} files (*.ttl*, *.log*) \e[33mget overwritten\e[0m ..."
fi
echo -ne "# [\e[32myes\e[0m or \e[31mno\e[0m (default: no)]: \e[0m"
}


# a=$([ "$b" == 5 ] && echo "$c" || echo "$d")

# TODO check and stop
# file_search_pattern="Thread-*data.rbge.org*_2020-05-05.rdf"
# file_search_pattern="Thread-1_coldb.mnhn.fr_2020-06-04_get_0264001-0274000.rdf"
############################
this_pwd=`echo $PWD`
cd "$this_pwd"

if [[ ${#} -eq 0 ]]; then
    usage; exit 0;
fi

while getopts ":s:h" o; do
    case "${o}" in
        h)
            usage; exit 0;
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
            usage
            ;;
    esac
done


# set (i)ndex and (n)umber of files alltogether
i=1; 
n=`find . -maxdepth 1 -type f -iname "${file_search_pattern}" | wc -l `
n_parsed=`find . -maxdepth 1 -type f -iname "${file_search_pattern}*.ttl*" -or -iname "${file_search_pattern}*.log*" | wc -l `


processinfo
read yno
case $yno in
  [yYjJ]|[yY][Ee][Ss]|[jJ][aA])
echo -e "# \e[32mContinue ...\e[0m"
  ;;
  [nN]|[nN][oO]|[nN][eE][iI][nN])
echo -e "# \e[31mStop\e[0m";
    exit 1
  ;;
  *)
echo -e "# \e[31mInvalid or no input (stop)\e[0m"
    exit 1
  ;;
esac

datetime_start=`date --rfc-3339 'ns'` ; # unix_seconds_start=$(date +"%s")

for rdfFilePath in `find . -maxdepth 1 -type f -iname "${file_search_pattern}" | sort --version-sort`; do
# loop through each file

  this_file_modified_is_gz=0
  this_file_is_gz=$([ $(echo "$rdfFilePath" | grep ".\bgz$") ] && echo 1  || echo 0 )
  if [[ $this_file_is_gz -gt 0 ]];then
    gunzip --quiet "$rdfFilePath"; 
    rdfFilePath=${rdfFilePath/%.gz/}
  fi
  import_ttl="${rdfFilePath}.ttl"
  import_ttl_normalized="${rdfFilePath}.normalized.ttl"
  log_rdfparse_warnEtError="${rdfFilePath}.ttl-warn-or-error.log"
  log_turtle2trig_warnEtError="${rdfFilePath}.turtle-validate-warn-or-error.log"
  echo "#-----------------------------" ;
  if [[ $i -gt 1 ]];then
    printf "# \e[32m(0) Info\e[0m ";  get_timediff_for_njobs_new "$datetime_start" "$(date --rfc-3339 'ns')" "$n" "$((i - 1))"
  fi
# parse
  #   sed --regexp-extended  '  /"https?:\/\/[^"]+[ `]+[^"]*"/ {:label.urispace; s@"(https?://[^" ]+)\s@"\1%20@; tlabel.urispace; :label.uriaccentgrave; s@"(https?://[^"`]+)`@"\1%60@; tlabel.uriaccentgrave; } ' test-space-in-URIs.rdf > test-space-in-URIs_replaced.rdf

  n_of_illegal_iri_character_in_urls=`grep --ignore-case '"https\?://[^"]\+[ \^\`\\]\+[^"]*"' "${rdfFilePath}" | wc -l`
  if [[ $n_of_illegal_iri_character_in_urls -gt 0 ]];then
    printf   "\e[31m# (0) Fix illegal IRI characters in %s URLs within \"http...double quotes\" ...\e[0m\n" $n_of_illegal_iri_character_in_urls;
    sed --regexp-extended --in-place '
    # fix some characters that should be encoded (see https://www.ietf.org/rfc/rfc3986.txt)
    /"https?:\/\/[^"]+[][ \^`\\]+[^"]*"/ { # replace characters that are not allowed in URL
      :label.circumflex;          s@"(https?://[^"\^]+)\^@"\1%5E@; tlabel.circumflex;
      :label.urispace;            s@"(https?://[^" ]+)\s@"\1%20@;  tlabel.urispace;
      :label.uriaccentgrave;      s@"(https?://[^"`]+)`@"\1%60@;   tlabel.uriaccentgrave;
      :label.backslash;           s@"(https?://[^"\\]+)\\@"\1%5C@; tlabel.backslash;
      :label.leftsquaredbracket;  s@"(https?://[^"\[]+)\[@"\1%5B@; tlabel.leftsquaredbracket;
      :label.rightsquaredbracket; s@"(https?://[^"\[]+)\]@"\1%5D@; tlabel.rightsquaredbracket;
    }
 ' "${rdfFilePath}"
  fi
  
  n_of_comments_with_double_minus=`grep --ignore-case '<!--.*[^<][^!]--[^>].*-->' "${rdfFilePath}" | wc -l`
  if [[ $n_of_comments_with_double_minus -gt 0 ]];then
    printf   "\e[31m# (0) Fix comments with double minus not permitted\e[32m in %s URLs ...\e[0m\n" $n_of_illegal_iri_character_in_urls;
    sed --regexp-extended --in-place '
    /<!--.*[^<][^!]--[^>].*-->/ {# rdfparse Fatal Error:  (line 75 column 113): The string "--" is not permitted within comments.
      :label.uri_doubleminus_in_comment; s@\s(https?://.+)--([^>]* -->)@ \1%2D%2D\2@; tlabel.uri_doubleminus_in_comment; # if (s)ubstitution successful (t)ested, go back to label cycle
    }
 ' "${rdfFilePath}"
  fi

  printf   "# \e[32m(1) Parse (%04d of %04d) to                  %s (N-triple statements) ...\n\e[0m"  $i $n "${import_ttl}" ;
  $apache_jena_bin/rdfparse -R "${rdfFilePath}" > "${import_ttl}" 2> "${log_rdfparse_warnEtError}"

# normalise
  echo -e  "# \e[32m(2)   copy to normalise N-triples            ${import_ttl_normalized} ...\e[0m"
  cat "${import_ttl}" | sed --regexp-extended  '
  /> "" \. *$/d; # delete empty value lines
  # do substitutions
  s@<https?:(//www.wikidata.org|//m.wikidata.org)/(wiki|entity)/(Q[^"/]+)@<http://www.wikidata.org/entity/\3@g; # we need /entity not /wiki
  s@<https:(//www.ipni.org)@<http:\1@g;
  s@<https:(//purl.oclc.org)@<http:\1@g;
  s@<https:(//isni.org/isni/)@<http:\1@g;
  s@<https?://www.w3.org/2002/07/owl/@<http://www.w3.org/2002/07/owl#@g;
  s@<https?:(//viaf.org/viaf/[0-9]+)[/#<>]*[^"<>]*>@<http:\1>@g;
  # add datatype to <dwc:decimalLatitude> or <dwc:decimalLatitude>
  # <http://lagu.jacq.org/object/AA-00001> <http://rs.tdwg.org/dwc/terms/decimalLongitude> "-88.98333" .
  # <http://lagu.jacq.org/object/AA-00001> <http://rs.tdwg.org/dwc/terms/decimalLatitude> "13.5"^^<http://www.w3.org/2001/XMLSchema#decimal> .
    s@(<http://rs.tdwg.org/dwc/terms/(decimalLongitude|decimalLatitude)>)( "[^"]+")( \.)@\1\3^^<http://www.w3.org/2001/XMLSchema#decimal>\4@;
  # <http://www.w3.org/2003/01/geo/wgs84_pos#lat> "The WGS84 latitude of a SpatialThing (decimal degrees)." 
  # <http://www.w3.org/2003/01/geo/wgs84_pos#long> "The WGS84 longitude of a SpatialThing (decimal degrees)."  
    s@(<http://www.w3.org/2003/01/geo/wgs84_pos#(lat|long)>)( "[^"]+")( \.)@\1\3^^<http://www.w3.org/2001/XMLSchema#decimal>\4@;
' > "${import_ttl_normalized}"

  # check for decimal numbers to round
  echo -en "# \e[32m      check for geographic digits at 5 digits (about 1m accuracy) ...\e[0m"
  
  this_files_long_decimal_numbers=""
  this_files_long_decimal_numbers=` grep --max-count=1 --only-matching --files-with-matches --extended-regexp "(decimal(Latitude|Longitude)>|wgs84_pos#(lat|long)>) \"-?[0-9]+\.[0-9]{6,}\"" "${import_ttl_normalized}"`
  
  if ! [[ -z ${this_files_long_decimal_numbers//[\t ]/} ]];then
  echo -en "# \e[32mproceed and round numbers ...\e[0m\n"
    grep --max-count=1 --only-matching --files-with-matches --extended-regexp "(decimal(Latitude|Longitude)>|wgs84_pos#(lat|long)>) \"-?[0-9]+\.[0-9]{6,}\"" "${import_ttl_normalized}" \
    | while read this_filename ; do perl -i -pe '
    s/(?<=decimalLatitude> ")-?[0-9]+\.[0-9]{6,}(?=")/sprintf("%.5f",$&)/ge; 
    s/(?<=decimalLongitude> ")-?[0-9]+\.[0-9]{6,}(?=")/sprintf("%.5f",$&)/ge; 
    s/(?<=wgs84_pos#lat> ")-?[0-9]+\.[0-9]{6,}(?=")/sprintf("%.5f",$&)/ge; 
    s/(?<=wgs84_pos#long> ")-?[0-9]+\.[0-9]{6,}(?=")/sprintf("%.5f",$&)/ge;' \
    "$this_filename"; done
  else
  echo -en "# \e[32mno number match found\e[0m\n"  
  fi

# plus trig format
  echo -e  "# \e[32m(3)   create formatted TriG                  ${import_ttl_normalized}.trig ...\e[0m" ;
  $apache_jena_bin/turtle --validate "${import_ttl_normalized}" > "${log_turtle2trig_warnEtError}" 2>&1
  $apache_jena_bin/turtle --quiet --output=trig --formatted=trig "${import_ttl_normalized}" > "${import_ttl_normalized}.trig"

  echo -e  "# \e[32m(4)   add/check ROR ID (... bak.jacq.org, brnu.jacq.org aso.)\e[0m" ;
  sed --regexp-extended --in-place '
### JACQ Begin
  # URL:bak.jacq.org=ROR:https://ror.org/006m4q736
  # URL:brnu.jacq.org=ROR:https://ror.org/02j46qs45
  # URL:ere.jacq.org=ROR:https://ror.org/05mpgew40
  # URL:gat.jacq.org=ROR:https://ror.org/02skbsp27
  # URL:gjo.jacq.org=ROR:https://ror.org/00nxtmb68
  # URL:gzu.jacq.org=ROR:https://ror.org/01faaaf77
  # URL:hal.jacq.org=ROR:https://ror.org/05gqaka33
  # URL:je.jacq.org=ROR:https://ror.org/05qpz1x62
  # URL:lagu.jacq.org/object=ROR:https://ror.org/01j60ss54
  #   URL:lz.jacq.org=ROR:https://ror.org/03s7gtk40
  #   URL:mjg.jacq.org=ROR:https://ror.org/023b0x485
  #   URL:piagr.jacq.org=ROR:https://ror.org/03ad39j10
  # URL:pi.jacq.org=ROR:https://ror.org/03ad39j10
  # URL:prc.jacq.org=ROR:https://ror.org/024d6js02
  # URL:tbi.jacq.org/object=ROR:https://ror.org/051qn8h41
  # URL:tgu.jacq.org=ROR:https://ror.org/02drrjp49
  # URL:tub.jacq.org=ROR:https://ror.org/03a1kwz48
  # URL:w.jacq.org=ROR:https://ror.org/01tv5y993
  # URL:wu.jacq.org=ROR:https://ror.org/03prydq77

# ## ROR_OR_INSTITUTION of admont.jacq.org --- http://viaf.org/viaf/128466393
/^<https?:\/\/admont.jacq.org\/[^<>/]+>/ {
  :label_uri-entry_admont.jacq.org
   N                                     # append lines via \n into patternspace
  / \.$/!b label_uri-entry_admont.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/128466393>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/128466393>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  http://viaf.org/viaf/128466393 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://admont.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION admont.jacq.org
# ## ROR_OR_INSTITUTION of bak.jacq.org --- https://ror.org/006m4q736
 /^<https?:\/\/bak.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_bak.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_bak.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/006m4q736>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/006m4q736>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/006m4q736 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://bak.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION bak.jacq.org
# ## ROR_OR_INSTITUTION of boz.jacq.org --- http://viaf.org/viaf/128699910
/^<https?:\/\/boz.jacq.org\/[^<>/]+>/ {
  :label_uri-entry_boz.jacq.org
  N                                     # append lines via \n into patternspace
  / \.$/!b label_uri-entry_boz.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/128699910>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/128699910>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  http://viaf.org/viaf/128699910 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://boz.jacq.org>\1@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION boz.jacq.org
# ## ROR_OR_INSTITUTION of brnu.jacq.org --- https://ror.org/02j46qs45
 /^<https?:\/\/brnu.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_brnu.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_brnu.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02j46qs45>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02j46qs45>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/02j46qs45 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://brnu.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION brnu.jacq.org
# ## ROR_OR_INSTITUTION of dr.jacq.org --- http://viaf.org/viaf/155418159
/^<https?:\/\/dr.jacq.org\/[^<>/]+>/ {
  :label_uri-entry_dr.jacq.org
  N                                     # append lines via \n into patternspace
  / \.$/!b label_uri-entry_dr.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/155418159>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/155418159>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  http://viaf.org/viaf/155418159 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://dr.jacq.org>\1@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION dr.jacq.org
# ## ROR_OR_INSTITUTION of ere.jacq.org --- https://ror.org/05mpgew40
 /^<https?:\/\/ere.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_ere.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_ere.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05mpgew40>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05mpgew40>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/05mpgew40 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://ere.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION ere.jacq.org
# ## ROR_OR_INSTITUTION of gat.jacq.org --- https://ror.org/02skbsp27
 /^<https?:\/\/gat.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_gat.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_gat.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02skbsp27>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02skbsp27>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/02skbsp27 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gat.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION gat.jacq.org
# ## ROR_OR_INSTITUTION of gjo.jacq.org --- https://ror.org/00nxtmb68
 /^<https?:\/\/gjo.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_gjo.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_gjo.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00nxtmb68>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00nxtmb68>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/00nxtmb68 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gjo.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION gjo.jacq.org
# ## ROR_OR_INSTITUTION of gzu.jacq.org --- https://ror.org/01faaaf77
 /^<https?:\/\/gzu.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_gzu.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_gzu.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01faaaf77>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01faaaf77>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/01faaaf77 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gzu.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION gzu.jacq.org
# ## ROR_OR_INSTITUTION of hal.jacq.org --- https://ror.org/05gqaka33
 /^<https?:\/\/hal.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_hal.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_hal.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05gqaka33>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05gqaka33>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/05gqaka33 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://hal.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION hal.jacq.org
# ## ROR_OR_INSTITUTION of je.jacq.org --- https://ror.org/05qpz1x62
 /^<https?:\/\/je.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_je.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_je.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05qpz1x62>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05qpz1x62>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/05qpz1x62 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://je.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION je.jacq.org
# ## ROR_OR_INSTITUTION of kiel.jacq.org --- http://viaf.org/viaf/239180770
/^<https?:\/\/kiel.jacq.org\/[^<>/]+>/ {
  :label_uri-entry_kiel.jacq.org
  N                                     # append lines via \n into patternspace
  / \.$/!b label_uri-entry_kiel.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/239180770>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/239180770>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  http://viaf.org/viaf/239180770 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://kiel.jacq.org>\1@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION kiel.jacq.org
# ## ROR_OR_INSTITUTION of lagu.jacq.org/object --- https://ror.org/01j60ss54
 /^<https?:\/\/lagu.jacq.org\/object\/[^<>/]+>/ {
 :label_uri-entry_lagu.jacq.orgSLASHobject
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_lagu.jacq.orgSLASHobject # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01j60ss54>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01j60ss54>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/01j60ss54 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://lagu.jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv>\1@;
   s@(<http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv>\s+[;]\n +)(<.+)(<http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv> .)@\2\3@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION lagu.jacq.org/object
# ## ROR_OR_INSTITUTION of lz.jacq.org --- https://ror.org/03s7gtk40
 /^<https?:\/\/lz.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_lz.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_lz.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03s7gtk40>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03s7gtk40>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03s7gtk40 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://lz.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION lz.jacq.org
# ## ROR_OR_INSTITUTION of mjg.jacq.org --- https://ror.org/023b0x485
 /^<https?:\/\/mjg.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_mjg.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_mjg.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/023b0x485>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/023b0x485>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/023b0x485 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://mjg.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION mjg.jacq.org
# ## ROR_OR_INSTITUTION of piagr.jacq.org --- https://ror.org/03ad39j10
 /^<https?:\/\/piagr.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_piagr.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_piagr.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03ad39j10 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://piagr.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION piagr.jacq.org
# ## ROR_OR_INSTITUTION of pi.jacq.org --- https://ror.org/03ad39j10
 /^<https?:\/\/pi.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_pi.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_pi.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03ad39j10 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://pi.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION pi.jacq.org
# ## ROR_OR_INSTITUTION of prc.jacq.org --- https://ror.org/024d6js02
 /^<https?:\/\/prc.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_prc.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_prc.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/024d6js02>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/024d6js02>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/024d6js02 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://prc.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION prc.jacq.org
# ## ROR_OR_INSTITUTION of tbi.jacq.org/object --- https://ror.org/051qn8h41
 /^<https?:\/\/tbi.jacq.org\/object\/[^<>/]+>/ {
 :label_uri-entry_tbi.jacq.orgSLASHobject
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_tbi.jacq.orgSLASHobject # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/051qn8h41>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/051qn8h41>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/051qn8h41 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://tbi.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION tbi.jacq.org/object
# ## ROR_OR_INSTITUTION of tgu.jacq.org --- https://ror.org/02drrjp49
 /^<https?:\/\/tgu.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_tgu.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_tgu.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02drrjp49>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02drrjp49>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/02drrjp49 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://tgu.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION tgu.jacq.org
# ## ROR_OR_INSTITUTION of tub.jacq.org --- https://ror.org/03a1kwz48
 /^<https?:\/\/tub.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_tub.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_tub.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03a1kwz48>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03a1kwz48>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03a1kwz48 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://tub.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION tub.jacq.org
# ## ROR_OR_INSTITUTION of ubt.jacq.org --- http://viaf.org/viaf/142509930
/^<https?:\/\/ubt.jacq.org\/[^<>/]+>/ {
  :label_uri-entry_ubt.jacq.org
  N                                     # append lines via \n into patternspace
  / \.$/!b label_uri-entry_ubt.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/142509930>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <http://viaf.org/viaf/142509930>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  http://viaf.org/viaf/142509930 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://ubt.jacq.org>\1@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION ubt.jacq.org
# ## ROR_OR_INSTITUTION of willing.jacq.org --- http://www.willing-botanik.de
/^<https?:\/\/willing.jacq.org\/[^<>/]+>/ {
  :label_uri-entry_willing.jacq.org
  N                                     # append lines via \n into patternspace
  / \.$/!b label_uri-entry_willing.jacq.org # go back if last char is not a dot
  # skip adding ROR_OR_INSTITUTION ID, add publisher
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://willing.jacq.org>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/publisher>  <http://www.willing-botanik.de>\1@;
  s@(<http://purl.org/dc/terms/publisher>  <https://http://www.willing-botanik.de>\s+[;]\n +)(<.+)(<http://purl.org/dc/terms/publisher>  <http://www.willing-botanik.de> .)@\2\3@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION willing.jacq.org
# ## ROR_OR_INSTITUTION of w.jacq.org --- https://ror.org/01tv5y993
 /^<https?:\/\/w.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_w.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_w.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01tv5y993>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01tv5y993>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/01tv5y993 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://w.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION w.jacq.org
# ## ROR_OR_INSTITUTION of wu.jacq.org --- https://ror.org/03prydq77
#   https://wu.jacq.org/WU-MYC 
#   https://wu.jacq.org/WU 
 /^<https?:\/\/wu.jacq.org\/[^<>/]+>/ {
 :label_uri-entry_wu.jacq.org
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_wu.jacq.org # go back if last char is not a dot
  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03prydq77 .)@\1\2@; 
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://wu.jacq.org>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR_OR_INSTITUTION wu.jacq.org

## add dcterms:isPartOf for /data/rdf/  
/^<https?:\/\/[a-z]+.jacq.org\/data\/rdf\/[^<>/]+>/ {
  :label_uri-entry_xxx.jacq.orgSLASHdataSLASHrdfSLASH
  N;    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_xxx.jacq.orgSLASHdataSLASHrdfSLASH # loop back to label… if last char is anything but a dot
  s@(<https?)(://[a-z]+\.jacq.org/data/rdf/)(.+)(\s+[.])@\1\2\3 ;\n        <http://purl.org/dc/terms/isPartOf>  <http\2>\4@;
}
### JACQ End

# http://www.wikidata.org/entity/
/^<https?:\/\/www.wikidata.org\/entity\/[^<>/]+>/ {
  :label_uri-entry_www.wikidata.orSLASHentitySLASH
  N;    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_www.wikidata.orSLASHentitySLASH # loop back to label… if last char is anything but a dot
  s@(<https?)(://www.wikidata.org/entity/)(.+)(\s+[.])@\1\2\3 ;\n        <http://purl.org/dc/terms/isPartOf>  <http\2>\4@;
}

  '  "${import_ttl_normalized}.trig"

  if [[ $debug_mode -gt 0  ]];then
  echo -e    "# \e[32m(5)   keep and compress parsed file          ${import_ttl}.gz for backup ...\e[0m" ;
    gzip --force "${import_ttl}"
  echo -e    "# \e[32m(6)   keep and compress normalised file      ${import_ttl_normalized}.gz ...\e[0m" ;
    gzip  --force "${import_ttl_normalized}"
  else
  echo  -e   "# \e[32m(5)   remove parsed file ...\e[0m" ;
    rm "${import_ttl}"
  echo  -e   "# \e[32m(5)   remove normalised file ...\e[0m" ;
    rm "${import_ttl_normalized}"
  fi
  
  echo  -e   "# \e[32m(7)   keep and compress normalised trig file for import \e[0m${import_ttl_normalized}.trig.gz\e[32m ...\e[0m" ;
  gzip --force "${import_ttl_normalized}.trig"
  echo  -e   "# \e[32m      compress RDF source file ...\e[0m" ;
  gzip --force "${rdfFilePath}"

  # if [[ `stat --printf="%s" "${rdfFilePath##*/}"*.log ` -eq 0 ]];then
  if [[ `file  $log_rdfparse_warnEtError | awk --field-separator=': ' '{print $2}'` == 'empty' ]]; then
    echo -e  "# \e[32m(8)   no warnings or errors, remove empty rdfparse log   ...\e[0m" ;
    rm $log_rdfparse_warnEtError
  else
    echo -e  "# \e[31m(8)   warnings and errors in rdfparse log (gzip)         ${log_rdfparse_warnEtError}.gz ...\e[0m" ;
    gzip --force "${log_rdfparse_warnEtError}"
  fi
  if [[ `file  $log_turtle2trig_warnEtError | awk --field-separator=': ' '{print $2}'` == 'empty' ]]; then
    echo -e  "# \e[32m      no warnings or errors, remove empty trig log       ...\e[0m" ;
    rm $log_turtle2trig_warnEtError
  else
    echo -e  "# \e[31m      warnings and errors in converting to trig (gzip)   ${log_turtle2trig_warnEtError}.gz ...\e[0m" ;
    gzip --force "${log_turtle2trig_warnEtError}"
  fi
  if [[ `ls -lt "${rdfFilePath##*/}"*.log 2> /dev/null ` ]]; then
    echo -e  "# \e[31m      warnings and errors in other log files (gzip)      ${rdfFilePath##*/}*.log.gz ...\e[0m" ;
    gzip --force "${rdfFilePath##*/}"*.log
  fi

  # increase index
  i=$((i + 1 ))
done

echo  -e "\e[32m#----------------------------------------\e[0m"
echo  -e "# \e[32mDone \e[0m"

datetime_end=`date --rfc-3339 'seconds'` ;
echo -e $( date --date="$datetime_start" '+# \e[32mTime Started:\e[0m %Y-%m-%d %H:%M:%S%:z' )
echo -e $( date --date="$datetime_end"   '+# \e[32mTime Ended:\e[0m   %Y-%m-%d %H:%M:%S%:z' )

echo  -e "# \e[32mCheck compressed logs by, e.g. ...\e[0m"
echo  -e "# \e[32m   zgrep --color=always --ignore-case 'error\|warn' *modified*.log.gz\e[0m"
echo  -e "# \e[32m   zgrep --ignore-case 'error\|warn' *modified*.log.gz | sed --regexp-extended 's@file:///(.+)/(\./Thread)@\2@;s@^Thread-[^:]*:@@;'\e[0m"
echo  -e "# \e[32m   zcat *${file_search_pattern/%.gz/}*warn-or-error.log* | grep --color=always --ignore-case 'error\|warn' \e[0m"
if [[ `ls  *${file_search_pattern/%.gz/}*warn-or-error.log* 2> /dev/null | wc -l` -gt 0 ]];then
echo  -e "# \e[31m   `ls  *${file_search_pattern/%.gz/}*warn-or-error.log* 2> /dev/null | wc -l` log files found with warnings or errors\e[0m"
else
echo  -e "# \e[32m   No log files generated (i.e. it seems no errors, warnings)\e[0m"
fi
echo  -e "# \e[32mNow you can import the normalised *.trig or *.ttl files to Apache Jena\e[0m"
echo  -e "# \e[32m# # # # Modifications # # # # # # # # # #\e[0m"
echo  -e "# \e[32mAdded: \e[1;34mdcterms:conformsTo <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\e[32m\e[0m"
echo  -e "# \e[32mAdded some \e[1;34mdwcterms:institutionID <http://ror.org/…ID…>\e[32m\e[0m"
echo  -e "# \e[32mMaybe added \e[1;34mdcterms:isPartOf <http://www.wikidata.org/entity/>\e[32m \e[0m"
echo  -e "# \e[32mMaybe added \e[1;34mdcterms:hasPart  <http://www.wikidata.org/entity/>\e[32m \e[0m"
echo  -e "# \e[32mMaybe added \e[1;34mdcterms:isPartOf <http://viaf.org/viaf/>\e[32m \e[0m"
echo  -e "# \e[32mMaybe added \e[1;34mdcterms:hasPart  <http://viaf.org/viaf/>\e[32m \e[0m"
echo  -e "\e[32m#########################################\e[0m"
