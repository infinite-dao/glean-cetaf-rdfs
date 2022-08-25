#!/bin/bash
# TODO generate vor paris pattern ^<https?:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\/[a-z]+\/[^<>]+
# generate sed search pattern for trig formatted RDF
# See also
# - https://ror.org
# - https://www.worldcat.org/identities/
# - http://viaf.org

# [ "${SED_EXPRESSION_MATCH_CETAFID["coldb.mnhn.fr/cudairneg"]+irgendwas}" ] && echo "exists" || echo "existiert nicht"
# [ "${SED_EXPRESSION_MATCH_CETAFID["coldb.mnhn.fr/catalognumber/mnhn/"]+irgendwas}" ] && echo "exists" || echo "existiert nicht"
    
declare -A ROR_OR_INSTITUTION # associative array
declare -A SED_EXPRESSION_MATCH_CETAFID # associative array

# ROR_OR_INSTITUTION["domain-cetaf-ID-fixed-pattern-path-without-ID"]="URL-ROR-ID", e.g. 
# ROR_OR_INSTITUTION["coldb.mnhn.fr/catalognumber/mnhn/"]="https://ror.org/03wkt5x30"
#   SED_EXPRESSION_MATCH_CETAFID["coldb.mnhn.fr/catalognumber/mnhn/"]="^<https?:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\/[a-z]+\/[^<>]+>"
# ROR_OR_INSTITUTION["data.biodiversitydata.nl/naturalis/specimen/"]="https://ror.org/0566bfb96"
# ROR_OR_INSTITUTION["data.nhm.ac.uk/object/"]="https://ror.org/039zvsn29"
# ROR_OR_INSTITUTION["data.rbge.org.uk/herb/"]="https://ror.org/0349vqz63"
# ROR_OR_INSTITUTION["herbarium.bgbm.org/object/"]="https://ror.org/00bv4cx53"
# ROR_OR_INSTITUTION["specimens.kew.org/herbarium/"]="https://ror.org/00ynnr806"
# ROR_OR_INSTITUTION["www.botanicalcollections.be/specimen/"]="https://ror.org/01h1jbk91"
# ROR_OR_INSTITUTION["id.herb.oulu.fi"]="https://ror.org/03yj89h83"
# ROR_OR_INSTITUTION["id.smns-bw.org"]="https://ror.org/05k35b119"
#   SED_EXPRESSION_MATCH_CETAFID["id.smns-bw.org"]="^<https?:\/\/id.smns-bw.org\/smns\/collection\/[0-9]+\/[^<>]+>"
        #   https://id.smns-bw.org/smns/collection/275270/772621/279650

# ROR_OR_INSTITUTION["id.snsb.info/snsb/collection/"]="https://ror.org/05th1v540"
# ROR_OR_INSTITUTION["id.snsb.info/snsb/collection_monitoring/"]="https://ror.org/05th1v540"
#   SED_EXPRESSION_MATCH_CETAFID["id.snsb.info/snsb/collection/"]="^<https?:\/\/id.snsb.info\/snsb\/collection\/[0-9]+\/[^<>]+>"
#   SED_EXPRESSION_MATCH_CETAFID["id.snsb.info/snsb/collection_monitoring/"]="^<https?:\/\/id.snsb.info\/snsb\/collection_monitoring\/[0-9]+\/[^<>]+>"

# # # # # # Finland (needs carful check to catch the CSPP and conformsTo the right way: the CSPP should not be added for (dcmi)type Event but for (dcmi)type PhysicalObject ?Occurrence?)
# ROR_OR_INSTITUTION["id.luomus.fi"]="https://ror.org/undefined4id.luomus.fi"
ROR_OR_INSTITUTION["id.luomus.fi"]="https://ror.org/03tcx6c30"
ROR_OR_INSTITUTION["id.zmuo.oulu.fi"]="https://ror.org/03yj89h83"
# ROR_OR_INSTITUTION["tun.fi"]="https://ror.org/6-institutions"

