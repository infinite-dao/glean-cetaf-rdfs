#!/bin/bash
# Usage: fix misstakes in RDF in files
#   fixRDF_before_validateRDFs.sh -h # get help; see also function usage()
# dependency: sed

# for this_file in `ls *coldb*get_2510001-2810000*.rdf | sort --version-sort`; do echo "# Insert </rdf:RDF> to $this_file"; echo '</rdf:RDF><!-- manually inserted 20200618 -->' >> "$this_file"; done
file_search_pattern="Thread-*data.biodiversitydata.nl*.rdf"
file_search_pattern="Test_sed*.rdf"
file_search_pattern="Threads_import_*_20201116.rdf"
file_search_pattern="Thread-*_jacq.org_20211108-1309.rdf"

bak="bak_"$(date '+%Y%m%d_%H%M')
n=0

function file_search_pattern_default () {
  file_search_pattern_default=`printf "Threads_import_*_%s.rdf" $(date '+%Y%m%d')`
}
file_search_pattern_default

function usage() { 
  echo -e "# Merge multiple RDFs from a download stack into one RDF" 1>&2; 
  echo -e "# Usage: \e[32m${0##*/}\e[0m [-s 'Thread*file-search-pattern*.rdf']" 1>&2; 
  echo    "#   -h  ...................................... show this help usage" 1>&2; 
  echo -e "#   -s  \e[32m'Thread*file-search-pattern*.rdf'\e[0m .... optional specific search pattern" 1>&2; 
  echo -e "#       Note: better use quotes for pattern with asterisk '*pattern*' (default: '${file_search_pattern_default}')" 1>&2; 
  exit 1; 
}

function processinfo () {
echo     "############ Fix RDF before validateRDF.sh #################"
echo -e  "# Process for search pattern: \e[32m$file_search_pattern\e[0m ..."
echo -e  "# Originals are kept as:      \e[32m${file_search_pattern}.$bak\e[0m ..." # final line break
echo -e  "# Read directory:  \e[32m${this_wd}\e[0m ..."
if [ ${n} -gt 0 ];then
echo -ne "# Do you want to process \e[32m${n}\e[0m files with search pattern: «\e[32m${file_search_pattern}\e[0m» ?\n# [\e[32myes\e[0m or \e[31mno\e[0m (default: no)]: \e[0m"
else 
echo -ne "# \e[0mBy using search pattern: «\e[32m${file_search_pattern}\e[0m» the number of processed files is \e[31m${n}\e[0m.\n# \e[31m(Stop) We stop here; please check the search pattern, directory and/or data.\e[0m\n";
exit 1;
fi

}


this_wd="$PWD"
cd "$this_pwd"

