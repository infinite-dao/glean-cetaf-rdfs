#!/bin/bash
# filename convertRDF4import_normalise-files.sh
###########################
# Description: Use RDF and convert to ...
# => n-tuples (rdfparse), normalise, remove empty, fix standard URIs (wikidata etc)
# => trig format (turtle)
# => compression 
# dependencies $apache_jena_bin, e.g. ~/apache-jena-4.1.0/bin programs: turtle rdfparse
# dependencies ~/apache-jena-4.1.0/bin/rdfparse
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

apache_jena_bin=$([ -d "~/Programme/apache-jena-4.1.0/bin" ] && echo "~/Programme/apache-jena-4.1.0/bin" || echo "~/apache-jena-4.1.0/bin" )
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
echo -ne "# Do you want to parse \e[32m${n}\e[0m files with search pattern: «\e[32m${file_search_pattern}\e[0m» ?\n# [\e[32myes\e[0m or \e[31mno\e[0m (default: no)]: \e[0m"
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


i=1; n=`find . -maxdepth 1 -type f -iname "${file_search_pattern}" | wc -l `
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
  log_rdfparse_warnEtError="${rdfFilePath}_rdfparse.log"
  log_turtle2trig_warnEtError="${rdfFilePath}_turtle2trig.log"
  echo "#-----------------------------" ; 