# # # # # # # # # # # # # # 
# JACQ
# ROR_OR_INSTITUTION["admont.jacq.org"]="https://nowhere.org/no-ROR-yet-for-admont-jacq-org"
# ROR_OR_INSTITUTION["admont.jacq.org"]="http://viaf.org/viaf/128466393"
# ROR_OR_INSTITUTION["bak.jacq.org"]="https://ror.org/006m4q736"
# # ROR_OR_INSTITUTION["boz.jacq.org"]="https://nowhere.org/no-ROR-yet-for-boz-jacq-org"
# ROR_OR_INSTITUTION["boz.jacq.org"]="http://viaf.org/viaf/128699910"
# #   # nicht im Indexer 2020-09-15
# 
# ROR_OR_INSTITUTION["brnu.jacq.org"]="https://ror.org/02j46qs45"
# ROR_OR_INSTITUTION["dr.jacq.org"]="http://viaf.org/viaf/155418159"
#   # https://www.worldcat.org/identities/viaf-155418159/
#   # http://viaf.org/viaf/155418159/#Technische_Universität_(Dresden)._Institut_für_Botanik
# ROR_OR_INSTITUTION["ere.jacq.org"]="https://ror.org/05mpgew40"
# ROR_OR_INSTITUTION["gat.jacq.org"]="https://ror.org/02skbsp27"
# ROR_OR_INSTITUTION["gjo.jacq.org"]="https://ror.org/00nxtmb68"
# ROR_OR_INSTITUTION["gzu.jacq.org"]="https://ror.org/01faaaf77"
# ROR_OR_INSTITUTION["hal.jacq.org"]="https://ror.org/05gqaka33"
# ROR_OR_INSTITUTION["je.jacq.org"]="https://ror.org/05qpz1x62"
# ROR_OR_INSTITUTION["kiel.jacq.org"]="http://viaf.org/viaf/239180770"
# 
# ROR_OR_INSTITUTION["lagu.jacq.org/object"]="https://ror.org/01j60ss54"
# ROR_OR_INSTITUTION["lz.jacq.org"]="https://ror.org/03s7gtk40"
# ROR_OR_INSTITUTION["mjg.jacq.org"]="https://ror.org/023b0x485"
# ROR_OR_INSTITUTION["pi.jacq.org"]="https://ror.org/03ad39j10"
# ROR_OR_INSTITUTION["piagr.jacq.org"]="https://ror.org/03ad39j10"
# ROR_OR_INSTITUTION["prc.jacq.org"]="https://ror.org/024d6js02"
# ROR_OR_INSTITUTION["tbi.jacq.org/object"]="https://ror.org/051qn8h41"
# ROR_OR_INSTITUTION["tgu.jacq.org"]="https://ror.org/02drrjp49"
# ROR_OR_INSTITUTION["tub.jacq.org"]="https://ror.org/03a1kwz48"
# ROR_OR_INSTITUTION["ubt.jacq.org"]="http://viaf.org/viaf/142509930"
# ROR_OR_INSTITUTION["w.jacq.org"]="https://ror.org/01tv5y993"
# ROR_OR_INSTITUTION["willing.jacq.org"]="http://www.willing-botanik.de"
# #   # nicht im Indexer 2020-09-15
# ROR_OR_INSTITUTION["wu.jacq.org"]="https://ror.org/03prydq77"

# # IFS=$'\n' ROR_OR_INSTITUTION_URI_sorted=($(sort <<<"${ROR_OR_INSTITUTION[*]}")); unset IFS
# # printf "[%s]\n" "${ROR_OR_INSTITUTION_URI_sorted[@]}"
IFS=$'\n' ROR_OR_INSTITUTION_DOMAIN_sorted=($(sort <<<"${!ROR_OR_INSTITUTION[*]}")); unset IFS
# # printf "[%s]\n" "${ROR_OR_INSTITUTION_DOMAIN_sorted[@]}"

