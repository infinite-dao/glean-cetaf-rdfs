#!/bin/bash
# filename convertRDF4import_normalise-files.sh
###########################
# Description: Use RDF and convert to ...
# => n-tuples (rdfparse), normalise, remove empty, fix standard URIs (wikidata etc)
# => trig format (turtle)
# => compression
# dependencies $apache_jena_bin, e.g. /home/aplank/apache-jena-3.14.0/bin programs: turtle rdfparse
# dependencies /home/aplank/apache-jena-3.14.0/bin/rdfparse
# dependencies gzip, sed, cat

# this will find all Thread-1_... Thread-2_... etc. files
# file_search_pattern="Thread*coldb.mnhn.fr*.rdf"
# file_search_pattern="Thread*tub.jacq.org*.rdf"
# file_search_pattern="Thread*herbarium.bgbm.org*.rdf"
# file_search_pattern="Thread*lagu.jacq.org*.rdf"
# file_search_pattern="Thread*.jacq.org*.rdf"
# file_search_pattern="Thread-*biodiversitydata.nl*.rdf"
# file_search_pattern="test-space-in-URIs.rdf"
debug_mode=0

apache_jena_bin=$([ -d ~/"Programme/apache-jena-4.2.0/bin" ] && echo ~/"Programme/apache-jena-4.2.0/bin" || echo ~/"apache-jena-4.2.0/bin" )
# apache_jena_bin=$([ -d ~/"Programme/apache-jena-4.1.0/bin" ] && echo ~/"Programme/apache-jena-4.1.0/bin" || echo ~/"apache-jena-4.1.0/bin" )

if ! [ -d "${apache_jena_bin}" ];then
  echo -e "# \e[33m${apache_jena_bin}\e[0m does not exists to run rdfxml with!"
  echo    "# Download it from jena.apache.org and set path in \$apache_jena_bin accordingly."
  echo    "# (stop)"
  exit 1;
fi

function file_search_pattern_default () {
  file_search_pattern_default=`printf "Threads_import_*_%s.rdf" $(date '+%Y%m%d')`
}
file_search_pattern_default

function usage() {
  echo -e "# Convert RDF into TriG format (*.trig) format " 1>&2;
  echo -e "# Usage: \e[32m${0##*/}\e[0m [-s 'Thread*file-search-pattern*.rdf']" 1>&2;
  echo    "#   -h  ...................................... show this help usage" 1>&2;
  echo -e "#   -s  \e[32m'Thread*file-search-pattern*.rdf'\e[0m .... optional specific search pattern" 1>&2;
  echo -e "#       Note: better use quotes for pattern with asterisk '*pattern*' (default: '${file_search_pattern_default}')" 1>&2;
  exit 1;
}


