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
echo -e  "# Originals are kept as:      \e[32m${file_search_pattern}.$bak.gz\e[0m ..." # final line break
echo -e  "# Read directory:  \e[32m${this_wd}\e[0m ..."
if [ ${n} -gt 0 ];then
echo -ne "# Do you want to process \e[32m${n}\e[0m files with search pattern: «\e[32m${file_search_pattern}\e[0m» ?\n# [\e[32myes\e[0m or \e[31mno\e[0m (default: no)]: \e[0m"
else 
echo -ne "# \e[0mBy using search pattern: «\e[32m${file_search_pattern}\e[0m» the number of processed files is \e[31m${n}\e[0m.\n# \e[31m(Stop) We stop here; please check or add the correct search pattern, directory and/or data.\e[0m\n";
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

echo "#   extract all <rdf:RDF …> to ${this_file%.*}_rdfRDF_headers_extracted.rdf ... " 
sed --regexp-extended --quiet '/<rdf:RDF/,/>/{ s@<rdf:RDF +@@; s@\bxmlns:@\n  xmlns:@g; s@>@@; /\n  xmlns:/!d; /^[\s\t\n]*$/d; p; }' "$this_file" | sort --unique \
  | sed --regexp-extended --quiet  '/^[\t ]+$/d;/^$/d;p;' \
  | sed "1i\<rdf:RDF
  \$a\>\n<\!-- these are all RDF-headers extracted from ${this_file} -->" > "${this_file%.*}_rdfRDF_headers_extracted.rdf"
  
  echo "#   fix xml head, rdf:RDF, illegal characters in URIs, '--' in comments etc.) ... " 
  sed --regexp-extended -i.$bak '
  0,/<!--/{N; s@(.+)(<\?xml[^>]+>)@\2\1@; };
  # move comments that may be there before first starting <?xml…>
  
  0,/<\?xml/!{s@(<\?xml[^>]+>)@<!-- xml replaced -->@}; 
  # replace all <?xml…> but the first
  
  0,/<rdf:RDF/!{ /<rdf:RDF/{:label_rdfRDF; N; /<rdf:RDF[^>]*>/!b label_rdfRDF; s@<rdf:RDF[^>]*>@<!-- rdf:RDF replaced -->@;} }
  # replace all <rdf:RDF…> but the first
  
  s@</rdf:RDF>@@; $ a\ </rdf:RDF>
  # replace all </rdf:RDF…> but append at the very last line
  
  /<!--.*[^<][^!]--[^>].*-->/ { # rdfparse Fatal Error:  (line 75 column 113): The string "--" is not permitted within comments.
      :label.uriminus_in_comment; s@\s(https?://.+)--([^>]* -->)@ \1%2D%2D\2@; tlabel.uriminus_in_comment;
    }
  # replace all double minus -- in comments 
  
  # fix some characters that should be encoded (see https://www.ietf.org/rfc/rfc3986.txt)
  /"https?:\/\/[^"]+[][ `\\]+[^"]*"/ { # replace characters that are not allowed in URL
      :label.urispace; s@"(https?://[^" ]+)\s@"\1%20@; tlabel.urispace;
      :label.uriaccentgrave; s@"(https?://[^"`]+)`@"\1%60@; tlabel.uriaccentgrave;
      :label.backslash; s@"(https?://[^"\\]+)\\@"\1%5C@; tlabel.backslash;
      :label.leftsquaredbracket; s@"(https?://[^"\[]+)\[@"\1%5B@; tlabel.leftsquaredbracket;
      :label.rightsquaredbracket; s@"(https?://[^"\[]+)\]@"\1%5D@; tlabel.rightsquaredbracket;
    }
  # add datatype to <dcterms:decimalLatitude> or <dcterms:decimalLatitude>
  s@(<)([[:alpha:]]+:)(decimalLongitude|decimalLatitude)(>)([^<>]*)(</\2\3>)@\1\2\3 rdf:datatype="http://www.w3.org/2001/XMLSchema#decimal"\4\5\6@g;

  # remove double http… (some JACQ had such data)
  s@(rdf:resource|rdf:about)="(https?://[^"]+)\2"@\1="\2"@
  s@<(dwc:materialSampleID)>(https?://[^<>]+)\2</\1>@<\1>\2</\1>@
  
  ' "$this_file" #
  gzip --verbose "$this_file.$bak"
  i=$((i + 1))
done
echo     "# Done. Original data are kept in ${file_search_pattern}.$bak.gz ..." # final line break
echo     "# Each RDF file is prepared for validation and could be imported from this point on." # final line break
echo     "# Check also if the RDF-head is equal to the extracted ones with ${this_file%.*}_rdfRDF_headers_extracted.rdf ..." # final line break
echo     "# You can use command pr to print the RDF headers side by side:" # final line break
for this_file in `ls $file_search_pattern | sort --version-sort`; do
echo     "#   f='${this_file}'; sed --quiet -r '/<rdf:RDF/,/>/{s@[ \t\s]+(xmlns:)@\n  \1@g; p}' \${f} | pr --page-width 140 --merge --omit-header \${f%.*}_rdfRDF_headers_extracted.rdf -" # final line break
done
