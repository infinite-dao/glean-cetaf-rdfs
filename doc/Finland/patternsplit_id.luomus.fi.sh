#!/bin/bash

awk_patternsplit_commands=/opt/jena-fuseki/import-sandbox/bin/patternsplit.awk
cd "$PWD"

ls_search_pattern='Thread-*id.luomus.fi_2022[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]*.normalized.ttl.trig.gz'
IFS=$'\n';
n=`ls $ls_search_pattern | wc -l`
i=1
# for f in `ls $ls_search_pattern | sort --version-sort | head -n 5 `; do
for f in `ls $ls_search_pattern | sort --version-sort `; do
  printf "# \e[32m$f processing\e[0m … (%s of %s)\n" $i $n
  this_file_modified_is_gz=0
  this_file_is_gz=$([ $(echo "$f" | grep ".\bgz$") ] && echo 1  || echo 0 )
  if [[ $this_file_is_gz -gt 0 ]];then
    printf '#   gunzip %s …\n' "$f"; gunzip --quiet "$f"
    f=${f/%.gz/}
  fi
  
  prefix_normalized_file=`echo "$f" | sed -r 's@.*(Thread-.*id.luomus.fi.*)_modified.rdf.+@\1@'`  ;
  awk_fileprefix="${prefix_normalized_file}_importsplit_";
  echo "# DEV run patternsplit …";
  # echo "# DEV start patternsplit awk -v fileprefix=\"$awk_fileprefix\" -v compress_files=1 -f /opt/jena-fuseki/import-sandbox/bin/patternsplit.awk     \"$f\""
  awk -v fileprefix="$awk_fileprefix" -v compress_files=1 -f "$awk_patternsplit_commands" "$f"; 
  printf '#   gzip %s …\n' "$f"; gzip --quiet "$f";
  i=$(( i + 1 ));
done
unset IFS
