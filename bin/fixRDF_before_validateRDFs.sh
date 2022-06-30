#!/bin/bash
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

n=0


function file_search_pattern_default () {
  printf "Thread-[0-9][0-9]_*_%s-[0-9][0-9][0-9][0-9].rdf" $(date '+%Y%m%d')
}
export file_search_pattern_default

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
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo jobs to do, estimated end %ddays %Hh:%Mmin:%Ssec"`
    elif [[ $this_unixseconds_todo -ge $(( 60 * 60 * 24 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo jobs to do, estimated end %dday %Hh:%Mmin:%Ssec"`
    elif [[ $this_unixseconds_todo -ge $(( 60 * 60 * 1 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo jobs to do, estimated end %Hh:%Mmin:%Ssec"`
    elif [[ $this_unixseconds_todo -lt $(( 60 * 60 * 1 )) ]];then
      this_msg_estimated_sofar=`$this_command_timediff "@0" "@$this_unixseconds_todo" -f "Still $this_n_jobs_todo jobs to do, estimated end %Mmin:%Ssec"`
    fi
    
  fi
  #echo "from $this_n_jobs_all, $njobs_done_so_far; $this_msg_estimated_sofar"
  echo "$this_msg_estimated_sofar"
  # END estimate time to do 
}
export -f get_timediff_for_njobs_new 
get_timediff_for_njobs_new --test

function usage() { 
  echo    "################ Fix RDF before validateRDF.sh #####################"
  echo -e "# Clean up and fix each of previousely merged RDFs from a download" 1>&2; 
  echo -e "# stack to be each valid RDF files. The file’s search patterns and" 1>&2; 
  echo -e "# fixing etc. is considered in development stage, so checking its" 1>&2; 
  echo -e "# right functioning is still of essence." 1>&2; 
  echo    "# -----------------------------------------------------------------"
  echo -e "# Usage: \e[32m${0##*/}\e[0m [-s 'Thread*file-search-pattern*.rdf']" 1>&2; 
  echo    "#   -h  ...................................... show this help usage" 1>&2; 
  echo    "#   -p  ..... print only RDF header comparison (no file processing)" 1>&2; 
  echo -e "#   -s  \e[32m'Thread*file-search-pattern*.rdf'\e[0m .... optional specific search pattern" 1>&2; 
  echo -e "#       Note: better use quotes for pattern with asterisk '*pattern*'" 1>&2; 
  echo -e "#       and use a narrow search pattern that really matches the RDF \e[1msource files only\e[0m" 1>&2; 
  echo -e "#       (default: '\e[32m$(file_search_pattern_default)\e[0m')" 1>&2; 
  echo    "# -----------------------------------------------------------------"
  echo -e "# Eventually the processed files \e[32m…\e[34m_modified\e[32m.rdf\e[0m are get zip-ed to save space." 1>&2; 
  exit 1; 
}

function processinfo () {
if [[ $INSTRUCT_TO_PRINT_ONLY_RDF_COMPARISON -gt 0 ]];then
  echo     "################ Fix RDF before validateRDF.sh (print rdf header comparison) #####################"
  echo -e  "# Print only rdf header comparison"
  echo -e  "# Read directory:  \e[32m${this_wd}\e[0m ..."
  echo -e  "# Process for search pattern:  \e[32m$file_search_pattern\e[0m ..."
  if [[ ${n} -gt 0 ]];then
  echo -ne "# Do you want to print out rdf header comparison for \e[32m${n}\e[0m files with search pattern: «\e[32m${file_search_pattern}\e[0m» ?\n# [\e[32myes\e[0m or \e[31mno\e[0m (default: no)]: \e[0m"
  else 
  echo -ne "# \e[0mBy using search pattern: «\e[32m${file_search_pattern}\e[0m» the number of processed files is \e[31m${n}\e[0m.\n# \e[31m(Stop) We stop here; please check or add the correct search pattern, directory and/or data.\e[0m\n";
  exit 1;
  fi
else
  echo     "################ Fix RDF before validateRDF.sh #####################"
  echo -e  "# Working directory:             \e[32m${this_wd}\e[0m ..."
  echo -e  "# Files get processed as:        \e[32m…\e[34m_modified\e[32m.rdf\e[0m finally compressed to \e[32m*.rdf.gz\e[0m ..."
  echo -e  "# Original files are kept untouched and eventually compressed to: \e[32m*.rdf.gz\e[0m ..." # final line break
  echo -e  "# Do processing for search pattern: \e[32m$file_search_pattern\e[0m ..."
  if [[ ${n} -gt 0 ]];then
  echo -ne "# Do you want to process \e[32m${n}\e[0m files with above search pattern?\n# [\e[32myes\e[0m or \e[31mno\e[0m (default: no)]: \e[0m"
  else 
  echo -ne "# \e[0mBy using above search pattern the number of processed files is \e[31m${n}\e[0m.\n# \e[31m(Stop) We stop here; please check or add the correct search pattern, directory and/or data.\e[0m\n";
  exit 1;
  fi
fi
}


this_wd="$PWD"
cd "$this_pwd"

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
              echo -e "\e[33mOption Error:\e[0m option -s requires an argument, please specify e.g. \e[3m-s 'Thread*file-search-pattern*.rdf.gz'\e[0m or let it run without -s option (default: '\e[32m$(file_search_pattern_default)\e[0m')."; exit 1;
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
shift $((OPTIND-1))

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
printf "# \e[32mProcess %03d of %03d in \e[3m%s\e[32m …\e[0m\n" $i $n "${this_file##*/}";
  
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
    
    stat --printf="#    \e[32mRead out comperessd\e[0m \e[3m%n\e[0m (%s bytes) using \e[34mzcat\e[0m …" "${this_file}"; printf " > \e[3m%s\e[0m …\n" "${this_file_modified}";
    zcat "$this_file" > "$this_file_modified"
    
  else
    # assume text/xml
    if ! [[ "${this_file_mimetype}" == "text/xml" ]];then
      echo -e "#    \e[31mError:\e[0m Please fix wrong file type: $this_file_mimetype, we expects file type “text/xml” (skip to next step)";
      continue;
    else
    printf "#    \e[32mCopy anew\e[0m \e[3m%s\e[0m for processing …\n" "${this_file_modified}";
      cp --force "$this_file" "$this_file_modified"
      printf "#    \e[32mCompress source file\e[0m \e[3m%s\e[0m (to keep storage minimal)…\n#    " "${this_file}";
      gzip --verbose "$this_file"
    fi
  fi
  
  if ! [[ -e "${this_file_modified}" ]]; then
    echo -e "#    \e[31mError:\e[0m File not found to process: $this_file_modified (skip to next step)";
    continue;
  fi
  
  this_file_modified_mimetype=$(file --mime-type "${this_file_modified}" | sed -r 's@.*: ([^:]+)@\1@')
  if ! [[ "${this_file_modified_mimetype}" == "text/xml" ]];then
    echo -e "#    \e[31mError:\e[0m Please fix wrong file type: ${this_file_modified_mimetype}, we expects file type “text/xml” (skip to next step)";
    continue;
  fi

  echo -e "#    \e[32mExtract all\e[0m <rdf:RDF …> to \e[3m${this_file_headers_extracted}\e[0m ... " 

  # TODO check correct functioning
  sed --regexp-extended --quiet \
  '/<rdf:RDF/,/>/{ 
    s@<rdf:RDF +@@; 
    s@\bxmlns:@\n  xmlns:@g; 
    s@>@@; 
    /\n  xmlns:/!d; 
    /^[[:space:]\n]*$/d; 
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
    echo -e "#    \e[32mfix RDF \e[0m(separate DOCTYPE html) ... " 
    sed --regexp-extended --in-place '/<!DOCTYPE html/,/<\/html>/ {
      /<!DOCTYPE html/ {s@<!DOCTYPE html@\n&@; }
      /<\/html>/ {s@<\/html>@\n&\n<!-- DOCTYPE html replaced -->\n@; }
    }; ' "${this_file_modified}"
    echo -e "#    \e[32mfix RDF \e[0m(delete DOCTYPE html things) ... " 
    sed --regexp-extended --in-place ' /<!DOCTYPE html/,/<\/html>/{ /<\/html>/!d; s@</html>@<!-- DOCTYPE html replaced -->@; }  ' "${this_file_modified}" #
  fi

  n_of_illegal_iri_character_in_urls=`grep --ignore-case '"https\?://[^"]\+[ \^\`\\]\+[^"]*"' "${this_file_modified}" | wc -l`
  if [[ $n_of_illegal_iri_character_in_urls -gt 0 ]];then
    printf   "\e[32m#    fix \e[31millegal or bad IRI characters\e[32m in %s URLs within \"http...double quotes\"...\e[0m\n" $n_of_illegal_iri_character_in_urls;
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
 ' "${this_file_modified}"
  fi
  
  n_of_comments_with_double_minus=`grep --ignore-case '<!--.*[^<][^!]--[^>].*-->' "${this_file_modified}" | wc -l`
  if [[ $n_of_comments_with_double_minus -gt 0 ]];then
    printf   "\e[32m#    fix \e[31mcomments with double minus not permitted\e[32m in %s URLs ...\e[0m\n" $n_of_comments_with_double_minus;
    sed --regexp-extended --in-place '
    /<!--.*[^<][^!]--[^>].*-->/ {# rdfparse Fatal Error:  (line 75 column 113): The string "--" is not permitted within comments.
      :label.uri_doubleminus_in_comment; s@[[:space:]](https?://.+)--([^>]* -->)@ \1%2D%2D\2@; tlabel.uri_doubleminus_in_comment; # if (s)ubstitution successful (t)ested, go back to label cycle
    }
 ' "${this_file_modified}"
  fi

  if [[ $(grep --max-count=1 'rdf:resource="[^"]\+$' "${this_file_modified}" ) ]];then
    printf   "\e[32m#    fix \e[31mline break in IRI\e[32m within «\e[3mrdf:resource=\"http...line break\"\e[32m ...\n\e[0m";
    sed --regexp-extended --in-place '/rdf:resource="[^"]+$/,/"/{N; s@[[:space:]]*\n[[:space:]]*@@; }' "${this_file_modified}"
  fi
  

  echo -e "#    \e[32mfix common errors \e[0m(also check or fix decimalLatitude decimalLongitude data type) ... " 
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
  
  echo -e "#    \e[32mfix RDF \e[0m(tag ranges: XML-head; XML-stylesheet; DOCTYPE rdf:RDF aso.) ... " 
  sed --regexp-extended --in-place '
  s@</rdf:RDF> *<\?xml[^>]+\?>@<!-- rdf-closing and xml replaced -->@;
  
  0,/<\?xml/{
    /<!--/,/<\?xml/{
     N; s@(<!--.+-->\n?)(<\?xml[[:space:]\n][^>]+\?>)@\2\1@; 
    }
  };
  # move comments that may be there before first starting <?xml…>
  
  /<!DOCTYPE rdf:RDF/,/\[/ {     
      :label_DOCTYPE; N;   /<!DOCTYPE rdf:RDF.+\]>/!b label_DOCTYPE;  
      s@(<!DOCTYPE rdf:RDF.+\]>)@<!-- DOCTYPE rdf:RDF REPLACED -->@
  }
  # replace all DOCTYPE rdf
  
  0,/<rdf:RDF/!{
    /<rdf:RDF/,/>/ { # Note: it can have newline <rdf:RDF[\n or [:space:]+] …>
      :label_rdfRDF_in_multiline; N;  /<rdf:RDF[^>]+[^]]>/!b label_rdfRDF_in_multiline;
      s@<rdf:RDF[^>]+[^]]>@<!-- rdf:RDF REPLACED -->@g;
    }
  }
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
  ' "${this_file_modified}" #
  i=$((i + 1))
done


echo "# -----------------------"
if [[ $(echo "$file_search_pattern" | grep ".\bgz$") ]]; then
echo -e  "# \e[32mDone. Original data are kept in \e[0m${file_search_pattern}\e[32m ...\e[0m" # final line break
else
echo -e  "# \e[32mDone. Original data are kept in \e[0m${file_search_pattern}.gz\e[32m ...\e[0m" # final line break
fi

echo -e  "# \e[32mEach RDF file should be prepared for validation and could then be imported from this point on.\e[0m" # final line break
echo -e  "# \e[32mCheck also if the RDF-head is equal to the extracted ones, e.g. in \e[0m${this_file_headers_extracted}\e[32m ...\e[0m" # final line break
echo -e  "# \e[32mYou can use command pr to print the RDF headers side by side:\e[0m" # final line break
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
  exclamation='!';

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
  printf  "# \e[32mCompare RDF headers %03d of %03d based on \e[3m%s\e[0m …\e[0m\n" $i $n "${this_file##*/}";
  echo -e "# ----------------------- ";

  echo    "# -----------------------" >> $logfile_rdf_headers;
  printf  "# Compare RDF headers %03d of %03d based on %s …\n" $i $n "${this_file##*/}" >> $logfile_rdf_headers;
  echo    "# -----------------------" >> $logfile_rdf_headers;
  i=$((i + 1))
  
  if ! [[ -e "$this_file_headers_extracted" ]]; then
    echo -e "#    \e[31mError:\e[0m \e[3m${this_file_headers_extracted}\e[0m not found (skipping) …"
    continue;
  fi
  
  if ! [[ -e "$this_file_modified" ]]; then
    if ! [[ -e "${this_file_modified}.gz" ]]; then 
    echo -e "#    \e[31mError:\e[0m \e[3m${this_file_modified}\e[0m or \e[3m${this_file_modified}.gz\e[0m not found (skipping) …"
    echo -e "#    Error: ${this_file_modified} or ${this_file_modified}.gz not found (skipping) …"  >> $logfile_rdf_headers
    continue;
    fi
  fi
  
  echo -e "# \e[32mFor checking unzippd modified files\e[0m …"
  echo -e "# For checking unzippd modified files …" >> $logfile_rdf_headers
  echo -e "  \e[34msed\e[0m --quiet --regexp-extended \e[33m'/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/${exclamation}b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\\\n  \1@g; s@\\\n\\\n@\\\n@g; p;
  }'\e[0m '${this_file_modified}' \\
  | \e[34mpr\e[0m --page-width 140 --merge --omit-header \\
  '${this_file_headers_extracted}' -"; # final line break
  
  echo -e "  sed --quiet --regexp-extended '/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/${exclamation}b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\\\n  \1@g; s@\\\n\\\n@\\\n@g; p;
  }' '${this_file_modified}' \\
  | pr --page-width 140 --merge --omit-header \\
  '${this_file_headers_extracted}' -" >> $logfile_rdf_headers  ; # final line break

  echo -e "# \e[32mFor checking zipped modified files\e[0m …"
  echo -e "# For checking zipped modified files …"  >> $logfile_rdf_headers
  echo -e "  \e[34mzcat\e[0m ${this_file_modified}.gz | \e[34msed\e[0m --quiet --regexp-extended \e[33m'/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/${exclamation}b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\\\n  \1@g; s@\\\n\\\n@\\\n@g; p;
  }'\e[0m \\
  | \e[34mpr\e[0m --page-width 140 --merge --omit-header \\
  '${this_file_headers_extracted}' -"; # final line break
  
  echo -e " zcat ${this_file_modified}.gz | sed --quiet --regexp-extended '/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/${exclamation}b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\\\n  \1@g; s@\\\n\\\n@\\\n@g; p;
  }' \\
  | pr --page-width 140 --merge --omit-header \\
  '${this_file_headers_extracted}' -" >> $logfile_rdf_headers  ; # final line break
  echo -e "# ----------------------- \e[32mLogged also into \e[3m$logfile_rdf_headers\e[0m …\e[0m";
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
      echo -e "# \e[32mInfo:\e[0m remove old $this_file_modified_gz and replace it …"
      rm "$this_file_modified_gz"
    fi
    printf "# File "; gzip --verbose "$this_file_modified"
  else
    echo -e "# \e[34mWarning:\e[0m expected $this_file_modified but it was not found (skipping)"
    continue
  fi
done

datetime_end=`date --rfc-3339 'seconds'` ;
echo $( date --date="$datetime_start" '+# Time Started: %Y-%m-%d %H:%M:%S%:z' )
echo $( date --date="$datetime_end"   '+# Time Ended:   %Y-%m-%d %H:%M:%S%:z' )