function processinfo () {
# # # #
if [[ $debug_mode -gt 0  ]];then
echo -e  "############  Parse RDF (\e[31mdebug mode\e[0m) ####"
else
echo -e  "############  Parse RDF #################"
fi

echo -e  "# To check RDF use \e[32mvalidateRDF.sh\e[0m"
echo -e  "# Now ..."
echo -e  "# * we parse RDF, convert to n-tuples, remove empty fields, normalise content (some https -> http etc.)"
if [[ $debug_mode -gt 0  ]];then
echo -e  "# * in debug mode, we \e[31mkeep all files\e[0m from in between (*_rdfparse.ttl, *_normalized.ttl etc.)"
else
echo -e  "# * we convert all modified data into TriG format (*.trig) and \e[31mclean up all files\e[0m from in between (*_rdfparse.ttl, *_normalized.ttl etc.)"
fi
echo -e  "# * we compress the files with gzip to *.gz"
echo -e  "# * we remove empty log files (only *.log with content is kept)"
echo -e  "# * \e[33mmake sure to add ROR-ID as dwc:institutionID in this script\e[0m"
echo -e  "# Reading directory: \e[32m${this_pwd}\e[0m ..."
echo -ne "# Do you want to parse \e[32m${n}\e[0m files with search pattern: «\e[32m${file_search_pattern}\e[0m» ?\n"
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

while getopts ":s:h" o; do
    case "${o}" in
        h)
            usage; exit 0;
            ;;
        s)
            file_search_pattern=${OPTARG}
            if   [[ -z ${file_search_pattern// /} ]] ; then file_search_pattern_default; file_search_pattern="$file_search_pattern_default" ; fi
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))


i=1; 
n=`find . -maxdepth 1 -type f -iname "${file_search_pattern}" | wc -l `
n_parsed=`find . -maxdepth 1 -type f -iname "${file_search_pattern}*.ttl*" -or -iname "${file_search_pattern}*.log*" | wc -l `
# set (i)ndex and (n)umber of files alltogether

# if [[ $debug_mode -gt 0  ]];then
# echo -e  "\e[32m############  Parse RDF (\e[31mdebug mode\e[35m) ####\e[0m"
# else
# echo -e  "\e[32m############  Parse RDF #################\e[0m"
# fi
#
# echo -e  "\e[32m# To check RDF use validateRDF.sh\e[0m"
# echo -e  "\e[32m# Now ...\e[0m"
# echo -e  "\e[32m# * we parse RDF, convert to n-tuples, remove empty fields, normalise content (some https -> http etc.)\e[0m"
# if [[ $debug_mode -gt 0  ]];then
# echo -e  "\e[32m# * in debug mode, we \e[31mkeep all files\e[32m from in between (*_rdfparse.ttl, *_normalized.ttl etc.)\e[0m"
# else
# echo -e  "\e[32m# * we convert all modified data into TriG format (*.trig) and \e[31mclean up all files\e[32m from in between (*_rdfparse.ttl, *_normalized.ttl etc.)\e[0m"
# fi
# echo -e  "\e[32m# * we compress the files with gzip to *.gz\e[0m"
# echo -e  "\e[32m# * we remove empty log files (only *.log with content is kept)\e[0m"
# echo -e  "\e[32m# Reading directory: ${this_pwd} ...\e[0m"
# echo -ne "\e[32m# Do you want to parse ${n} files with search pattern: «${file_search_pattern}» ?\n# [yes or no (default: no)]: \e[0m"



processinfo
read yno
case $yno in
  [yYjJ]|[yY][Ee][Ss]|[jJ][aA])
echo -e "\e[32m# Continue ...\e[0m"
  ;;
  [nN]|[nN][oO]|[nN][eE][iI][nN])
echo -e "\e[31m# Stop\e[0m";
    exit 1
  ;;
  *)
echo -e "\e[31m# Invalid or no input (stop)\e[0m"
    exit 1
  ;;
esac

for rdfFilePath in `find . -maxdepth 1 -type f -iname "${file_search_pattern}" | sort --version-sort`; do
# loop through each file
  import_ttl="${rdfFilePath}_rdfparse.ttl"
  import_ttl_normalized="${rdfFilePath}._normalized.ttl"
  log_rdfparse_warnEtError="${rdfFilePath}_rdfparse-warn-or-error.log"
  log_turtle2trig_warnEtError="${rdfFilePath}_turtle2trig-warn-or-error.log"
  echo "#-----------------------------" ;