len=${#ROR_OR_INSTITUTION[@]}
i=1
# /^<https?:\/\/wu.jacq.org\/[^<>/]+>/ {
#   :label_uri-entry_wu.jacq.orgSLASHno_object
#   N    # append lines via \n into patternspace
#   / \.$/!b label_uri-entry_wu.jacq.orgSLASHno_object # loop back to label… if last char is anything but a dot
#   # wu.jacq.org --- ROR_OR_INSTITUTION-ID https://ror.org/03prydq77
#   /^<https?:\/\/wu.jacq.org\/[^<>/]+/,/ .$/ {
#     # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
#     s@(\s+[.])$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77>\1@;
#     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  <https://ror.org/03prydq77> .)@\1\2@;
#     # add isPartOf
#     s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;
#     s@(\s+[.])$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://wu.jacq.org>\1@;
#     s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;
#   }
# } # JACQ without object
for null_index in "${!ROR_OR_INSTITUTION_DOMAIN_sorted[@]}";do
  # for domain_part in "${!ROR_OR_INSTITUTION[@]}"; do 
  domain_part=${ROR_OR_INSTITUTION_DOMAIN_sorted[$null_index]};
  domain_only_http=`echo ${domain_part} | sed -r 's@^([^/]+)/?.*$@http://\1@'`
  
  this_institution_id=${ROR_OR_INSTITUTION[$domain_part]};
  
  [[ "${domain_part}" != */ ]] && domain_part_with_slash="${domain_part}/" || domain_part_with_slash="${domain_part}"
  
  echo "# ## ROR_OR_INSTITUTION of" $domain_part --- ${this_institution_id}; 
  if [[ $domain_part =~ wu.jacq.org ]];then
  echo "#   https://wu.jacq.org/WU-MYC "
  echo "#   https://wu.jacq.org/WU "
  fi
  
  # fix sed search match for some institution IDs
  if [ -v 'SED_EXPRESSION_MATCH_CETAFID[$domain_part]' ];then
  echo "/${SED_EXPRESSION_MATCH_CETAFID[$domain_part]}/ {"
  else
  echo "/^<https?:\/\/"${domain_part_with_slash//\//\\/}"[^<>/]+>/ {"
  fi

  echo "  :label_uri-entry_"${domain_part//\//SLASH}
  echo "  N                                     # append lines via \n into patternspace"
  echo "  / \.$/!b label_uri-entry_"${domain_part//\//SLASH}" # go back if last char is not a dot"
  if [[ $domain_part =~ willing.jacq.org ]];then
  echo "  # skip adding ROR_OR_INSTITUTION ID, add publisher"
  else
  echo "  # add ROR_OR_INSTITUTION ID eventually to the final dot, and remove possible duplicates
     s@(\s+[.])\$@ ;\n        <http://rs.tdwg.org/dwc/terms/institutionID>  <${this_institution_id}>\1@;
     s@<http://rs.tdwg.org/dwc/terms/institutionID>  <${this_institution_id}>\s+[;]\n +(<.+)(<http://rs.tdwg.org/dwc/terms/institutionID>  ${this_institution_id} .)@\1\2@; "
  fi # institutionID
  echo "  # add dcterms:isPartOf, dcterms:hasPart, dcterms:conformsTo"
  echo "    s@(\s+[.])\$@ ;\n        <http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_(CSPP)>\1@;"
  if [[ $domain_part =~ .fi$ ]];then
  echo "  # fix remove conformsTo:CETAFID on rdf:type or dcterms:type Event"
  echo "    s@(<http://www.w3.org/1999/02/22-rdf-syntax-ns#type> +<http://rs.tdwg.org/dwc/terms/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_\(CSPP\)>(\s+[.])@\1\2\3@;"
  echo "    s@(<http://purl.org/dc/terms/type> +<http://purl.org/dc/dcmitype/Event> ;)(.*) ;\n +<http://purl.org/dc/terms/conformsTo>  <https://cetafidentifiers.biowikifarm.net/wiki/CETAF_Specimen_Preview_Profile_\(CSPP\)>(\s+[.])@\1\2\3@;"
  echo "    s@(\s+[.])\$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://gbif.fi>\1@;"
  echo "    s@(\s+[.])\$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://$domain_part>\1@;"
  fi

  if [[ $domain_part =~ jacq.org ]];then
  echo "  s@(\s+[.])\$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <http://jacq.org>\1@;"
  echo "  s@(\s+[.])\$@ ;\n        <http://purl.org/dc/terms/isPartOf>  <${domain_only_http}>\1@;"
  fi
  if [[ $domain_part =~ lagu.jacq.org ]];then
  echo "  # add dcterms:publisher"
  echo "  s@(\s+[.])\$@ ;\n        <http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv>\1@;"
  echo "  s@(<http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv>\s+[;]\n +)(<.+)(<http://purl.org/dc/terms/publisher>  <https://www.jardinbotanico.org.sv> .)@\2\3@;"
  fi
  if [[ $domain_part =~ willing.jacq.org ]];then
  echo "  # add dcterms:publisher"
  echo "  s@(\s+[.])\$@ ;\n        <http://purl.org/dc/terms/publisher>  <http://www.willing-botanik.de>\1@;"
  echo "  s@(<http://purl.org/dc/terms/publisher>  <https://http://www.willing-botanik.de>\s+[;]\n +)(<.+)(<http://purl.org/dc/terms/publisher>  <http://www.willing-botanik.de> .)@\2\3@;"
  fi
  
  if [[ $domain_part =~ data.rbge.org.uk ]];then
  echo "  # add dcterms:publisher"
  echo "  s@(\s+[.])\$@ ;\n        <http://purl.org/dc/terms/publisher>  <http://www.rbge.org.uk>\1@;"
  echo "  s@(<http://purl.org/dc/terms/publisher>  <http://www.rbge.org.uk>\s+[;]\n +)(<.+)(<http://purl.org/dc/terms/publisher>  <http://www.rbge.org.uk> .)@\2\3@;"
  fi

  if [[ $domain_part =~ coldb.mnhn.fr ]];then
  echo "  # add isPartOf for sub collections mnhn/pc/ mnhn/zo/ and so on"
  echo "  s@^<(https?://coldb.mnhn.fr/catalognumber/mnhn/[^<>/]+/)([^<>]+)>(.+)(\s+[.])$@<\1\2>\3 ;\n        <http://purl.org/dc/terms/isPartOf>  <\1>\4@;"
  fi

  echo "  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://www.wikidata.org/entity/[^<>]+>\s+[;.])(\n +<.+[.])\$@\n        <http://purl.org/dc/terms/hasPart>  <http://www.wikidata.org/entity/> ;\1\2@;"
  echo "  s@(\n +<http://rs.tdwg.org/dwc/iri/recordedBy>  <http://viaf.org/viaf/[^<>]+>\s+[;.])(\n +<.+[.])\$@\n        <http://purl.org/dc/terms/hasPart>  <http://viaf.org/viaf/> ;\1\2@;"
  echo "} ## end ROR_OR_INSTITUTION $domain_part"
done



# echo "PREFIX dwc: <http://rs.tdwg.org/dwc/terms/>";
# echo "PREFIX dcterms: <http://purl.org/dc/terms/>";
# echo "SELECT  ?cetaf_id_exaple ?title_example ?ror_id"
# echo "WHERE {";
# for domain_part in "${!ROR_OR_INSTITUTION[@]}"; do 
# [[ "${domain_part}" != */ ]] && domain_part_with_slash="${domain_part}/" || domain_part_with_slash="${domain_part}"
#   echo "  { SELECT  ?cetaf_id_exaple ?p ?title_example ?ror_id";
#   echo "    WHERE";
#   echo "    { ?cetaf_id_exaple  ?p  ?title_example;";
#   echo "          # ROR_OR_INSTITUTION of" $domain_part --- ${this_institution_id}; 
#   echo "          dwc:institutionID <"${this_institution_id}">;";
#   echo "          dcterms:title ?title_example;";
#   echo "          dwc:institutionID ?ror_id;";
#   echo "    }";
#   echo "    LIMIT   1 # $i of $len";
#   if [[ $i -lt $len ]];then
#   echo "  } UNION";
#   else
#   echo "  }";
#   fi
#   i=$(( i + 1 ))
# done
#   echo "}";
