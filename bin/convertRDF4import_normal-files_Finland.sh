#!/bin/bash
###########################
# Usage: convert RDF files to normalised zipped files and check for adding ror.org IDs or dcterms:isPartOf etc. or remove technical stuff
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
# # # # # # # # # # # # # #
# dependencies $apache_jena_bin, e.g. /home/aplank/apache-jena-4.2.0/bin programs: turtle rdfparse
# dependencies /home/aplank/apache-jena-4.2.0/bin/rdfparse
# dependencies gzip, sed, cat
###########################
# this will find all Thread-1_... Thread-2_... etc. files
# file_search_pattern="Thread*coldb.mnhn.fr*.rdf"
# file_search_pattern="Thread*tub.jacq.org*.rdf"
# file_search_pattern="Thread*herbarium.bgbm.org*.rdf"
# file_search_pattern="Thread*lagu.jacq.org*.rdf"
# file_search_pattern="Thread*.jacq.org*.rdf"
# file_search_pattern="Thread-*biodiversitydata.nl*.rdf"
# file_search_pattern="test-space-in-URIs.rdf"
debug_mode=0

apache_jena_bin=$([ -d ~/"Programme/apache-jena-4.3.2/bin" ] && echo ~/"Programme/apache-jena-4.3.2/bin" || echo ~/"apache-jena-4.2.0/bin" )
# apache_jena_bin=$([ -d ~/"Programme/apache-jena-4.1.0/bin" ] && echo ~/"Programme/apache-jena-4.1.0/bin" || echo ~/"apache-jena-4.0.0/bin" )

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
  # add datatype to <dwc:decimalLatitude> or <dwc:decimalLatitude>
  # <http://lagu.jacq.org/object/AA-00001> <http://rs.tdwg.org/dwc/terms/decimalLongitude> "-88.98333" .
  # <http://lagu.jacq.org/object/AA-00001> <http://rs.tdwg.org/dwc/terms/decimalLatitude> "13.5"^^<http://www.w3.org/2001/XMLSchema#decimal> .
    s@(<http://rs.tdwg.org/dwc/terms/(decimalLongitude|decimalLatitude)>)( "[^"]*")( \.)@\1\3^^<http://www.w3.org/2001/XMLSchema#decimal>\4@;
  # <http://www.w3.org/2003/01/geo/wgs84_pos#lat> "The WGS84 latitude of a SpatialThing (decimal degrees)." 
  # <http://www.w3.org/2003/01/geo/wgs84_pos#long> "The WGS84 longitude of a SpatialThing (decimal degrees)."  
    s@(<http://www.w3.org/2003/01/geo/wgs84_pos#(lat|long)>)( "[^"]*")( \.)@\1\3^^<http://www.w3.org/2001/XMLSchema#decimal>\4@;
' > "${import_ttl_normalized}"
# plus trig format
  echo -e  "\e[32m# (3)   create trig format            ${import_ttl_normalized}.trig ...\e[0m" ;
  $apache_jena_bin/turtle --validate "${import_ttl_normalized}" > "${log_turtle2trig_warnEtError}"
  $apache_jena_bin/turtle --quiet --output=trig "${import_ttl_normalized}" > "${import_ttl_normalized}.trig"

  echo -e  "\e[32m# (4)   check RORID, delete technical stuff, add isPartOf etc.  ${import_ttl_normalized}.trig ... (id.herb.oulu.fi, tun.fi etc.)\e[0m" ;
  sed --regexp-extended --in-place '

# http://www.wikidata.org/entity/
/^<https?:\/\/www.wikidata.org\/entity\/[^<>/]+>/ {
  :label_uri-entry_www.wikidata.orSLASHentitySLASH
  N;    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_www.wikidata.orSLASHentitySLASH # loop back to label… if last char is anything but a dot
  s@(<https?)(://www.wikidata.org/entity/)(.+)(\s+[.])@\1\2\3 ;\n        <http://purl.org/dc/terms/isPartOf>  <http\2>\4@;
}

# delete technical stuff
/^<https?:\/\/[^<>/]+\/[^<>]+=[^<>]+>/ {
  :label_uri-entry_technical_data_tobedeleted
  N;    # append lines via \n into patternspace
  /\.$/!b label_uri-entry_technical_data_tobedeleted # loop back to label… if last char is anything but a dot
  d;
}


# # # # Finland start
# ## ROR of id.herb.oulu.fi --- https://ror.org/03yj89h83
 /^<https?:\/\/id.herb.oulu.fi\/[^<>/]+>/ {
 :label_uri-entry_id.herb.oulu.fi
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_id.herb.oulu.fi # go back if last char is not a dot
   # add ROR ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03yj89h83>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03yj89h83>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03yj89h83 .)@\1\2@; 
   # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
    # fix remove conformsTo:CETAFID on rdf:type or dcterms:type Event
    s@(<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> +<http://rs.tdwg.org/dwc/terms/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>(\s+[.])@\1\2\3@;
    s@(<http://purl.org/dc/terms/type> +<http://purl.org/dc/dcmitype/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>(\s+[.])@\1\2\3@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gbif.fi>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://id.herb.oulu.fi>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR id.herb.oulu.fi
  
# ## ROR of id.luomus.fi --- https://ror.org/03tcx6c30
/^<https?:\/\/id.luomus.fi\/[^<>/]+>/ {
 :label_uri-entry_id.luomus.fi
   N                                     # append lines via \n into patternspace
   / \.$/!b label_uri-entry_id.luomus.fi # go back if last char is not a dot
   # add ROR ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03tcx6c30>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03tcx6c30>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03tcx6c30 .)@\1\2@; 
   # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
    # fix remove conformsTo:CETAFID on rdf:type or dcterms:type Event
    s@(<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> +<http://rs.tdwg.org/dwc/terms/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>(\s+[.])@\1\2\3@;
    s@(<http://purl.org/dc/terms/type> +<http://purl.org/dc/dcmitype/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>(\s+[.])@\1\2\3@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gbif.fi>\1@;
   s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://id.luomus.fi>\1@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
   s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR id.luomus.fi

  
# ## ROR of tun.fi --- https://ror.org/6-institutions
/^<https?:\/\/tun.fi\/[^<>/]+>/ {
  :label_uri-entry_tun.fi
  N                                     # append lines via \n into patternspace
  / \.$/!b label_uri-entry_tun.fi # go back if last char is not a dot
  ## add ROR ID eventually to the final dot, and remove possible duplicates
    # "HERBARIUM UNIVERSITATIS OULUENSIS … " => University of Oulu
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/collectionCode>  "HERBARIUM UNIVERSITATIS OULUENSIS" [;.]/{ # test dwcterms:collectionCode
      s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03yj89h83>\1@;
      s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03yj89h83>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03yj89h83 .)@\1\2@; 
    }
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/collectionCode>  "HERBARIUM UNIVERSITATIS OULUENSIS OULU" [;.]/{ # test dwcterms:collectionCode
      s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03yj89h83>\1@;
      s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03yj89h83>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03yj89h83 .)@\1\2@; 
    }
    # "Hatikka.fi observations" => Finnish Museum of Natural History
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/collectionCode>  "Hatikka.fi observations" [;.]/{ # test dwcterms:collectionCode
      s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03tcx6c30>\1@;
      s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03tcx6c30>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03tcx6c30 .)@\1\2@; 
    }
    # "TUR-A Vascular plant collections …" => Abo Akademi, Turku, Finland (http://mus.utu.fi/)
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/collectionCode>  "TUR-A Vascular plant collections of the Åbo Akademi, Herbarium generale" [;.]/{ # test dwcterms:collectionCode
      s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/029pk6x14>\1@;
      s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/029pk6x14>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/029pk6x14 .)@\1\2@; 
    }
    # "TUR Vascular plant collections of the Turku University, Herbarium generale" => Natural History Museum, University of Turku (http://mus.utu.fi/)
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/collectionCode>  "TUR Vascular plant collections of the Turku University, Herbarium generale" [;.]/{ # test dwcterms:collectionCode
      s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05vghhr25>\1@;
      s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/05vghhr25>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/05vghhr25 .)@\1\2@; 
    }
    # "Vascular Plant Herbarium" => Finnish Museum of Natural History
    /<http:\/\/rs.tdwg.org\/dwc\/terms\/collectionCode>  "Vascular Plant Herbarium" [;.]/{ # test dwcterms:collectionCode
      s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03tcx6c30>\1@;
      s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03tcx6c30>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/03tcx6c30 .)@\1\2@; 
    }
  # unclear ROR for dwcterms:collectionCode>  "Kastikka Ark" ;
  # unclear ROR for dwcterms:collectionCode>  "Kastikka Floristic Archives (TURA)" ;
  # unclear ROR for dwcterms:collectionCode>  "Kastikka Literature Sources" ;
  # unclear ROR for dwcterms:collectionCode>  "Kastikka Small Collections" ;
  # unclear ROR for dwcterms:collectionCode>  "Vascular plant collections of Tampere Museums (TMP)" ;
  
  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
    # fix remove conformsTo:CETAFID on rdf:type or dcterms:type Event
    s@(<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> +<http://rs.tdwg.org/dwc/terms/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>(\s+[.])@\1\2\3@;
    s@(<http://purl.org/dc/terms/type> +<http://purl.org/dc/dcmitype/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>(\s+[.])@\1\2\3@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gbif.fi>\1@;
  s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://tun.fi>\1@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
} ## end ROR tun.fi
  
## # code template ## ROR of tun.fi --- https://ror.org/6-institutions
##  /^<https?:\/\/tun.fi\/[^<>/]+>/ {
##  :label_uri-entry_tun.fi
##    N                                     # append lines via \n into patternspace
##    / \.$/!b label_uri-entry_tun.fi # go back if last char is not a dot
##    # add ROR ID eventually to the final dot, and remove possible duplicates
##      s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/6-institutions>\1@;
##      s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/6-institutions>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  https://ror.org/6-institutions .)@\1\2@; 
##    # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo
##    s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;
##      # fix remove conformsTo:CETAFID on rdf:type or dcterms:type Event
##      s@(<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> +<http://rs.tdwg.org/dwc/terms/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>(\s+[.])@\1\2\3@;
##      s@(<http://purl.org/dc/terms/type> +<http://purl.org/dc/dcmitype/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>(\s+[.])@\1\2\3@;
##    s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gbif.fi>\1@;
##    s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://tun.fi>\1@;
##    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
##    s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;
## } ## end ROR tun.fi
  
# # # # Finland end  
  
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
echo  -e "\e[32m# # # # # Modifications # # # # # # # # # #\e[0m"
echo  -e "\e[32m# Added: \e[1;34mdcterms:conformsTo <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\e[32m\e[0m"
echo  -e "\e[32m# Added: \e[1;34mdcterms:isPartOf <http://gbif.fi>\e[32m\e[0m"
echo  -e "\e[32m# Added some \e[1;34mdwcterms:institutionID <http://ror.org/…ID…>\e[32m\e[0m"
echo  -e "\e[32m# Maybe added \e[1;34mdcterms:isPartOf <http://www.wikidata.org/entity/>\e[32m \e[0m"
echo  -e "\e[32m# Maybe added \e[1;34mdcterms:hasPart  <http://www.wikidata.org/entity/>\e[32m \e[0m"
echo  -e "\e[32m# Maybe added \e[1;34mdcterms:isPartOf <http://viaf.org/viaf/>\e[32m \e[0m"
echo  -e "\e[32m# Maybe added \e[1;34mdcterms:hasPart  <http://viaf.org/viaf/>\e[32m \e[0m"
echo  -e "\e[32m#########################################\e[0m"