# parse
  #   sed --regexp-extended  '  /"https?:\/\/[^"]+[ `]+[^"]*"/ {:label.urispace; s@"(https?://[^" ]+)\s@"\1%20@; tlabel.urispace; :label.uriaccentgrave; s@"(https?://[^"`]+)`@"\1%60@; tlabel.uriaccentgrave; } ' test-space-in-URIs.rdf > test-space-in-URIs_replaced.rdf

  n_of_illegal_iri_character_in_urls=`grep -i '"https\?://[^"]\+[ \`\\]\+[^"]*"\|<!--.*[^<][^!]--[^>].*-->' "${rdfFilePath}" | wc -l`
  if [[ $n_of_illegal_iri_character_in_urls -gt 0 ]];then
  printf   '\e[31m# (0) Fix illegal IRI characters in %s URLs (keep original RDF in %s.bak)...\n\e[0m' $n_of_illegal_iri_character_in_urls "${rdfFilePath}";
    sed --regexp-extended -i.bak '
    /<!--.*[^<][^!]--[^>].*-->/ {# rdfparse Fatal Error:  (line 75 column 113): The string "--" is not permitted within comments.
      :label.uri_doubleminus_in_comment; s@\s(https?://.+)--([^>]* -->)@ \1%2D%2D\2@; tlabel.uri_doubleminus_in_comment; # if (s)ubstitution successful (t)ested, go back to label cycle
    }
      # fix some characters that should be encoded (see https://www.ietf.org/rfc/rfc3986.txt)
  /"https?:\/\/[^"]+[][ `\\]+[^"]*"/ { # replace characters that are not allowed in URL
      :label.urispace; s@"(https?://[^" ]+)\s@"\1%20@; tlabel.urispace;
      :label.uriaccentgrave; s@"(https?://[^"`]+)`@"\1%60@; tlabel.uriaccentgrave;
      :label.backslash; s@"(https?://[^"\\]+)\\@"\1%5C@; tlabel.backslash;
      :label.leftsquaredbracket; s@"(https?://[^"\[]+)\[@"\1%5B@; tlabel.leftsquaredbracket;
      :label.rightsquaredbracket; s@"(https?://[^"\[]+)\]@"\1%5D@; tlabel.rightsquaredbracket;
    }
 ' "${rdfFilePath}"
  fi

  printf   "\e[32m# (1) Parse (%04d of %04d) to %s (turtle format: simple N-triple statements) ...\n\e[0m"  $i $n "${import_ttl}" ;
  $apache_jena_bin/rdfparse -R "${rdfFilePath}" > "${import_ttl}" 2> "${log_rdfparse_warnEtError}"

# normalise
  echo -e  "\e[32m# (2)   normalise N-triples into      ${import_ttl_normalized} ...\e[0m"
  cat "${import_ttl}" | sed --regexp-extended  '
  /> "" \. *$/d; # delete empty value lines
  # do substitutions
  s@<https?:(//www.wikidata.org|//m.wikidata.org)/(wiki|entity)/(Q[^"/]+)@<http://www.wikidata.org/entity/\3@g; # we need /entity not /wiki
  s@<https:(//www.ipni.org)@<http:\1@g;
  s@<https:(//purl.oclc.org)@<http:\1@g;
  s@<https:(//isni.org/isni/)@<http:\1@g;
  s@<https?://www.w3.org/2002/07/owl/@<http://www.w3.org/2002/07/owl#@g;
  s@<https?:(//viaf.org/viaf/[0-9]+)[/#<>]*[^"<>]*>@<http:\1>@g;
  # add datatype to <dcterms:decimalLatitude> or <dcterms:decimalLatitude>
  # <http://lagu.jacq.org/object/AA-00001> <http://rs.tdwg.org/dwc/terms/decimalLongitude> "-88.98333" .
  # <http://lagu.jacq.org/object/AA-00001> <http://rs.tdwg.org/dwc/terms/decimalLatitude> "13.5"^^<http://www.w3.org/2001/XMLSchema#decimal> .
  s@(<http://rs.tdwg.org/dwc/terms/(decimalLongitude|decimalLatitude)>)( "[^"]*")( \.)@\1\3^^<http://www.w3.org/2001/XMLSchema#decimal>\4@;
' > "${import_ttl_normalized}"
# plus trig format
  echo -e  "\e[32m# (3)   create trig format            ${import_ttl_normalized}.trig ...\e[0m" ;
  $apache_jena_bin/turtle --validate "${import_ttl_normalized}" > "${log_turtle2trig_warnEtError}"
  $apache_jena_bin/turtle --quiet --output=trig "${import_ttl_normalized}" > "${import_ttl_normalized}.trig"

  echo -e  "\e[32m# (4)   add/check ROR ID              ${import_ttl_normalized}.trig ... (bgbm.org, biodiversitydata.nl, botanicalcollections.be, coldb.mnhn.fr, rbge.org.uk etc.)\e[0m" ;
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
  # URL:lz.jacq.org=ROR:https://ror.org/03s7gtk40
  # URL:mjg.jacq.org=ROR:https://ror.org/023b0x485
  # URL:piagr.jacq.org=ROR:https://ror.org/03ad39j10
  # URL:pi.jacq.org=ROR:https://ror.org/03ad39j10
  # URL:prc.jacq.org=ROR:https://ror.org/024d6js02
  # URL:tbi.jacq.org/object=ROR:https://ror.org/051qn8h41
  # URL:tgu.jacq.org=ROR:https://ror.org/02drrjp49
  # URL:tub.jacq.org=ROR:https://ror.org/03a1kwz48
  # URL:w.jacq.org=ROR:https://ror.org/01tv5y993
  # URL:wu.jacq.org=ROR:https://ror.org/03prydq77
  
/^<https?:\/\/(bak|brnu|ere|gat|gjo|gzu|hal|je|lz|mjg|piagr|pi|prc|tgu|tub|w|wu).jacq.org\/[^<>/]+>/ {
  :label_uri-entry_xxx.jacq.orgSLASHno_object
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_xxx.jacq.orgSLASHno_object # loop back to label… if last char is anything but a dot
  # bak.jacq.org --- ROR-ID https://ror.org/006m4q736
  /^<https?:\/\/bak.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/006m4q736>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/006m4q736>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/006m4q736> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://bak.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # brnu.jacq.org --- ROR-ID https://ror.org/02j46qs45
  /^<https?:\/\/brnu.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02j46qs45>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02j46qs45>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02j46qs45> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://brnu.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # ere.jacq.org --- ROR-ID https://ror.org/05mpgew40
  /^<https?:\/\/ere.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05mpgew40>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05mpgew40>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05mpgew40> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://ere.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # gat.jacq.org --- ROR-ID https://ror.org/02skbsp27
  /^<https?:\/\/gat.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02skbsp27>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02skbsp27>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02skbsp27> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gat.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # gjo.jacq.org --- ROR-ID https://ror.org/00nxtmb68
  /^<https?:\/\/gjo.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00nxtmb68>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00nxtmb68>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00nxtmb68> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gjo.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # gzu.jacq.org --- ROR-ID https://ror.org/01faaaf77
  /^<https?:\/\/gzu.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01faaaf77>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01faaaf77>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01faaaf77> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gzu.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # hal.jacq.org --- ROR-ID https://ror.org/05gqaka33
  /^<https?:\/\/hal.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05gqaka33>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05gqaka33>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05gqaka33> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://hal.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # je.jacq.org --- ROR-ID https://ror.org/05qpz1x62
  /^<https?:\/\/je.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05qpz1x62>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05qpz1x62>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05qpz1x62> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://je.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # lz.jacq.org --- ROR-ID https://ror.org/03s7gtk40
  /^<https?:\/\/lz.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03s7gtk40>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03s7gtk40>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03s7gtk40> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://lz.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # mjg.jacq.org --- ROR-ID https://ror.org/023b0x485
  /^<https?:\/\/mjg.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/023b0x485>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/023b0x485>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/023b0x485> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://mjg.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # piagr.jacq.org --- ROR-ID https://ror.org/03ad39j10
  /^<https?:\/\/piagr.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://piagr.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # pi.jacq.org --- ROR-ID https://ror.org/03ad39j10
  /^<https?:\/\/pi.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://pi.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # prc.jacq.org --- ROR-ID https://ror.org/024d6js02
  /^<https?:\/\/prc.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/024d6js02>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/024d6js02>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/024d6js02> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://www.jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://www.prc.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # tgu.jacq.org --- ROR-ID https://ror.org/02drrjp49
  /^<https?:\/\/tgu.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02drrjp49>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02drrjp49>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02drrjp49> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://tgu.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # tub.jacq.org --- ROR-ID https://ror.org/03a1kwz48
  /^<https?:\/\/tub.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03a1kwz48>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03a1kwz48>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03a1kwz48> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://tub.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # w.jacq.org --- ROR-ID https://ror.org/01tv5y993
  /^<https?:\/\/w.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01tv5y993>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01tv5y993>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01tv5y993> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://w.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # wu.jacq.org --- ROR-ID https://ror.org/03prydq77
  /^<https?:\/\/wu.jacq.org\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://wu.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
} # JACQ without object

/^<https?:\/\/(lagu|tbi).jacq.org\/object\/[^<>/]+>/ {
  :label_uri-entry_xxx.jacq.orgSLASHwith_object
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_xxx.jacq.orgSLASHwith_object # loop back to label… if last char is anything but a dot
  # lagu.jacq.org/object --- ROR-ID https://ror.org/01j60ss54
  /^<https?:\/\/lagu.jacq.org\/object\//,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01j60ss54>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01j60ss54>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01j60ss54> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://lagu.jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv>\1@;
    s@(<http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv>\s+[;]\n +)(<.+)(<http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv> .)@\2\3@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
  # tbi.jacq.org/object --- ROR-ID https://ror.org/051qn8h41
  /^<https?:\/\/tbi.jacq.org\/object\//,/ .$/ {
    # add ROR ID eventually to the final dot, and remove possible duplicates
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/051qn8h41>\1@;
    s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/051qn8h41>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/051qn8h41> .)@\1\2@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://tbi.jacq.org>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  }
} # JACQ with object
  
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

# BGBM
# ROR of herbarium.bgbm.org/object/ --- https://ror.org/00bv4cx53
/^<https?:\/\/herbarium.bgbm.org\/object\// {
  :label_uri-entry_herbarium.bgbm.orgSLASHobjectSLASH
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_herbarium.bgbm.orgSLASHobjectSLASH # loop back to label… if last char is anything but a dot
  #/^<https?:\/\/herbarium.bgbm.org\/object\/[^<>/]+/,/ .$/ {
    # add ROR ID eventually to the final dot
    s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00bv4cx53>\1@;
    # remove duplicates
    s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00bv4cx53>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00bv4cx53> .)@\2\3@;

    # add publisher
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/publisher>  <https://www.bgbm.org>\1@;
    # remove duplicates
    s@(<http://purl.org/dc/terms/publisher>  <https://www.bgbm.org>\s+[;]\n +)(<.+)(<http://purl.org/dc/terms/publisher>  <https://www.bgbm.org> .)@\2\3@;
    # add isPartOf
    s@(\s+[.])@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://herbarium.bgbm.org/object/>\1@;
    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])?$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  #}
}
  
/^<https?:\/\/.*herbarium.bgbm.org\/data\/rdf\/[^<>/]+>/ {
  :label_uri-entry_xxx.herbarium.bgbm.orgSLASHdataSLASHrdfSLASH
  N;    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_xxx.herbarium.bgbm.orgSLASHdataSLASHrdfSLASH # loop back to label… if last char is anything but a dot
  s@(<https?)(://.*herbarium.bgbm.org/data/rdf/)(.+)(\s+[.])@\1\2\3 ;\n        <http://purl.org/dc/terms/isPartOf>  <http\2>\4@;
}


# ROR of data.biodiversitydata.nl/naturalis/specimen/ --- https://ror.org/0566bfb96
/^<https?:\/\/data.biodiversitydata.nl\/naturalis\/specimen\// {
  :label_uri-entry_data.biodiversitydata.nlSLASHnaturalisSLASHspecimenSLASH
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_data.biodiversitydata.nlSLASHnaturalisSLASHspecimenSLASH # loop back to label… if last char is anything but a dot

  # add ROR ID eventually to the final dot
  s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/0566bfb96>\1@;
  # remove duplicates
  s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/0566bfb96>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/0566bfb96> .)@\2\3@;
}

# ROR of specimens.kew.org/herbarium/ --- https://ror.org/00ynnr806
/^<https?:\/\/specimens.kew.org\/herbarium\// {
  :label_uri-entry_specimens.kew.orgSLASHherbariumSLASH
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_specimens.kew.orgSLASHherbariumSLASH # loop back to label… if last char is anything but a dot

  # add ROR ID eventually to the final dot
  s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00ynnr806>\1@;
  # remove duplicates
  s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00ynnr806>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00ynnr806> .)@\2\3@;
}

# ROR of www.botanicalcollections.be/specimen/ --- https://ror.org/01h1jbk91
# TODO isPartOf ? 
/^<https?:\/\/www.botanicalcollections.be\/specimen\// {
  :label_uri-entry_www.botanicalcollections.beSLASHspecimenSLASH
  N  # append lines via \n into patternspace
  /\.$/!b label_uri-entry_www.botanicalcollections.beSLASHspecimenSLASH # loop back to label… if last char is anything but a dot

  # add ROR-ID
  s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01h1jbk91>\1@;
  # remove duplicates
  s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01h1jbk91>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01h1jbk91> .)@\2\3@;
}

# ROR of coldb.mnhn.fr/catalognumber/mnhn/ --- https://ror.org/03wkt5x30
# TODO add isPartOf ? 
/^<https?:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\// {
  :label_uri-entry_coldb.mnhn.frSLASHcatalognumberSLASHmnhnSLASH
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_coldb.mnhn.frSLASHcatalognumberSLASHmnhnSLASH # loop back to label… if last char is anything but a dot
  # add ROR ID eventually to the final dot
  s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03wkt5x30>\1@;
  # remove duplicates
  s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03wkt5x30>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03wkt5x30> .)@\2\3@;
}

# ROR of id.snsb.info/snsb/collection/ --- https://ror.org/05th1v540
/^<https?:\/\/id.snsb.info\/snsb\/collection\// {
 :label_uri-entry_id.snsb.info_collection_SLASHobjectSLASH
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_id.snsb.info_collection_SLASHobjectSLASH # loop back to label… if last char is anything but a dot
  # add ROR ID eventually to the final dot
  s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05th1v540>\1@;
  # remove duplicates
  s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05th1v540>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05th1v540> .)@\2\3@;
}

# ROR of id.snsb.info/snsb/collection_monitoring/ --- https://ror.org/05th1v540
/^<https?:\/\/id.snsb.info\/snsb\/collection_monitoring\// {
 :label_uri-entry_id.snsb.info_collection_monitoring_SLASHobjectSLASH
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_id.snsb.info_collection_monitoring_SLASHobjectSLASH # loop back to label… if last char is anything but a dot
  
  # add ROR ID eventually to the final dot
  s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05th1v540>\1@;
  # remove duplicates
  s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05th1v540>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05th1v540> .)@\2\3@;
}

# ROR of data.nhm.ac.uk/object/ --- https://ror.org/039zvsn29
# distinguish between *.rdf and >
# <https://data.nhm.ac.uk/object/585704e8-2b31-47ee-b50e-1ca6acf142ea.rdf>
# <https://data.nhm.ac.uk/object/585704e8-2b31-47ee-b50e-1ca6acf142ea>
/^<https?:\/\/data.nhm.ac.uk\/object\// {
  /<https?:\/\/data.nhm.ac.uk\/object\/[^>]+\.rdf>/! {# filter out .rdf
  :label_uri-entry_data.nhm.ac.uk_SLASHobjectSLASH
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_data.nhm.ac.uk_SLASHobjectSLASH # loop back to label… if last char is anything but a dot
  
  # add ROR ID eventually to the final dot
  s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/039zvsn29>\1@;
  # remove duplicates
  s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/039zvsn29>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/039zvsn29> .)@\2\3@;
  }
}

# rbge add ROR https://data.rbge.org.uk/herb/ https://ror.org/0349vqz63
/^<https?:\/\/data.rbge.org.uk\/herb\// {
 :label_uri-entry_data.nhm.ac.uk_SLASHobjectSLASH
  N    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_data.nhm.ac.uk_SLASHobjectSLASH  # loop back to label… if last char is anything but a dot
  
  # add ROR ID eventually to the final dot
  s@(\s+[.])@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/0349vqz63>\1@;
  # remove duplicates
  s@(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/0349vqz63>\s+[;]\n +)(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/0349vqz63> .)@\2\3@;
}

  '  "${import_ttl_normalized}.trig"

  if [[ $debug_mode -gt 0  ]];then
  echo -e    "\e[32m# (5)   compress parsed file          ${import_ttl}.gz for backup ...\e[0m" ;
    gzip --force "${import_ttl}"
  echo -e    "\e[32m# (6)   compress normalised file      ${import_ttl_normalized}.gz ...\e[0m" ;
    gzip  --force "${import_ttl_normalized}"
  echo  -e   "\e[32m# (7)   compress normalised trig file ${import_ttl_normalized}.trig.gz ...\e[0m" ;
    gzip --force "${import_ttl_normalized}.trig"
  else
  echo  -e   "\e[32m# (5)   remove parsed file ${import_ttl} ...\e[0m" ;
    rm "${import_ttl}"
  echo  -e   "\e[32m# (6)   remove normalised file ${import_ttl_normalized} ...\e[0m" ;
    rm "${import_ttl_normalized}"
  echo  -e   "\e[32m# (7)   keep and compress normalised trig file ${import_ttl_normalized}.trig.gz ...\e[0m" ;
  gzip --force "${import_ttl_normalized}.trig"
  fi

  # if [[ `stat --printf="%s" "${rdfFilePath##*/}"*.log ` -eq 0 ]];then
  if [[ `file  $log_rdfparse_warnEtError | awk --field-separator=': ' '{print $2}'` == 'empty' ]]; then
    echo -e  "\e[32m# (8)   no warnings or errors, remove empty rdfparse log   $log_rdfparse_warnEtError ...\e[0m" ;
    rm $log_rdfparse_warnEtError
  else
    echo -e  "\e[31m# (8)   warnings and errors in rdfparse log (gzip)         ${log_rdfparse_warnEtError}.gz ...\e[0m" ;
    gzip --force "${log_rdfparse_warnEtError}"
  fi
  if [[ `file  $log_turtle2trig_warnEtError | awk --field-separator=': ' '{print $2}'` == 'empty' ]]; then
    echo -e  "\e[32m# (8)   no warnings or errors, remove empty trig log       $log_turtle2trig_warnEtError ...\e[0m" ;
    rm $log_turtle2trig_warnEtError
  else
    echo -e  "\e[31m# (8)   warnings and errors in converting to trig (gzip)   ${log_turtle2trig_warnEtError}.gz ...\e[0m" ;
    gzip --force "${log_turtle2trig_warnEtError}"
  fi
  if [[ `ls -lt "${rdfFilePath##*/}"*.log 2> /dev/null ` ]]; then
    echo -e  "\e[31m# (8)   warnings and errors in other log files (gzip)      ${rdfFilePath##*/}*.log.gz ...\e[0m" ;
    gzip --force "${rdfFilePath##*/}"*.log
  fi
  # increase index
  i=$((i + 1 ))
done

echo  -e "\e[32m#----------------------------------------\e[0m"
echo  -e "\e[32m# Done \e[0m"
echo  -e "\e[32m# Check compressed logs by, e.g. ...\e[0m"
echo  -e "\e[32m#    zgrep --color=always --ignore-case 'error\|warning' *.log.gz\e[0m"
echo  -e "\e[32m#    zgrep --ignore-case 'error\|warning' *.log.gz | sed --regexp-extended 's@file:///(.+)/(\./Thread)@\2@;s@^Thread-[^:]*:@@;'\e[0m"
echo  -e "\e[32m#    zcat *${file_search_pattern}*.log* | grep --color=always --ignore-case 'error\|warning' \e[0m"
if [[ `ls  *${file_search_pattern}*.log* 2> /dev/null | wc -l` -gt 0 ]];then
echo  -e "\e[31m#    `ls  *${file_search_pattern}*.log* 2> /dev/null | wc -l` log files found with warnings or errors\e[0m"
else
echo  -e "\e[32m#    No log files generated (i.e. no errors, warnings)\e[0m"
fi
echo  -e "\e[32m# Now you can import the normalised *.trig or *.ttl files to Apache Jena\e[0m"
echo  -e "\e[32m#########################################\e[0m"