# parse
  #   sed --regexp-extended  '  /"https?:\/\/[^"]+[ `]+[^"]*"/ { :label.urispace; s@"(https?://[^" ]+)\s@"\1%20@; tlabel.urispace; :label.uriaccentgrave; s@"(https?://[^"`]+)`@"\1%60@; tlabel.uriaccentgrave; } ' test-space-in-URIs.rdf > test-space-in-URIs_replaced.rdf
  
  n_of_illegal_iri_character_in_urls=`grep -i '"https\?://[^"]\+[ \`\\]\+[^"]*"\|<!--.*[^<][^!]--[^>].*-->' "${rdfFilePath}" | wc -l`
  if [[ $n_of_illegal_iri_character_in_urls -gt 0 ]];then
  printf   '\e[31m# (0) Fix illegal IRI characters in %s URLs (keep original RDF in %s.bak)...\n\e[0m' $n_of_illegal_iri_character_in_urls "${rdfFilePath}"; 
    sed --regexp-extended -i.bak ' 
    /<!--.*[^<][^!]--[^>].*-->/ { # rdfparse Fatal Error:  (line 75 column 113): The string "--" is not permitted within comments.
      :label.uri_doubleminus_in_comment; s@\s(https?://.+)--([^>]* -->)@ \1%2D%2D\2@; tlabel.uri_doubleminus_in_comment; # if (s)ubstitution successful (t)ested, go back to label cycle
    }
    /"https?:\/\/[^"]+[ `\\]+[^"]*"/ { 
      :label.urispace; s@"(https?://[^" ]+)\s@"\1%20@; tlabel.urispace;
      :label.uriaccentgrave; s@"(https?://[^"`]+)`@"\1%60@; tlabel.uriaccentgrave;
      :label.backslash; s@"(https?://[^"\\]+)\\@"\1%5C@; tlabel.backslash;
    } ' "${rdfFilePath}"
  fi  
  
  printf   "\e[32m# (1) Parse (%04d of %04d) to %s (turtle format: simple N-triple statements) ...\n\e[0m"  $i $n "${import_ttl}" ; 
  $apache_jena_bin/rdfparse -R "${rdfFilePath}" > "${import_ttl}" 2> "${log_rdfparse_warnEtError}"

# normalise
  echo -e  "\e[32m# (2)   normalise N-triples into      ${import_ttl_normalized} ...\e[0m"
  cat "${import_ttl}" | sed --regexp-extended  '
  /> "" \. *$/d; # delete empty value lines
  # do substitutions
  s@<https?:(//www.wikidata.org|//m.wikidata.org)/(wiki|entity)/([^"/]+)@<http://www.wikidata.org/entity/\3@g; # we need /entity not /wiki
  s@<https:(//www.ipni.org)@<http:\1@g;
  s@<https:(//purl.oclc.org)@<http:\1@g;
  s@<https:(//isni.org/isni/)@<http:\1@g;
  s@<https?://www.w3.org/2002/07/owl/@<http://www.w3.org/2002/07/owl#@g;
  s@<https?:(//viaf.org/viaf/[0-9]+)[/#<>]*[^"<>]*>@<http:\1>@g;
' > "${import_ttl_normalized}"
# plus trig format
  echo -e  "\e[32m# (3)   create trig format            ${import_ttl_normalized}.trig ...\e[0m" ; 
  $apache_jena_bin/turtle --validate "${import_ttl_normalized}" > "${log_turtle2trig_warnEtError}"
  $apache_jena_bin/turtle --quiet --output=trig "${import_ttl_normalized}" > "${import_ttl_normalized}.trig"
  
  echo -e  "\e[32m# (4)   add/check ROR ID              ${import_ttl_normalized}.trig ... (bgbm.org, biodiversitydata.nl, botanicalcollections.be, coldb.mnhn.fr, rbge.org.uk)\e[0m" ; 
  sed --regexp-extended --in-place '
# ROR of tgu.jacq.org/object/ --- https://ror.org/02drrjp49
 /^<https?:\/\/tgu.jacq.org\/object\// {
 :label_uri-entry_tgu.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_tgu.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://tgu.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02drrjp49>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/02drrjp49> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of herbarium.bgbm.org/object/ --- https://ror.org/00bv4cx53
 /^<https?:\/\/herbarium.bgbm.org\/object\// {
 :label_uri-entry_herbarium.bgbm.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_herbarium.bgbm.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://herbarium.bgbm.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00bv4cx53>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/00bv4cx53> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of hal.jacq.org/object/ --- https://ror.org/05gqaka33
 /^<https?:\/\/hal.jacq.org\/object\// {
 :label_uri-entry_hal.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_hal.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://hal.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05gqaka33>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/05gqaka33> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of pi.jacq.org/object/ --- https://ror.org/03ad39j10
 /^<https?:\/\/pi.jacq.org\/object\// {
 :label_uri-entry_pi.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_pi.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://pi.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/03ad39j10> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of brnu.jacq.org/object/ --- https://ror.org/02j46qs45
 /^<https?:\/\/brnu.jacq.org\/object\// {
 :label_uri-entry_brnu.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_brnu.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://brnu.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02j46qs45>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/02j46qs45> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of wu.jacq.org/object/ --- https://ror.org/03prydq77
 /^<https?:\/\/wu.jacq.org\/object\// {
 :label_uri-entry_wu.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_wu.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://wu.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/03prydq77> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of gat.jacq.org/object/ --- https://ror.org/02skbsp27
 /^<https?:\/\/gat.jacq.org\/object\// {
 :label_uri-entry_gat.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_gat.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://gat.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/02skbsp27>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/02skbsp27> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of ere.jacq.org/object/ --- https://ror.org/05mpgew40
 /^<https?:\/\/ere.jacq.org\/object\// {
 :label_uri-entry_ere.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_ere.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://ere.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05mpgew40>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/05mpgew40> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of gzu.jacq.org/object/ --- https://ror.org/01faaaf77
 /^<https?:\/\/gzu.jacq.org\/object\// {
 :label_uri-entry_gzu.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_gzu.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://gzu.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01faaaf77>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/01faaaf77> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of gjo.jacq.org/object/ --- https://ror.org/00nxtmb68
 /^<https?:\/\/gjo.jacq.org\/object\// {
 :label_uri-entry_gjo.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_gjo.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://gjo.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00nxtmb68>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/00nxtmb68> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of data.biodiversitydata.nl/naturalis/specimen/ --- https://ror.org/0566bfb96
 /^<https?:\/\/data.biodiversitydata.nl\/naturalis\/specimen\// {
 :label_uri-entry_data.biodiversitydata.nlSLASHnaturalisSLASHspecimenSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_data.biodiversitydata.nlSLASHnaturalisSLASHspecimenSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://data.biodiversitydata.nl/naturalis/specimen/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/0566bfb96>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/0566bfb96> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of mjg.jacq.org/object/ --- https://ror.org/023b0x485
 /^<https?:\/\/mjg.jacq.org\/object\// {
 :label_uri-entry_mjg.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_mjg.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://mjg.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/023b0x485>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/023b0x485> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of lz.jacq.org/object/ --- https://ror.org/03s7gtk40
 /^<https?:\/\/lz.jacq.org\/object\// {
 :label_uri-entry_lz.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_lz.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://lz.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03s7gtk40>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/03s7gtk40> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of tub.jacq.org/object/ --- https://ror.org/03a1kwz48
 /^<https?:\/\/tub.jacq.org\/object\// {
 :label_uri-entry_tub.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_tub.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://tub.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03a1kwz48>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/03a1kwz48> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of w.jacq.org/object/ --- https://ror.org/01tv5y993
 /^<https?:\/\/w.jacq.org\/object\// {
 :label_uri-entry_w.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_w.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://w.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01tv5y993>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/01tv5y993> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of specimens.kew.org/herbarium/ --- https://ror.org/00ynnr806
 /^<https?:\/\/specimens.kew.org\/herbarium\// {
 :label_uri-entry_specimens.kew.orgSLASHherbariumSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_specimens.kew.orgSLASHherbariumSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://specimens.kew.org/herbarium/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/00ynnr806>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/00ynnr806> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of www.botanicalcollections.be/specimen/ --- https://ror.org/01h1jbk91
 /^<https?:\/\/www.botanicalcollections.be\/specimen\// {
 :label_uri-entry_www.botanicalcollections.beSLASHspecimenSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_www.botanicalcollections.beSLASHspecimenSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://www.botanicalcollections.be/specimen/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/01h1jbk91>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/01h1jbk91> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of bak.jacq.org/object/ --- https://ror.org/006m4q736
 /^<https?:\/\/bak.jacq.org\/object\// {
 :label_uri-entry_bak.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_bak.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://bak.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/006m4q736>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/006m4q736> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of coldb.mnhn.fr/catalognumber/mnhn/ --- https://ror.org/03wkt5x30
 /^<https?:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\// {
 :label_uri-entry_coldb.mnhn.frSLASHcatalognumberSLASHmnhnSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_coldb.mnhn.frSLASHcatalognumberSLASHmnhnSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://coldb.mnhn.fr/catalognumber/mnhn/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03wkt5x30>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/03wkt5x30> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of tbi.jacq.org/object/ --- https://ror.org/051qn8h41
 /^<https?:\/\/tbi.jacq.org\/object\// {
 :label_uri-entry_tbi.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_tbi.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://tbi.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/051qn8h41>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/051qn8h41> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of piagr.jacq.org/object/ --- https://ror.org/03ad39j10
 /^<https?:\/\/piagr.jacq.org\/object\// {
 :label_uri-entry_piagr.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_piagr.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://piagr.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03ad39j10>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/03ad39j10> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
# ROR of je.jacq.org/object/ --- https://ror.org/05qpz1x62
 /^<https?:\/\/je.jacq.org\/object\// {
 :label_uri-entry_je.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_je.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://je.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05qpz1x62>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/05qpz1x62> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }
  
# ROR of id.snsb.info/snsb/collection/ --- https://ror.org/05th1v540
 /^<https?:\/\/id.snsb.info\/snsb\/collection\// {
 :label_uri-entry_id.snsb.info_collection_SLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_id.snsb.info_collection_SLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://id.snsb.info/snsb/collection/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05th1v540>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/05th1v540> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }

# ROR of id.snsb.info/snsb/collection_monitoring/ --- https://ror.org/05th1v540
 /^<https?:\/\/id.snsb.info\/snsb\/collection_monitoring\// {
 :label_uri-entry_id.snsb.info_collection_monitoring_SLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_id.snsb.info_collection_monitoring_SLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://id.snsb.info/snsb/collection_monitoring/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05th1v540>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/05th1v540> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
 }

# ROR of data.nhm.ac.uk/object/ --- https://ror.org/039zvsn29
  # distinguish between *.rdf and >
  # <https://data.nhm.ac.uk/object/585704e8-2b31-47ee-b50e-1ca6acf142ea.rdf>
  # <https://data.nhm.ac.uk/object/585704e8-2b31-47ee-b50e-1ca6acf142ea>

 /^<https?:\/\/data.nhm.ac.uk\/object\// {
  /<https?:\/\/data.nhm.ac.uk\/object\/[^>]+\.rdf>/! { # filter out .rdf
 :label_uri-entry_data.nhm.ac.uk_SLASHobjectSLASH
   N                                    # append lines via \n into patternspace
   /\.$/!b label_uri-entry_data.nhm.ac.uk_SLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID>/ ! { 
                                        # if no institutionID, do this:
      s@(<https?://data.nhm.ac.uk/object/.+)(\s+\.$)@\1 ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/039zvsn29>\2@;
                                        # append specific ROR institutionID
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/institutionID> +<https:\/\/ror.org\/[^<>]+>/! {
                                        # if no ROR institutionID, do this:
      s@(<http://rs.tdwg.org/dwc/terms/institutionID> +)(<[^<>]+>)(.+$)@\1\2\3\n\n\2\n        <http://www.w3.org/2002/07/owl#owl:sameAs>  <https://ror.org/039zvsn29> .@;
                                        # append block <uri-of-own-institutionID> owl:sameAs <ROR-ID> .
    }
  }
 }

# publisher URL of lagu.jacq.org/object/ --- <http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv> ;
 /^<https?:\/\/lagu.jacq.org\/object\// {
 :label_uri-entry_lagu.jacq.orgSLASHobjectSLASH
   N                                    # append lines via \n into pattern space
   /\.$/!b label_uri-entry_lagu.jacq.orgSLASHobjectSLASH # go back if last char is not a dot
    /<http:\/\/purl.org\/dc\/terms\/publisher> +<https:\/\/www.jardinbotanico.org.sv>.+\s+\.$/ !  { 
                                        # if no publisher with this URL is there, do this:
      s@(<https?://lagu.jacq.org/object/.+)(\s+\.$)@\1 ;\n        <http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv>\2@;
                                        # append publisher as URL
    }
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
echo  -e "\e[32m#    zgrep --color=auto --ignore-case 'error\|warning' *.log.gz | sed --regexp-extended 's@file:///([^\.]+)/(\./Thread)@\2@;s@^Thread-[^:]*:@@;'\e[0m"
echo  -e "\e[32m#    zcat *${file_search_pattern}*.log* | grep --ignore-case 'error\|warning' \e[0m"
if [[ `ls  *${file_search_pattern}*.log* 2> /dev/null | wc -l` -gt 0 ]];then 
echo  -e "\e[31m#    `ls  *${file_search_pattern}*.log* 2> /dev/null | wc -l` log files found with warnings or errors\e[0m"
else
echo  -e "\e[32m#    No log files generated (i.e. no errors, warnings)\e[0m"
fi
echo  -e "\e[32m# Now you can import the normalised *.trig or *.ttl files to Apache Jena\e[0m"
echo  -e "\e[32m#########################################\e[0m"