while getopts ":s:h" o; do
    case "${o}" in
        h)
            usage; exit 0;
            ;;
        s)
            file_search_pattern="${OPTARG}"
            if   [[ -z ${file_search_pattern// /} ]] ; then file_search_pattern_default; file_search_pattern="$file_search_pattern_default" ; fi
            ;;
        *)
            usage; exit 0;
            ;;
    esac
done
shift $((OPTIND-1))

# echo "# Options passed …"
# echo "find \"${this_wd}\" -maxdepth 1 -type f -iname \"${file_search_pattern##*/}\" | sort --version-sort | wc -l "

i=1; n=`find "${this_wd}" -maxdepth 1 -type f -iname "${file_search_pattern##*/}" | sort --version-sort | wc -l `
# echo "# find passed …"
# set (i)ndex and (n)umber of files alltogether

# echo     "############ Fix RDF before validateRDF.sh #################"
# echo     "# Process for search pattern: $file_search_pattern ..."
# echo     "# Originals are kept in ${file_search_pattern}.$bak ..." # final line break
# echo     "# Read directory:  ${this_wd} ..."
# echo -ne "# Do you want to process ${n} files with search pattern: «${file_search_pattern}» ?\n# [yes or no (default: no)]: "

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
echo "# Read passed …"

# check all RDFs

for this_file in `ls $file_search_pattern | sort --version-sort`; do
printf "# Process %03d of %03d in %s " $i $n "${this_file##*/}";
#   sed --regexp-extended  '0,/<rdf:RDF/!{ /<rdf:RDF/{:label_rdfRDF; N; /[^>]*>/!b label_rdfRDF; s@<rdf:RDF[^>]*>@<!-- rdf:RDF replaced -->@;} }' Test_sed.rdf # failed
#   sed --regexp-extended  '0,/<rdf:RDF/!{ /<rdf:RDF/N;s@<rdf:RDF[^>]*>@<!-- rdf:RDF replaced -->@}' Test_sed.rdf # failed because of prepended <!xml and not clear b pattt
#   sed --regexp-extended  '0,/<\?xml/!{s@(<\?xml[^>]+>)@@};' # OK
#   sed --regexp-extended  '0,/<rdf:RDF/!{ /<rdf:RDF/{:label_rdfRDF; N; /<rdf:RDF[^>]*>/!b label_rdfRDF; s@<rdf:RDF[^>]*>@<!-- rdf:RDF replaced -->@;} }' Test_sed.rdf # OK
#   sed --regexp-extended  '0,/<\?xml/!{s@(<\?xml[^>]+>)@@}; 0,/<rdf:RDF/!{ /<rdf:RDF/{:label_rdfRDF; N; /<rdf:RDF[^>]*>/!b label_rdfRDF; s@<rdf:RDF[^>]*>@<!-- rdf:RDF replaced -->@;} }' Test_sed.rdf # OK
#   sed --regexp-extended  '1 s@(.+)(<\?xml[^>]+>)@\2\1@;' Test_sed.rdf # 
#   sed --regexp-extended  '0,/<!--/{N; s@(.+)(<\?xml[^>]+>)@\2\1@; }' Test_sed.rdf # OK
#   sed --regexp-extended  '0,/<!--/{N; s@(.+)(<\?xml[^>]+>)@\2\1@; }; 0,/<\?xml/!{s@(<\?xml[^>]+>)@<!-- xml replaced -->@}; 0,/<rdf:RDF/!{ /<rdf:RDF/{:label_rdfRDF; N; /<rdf:RDF[^>]*>/!b label_rdfRDF; s@<rdf:RDF[^>]*>@<!-- rdf:RDF replaced -->@;} }' Test_sed.rdf #
#   sed --regexp-extended  '/"https?:\/\/[^"]+\s+[^"]*"/ { :label_url_with_space; s@"(https?://[^" ]+)\s@"\1%20@; tlabel_url_with_space; }' Test_sed.rdf # 
#### get RDF head
#   sed -n '/<rdf:RDF/,/>/{ s@\bxmlns:@\nxmlns:@g; /\nxmlns:/!d; /^[\s\t\n]*$/d; p; }' Thread-1_data.nhm.ac.uk_20201111-1335.rdf | sort --unique | sed '1i\<rdf:RDF 
# $a\ >'

echo "#   extract all <rdf:RDF …> to ${this_file%.*}_rdfRDF_head.rdf ... " 
  sed --regexp-extended --quiet '/<rdf:RDF/,/>/{ s@<rdf:RDF +@@; s@\bxmlns:@\nxmlns:@g; /\nxmlns:/!d; /^[\s\t\n]*$/d; p; }' "$this_file" | sort --unique \
  | sed --regexp-extended --quiet  '/^[\t ]+$/d;/^$/d;p;' \
  | sed '1i\<rdf:RDF 
$a\ >' > "${this_file%.*}_rdfRDF_head.rdf"
  
  echo "#   fix xml head, rdf:RDF, illegal characters in URIs, '--' in comments etc.) ... " 
  sed --regexp-extended -i.$bak '
  0,/<!--/{N; s@(.+)(<\?xml[^>]+>)@\2\1@; };
  # move comments after first starting <?xml…>
  
  0,/<\?xml/!{s@(<\?xml[^>]+>)@<!-- xml replaced -->@}; 
  # replace all <?xml…> but the first
  
  0,/<rdf:RDF/!{ /<rdf:RDF/{:label_rdfRDF; N; /<rdf:RDF[^>]*>/!b label_rdfRDF; s@<rdf:RDF[^>]*>@<!-- rdf:RDF replaced -->@;} }
  # replace all <rdf:RDF…> but the first
  
  s@</rdf:RDF>@@;$ a\ </rdf:RDF>
  # replace all </rdf:RDF…> but append at last
  
  /<!--.*[^<][^!]--[^>].*-->/ { # rdfparse Fatal Error:  (line 75 column 113): The string "--" is not permitted within comments.
      :label.uriminus_in_comment; s@\s(https?://.+)--([^>]* -->)@ \1%2D%2D\2@; tlabel.uriminus_in_comment;
    }
  # replace all double minus -- in comments 
  
  /"https?:\/\/[^"]+[ `\\]+[^"]*"/ { # replace characters that are not allowed in URL
      :label.urispace; s@"(https?://[^" ]+)\s@"\1%20@; tlabel.urispace;
      :label.uriaccentgrave; s@"(https?://[^"`]+)`@"\1%60@; tlabel.uriaccentgrave;
      :label.backslash; s@"(https?://[^"\\]+)\\@"\1%5C@; tlabel.backslash;
    }

  ' "$this_file" #
  i=$((i + 1))
#     echo "#   Fix $this_file ($n_URI_spaces URIs with spaces) ... " && sed --regexp-extended -i.bak ' /"https?:\/\/[^"]+\s+[^"]*"/ { :label_url_with_space; s@"(https?://[^" ]+)\s@"\1%20@; tlabel_url_with_space; } ' "$this_file"
done

echo     "# Done." # final line break
echo     "# Check also <rdf:RDF…> in ${file_search_pattern%.*}_rdfRDF_head.rdf ..." # final line break
echo     "# Originals are kept in ${file_search_pattern}.$bak ..." # final line break
