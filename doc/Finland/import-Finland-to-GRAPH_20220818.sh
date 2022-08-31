#!/bin/bash
if grep -q docker /proc/1/cgroup; then 
    echo -e  "# \e[32mOK\e[0m inside docker. Import Finland domains..."
else
   echo -e  "# \e[31mError:\e[0m script is executet on host but needs to run inside docker (stop)."
   echo -e  "#        You can enter the docker container by «docker exec -it containername bash», e.g. docker exec -it fuseki-app bash"
   exit
fi

# docker exec -it fuseki-app bash
  working_directory=/import-data/rdf/Finland; 
  cd $working_directory
  for graph_domain_and_optional_path in id.luomus.fi id.herb.oulu.fi tun.fi;do
  # for graph_domain_and_optional_path in id.herb.oulu.fi tun.fi;do
    this_domain=$(echo $graph_domain_and_optional_path | sed -r 's@/.+$@@' )
    this_datetime=$(date '+%Y%m%d-%Hh%Mm%Ss')
    echo "# - - - Start import $this_domain (for http://${graph_domain_and_optional_path}) at $this_datetime ..."
    # file_pattern="Thread-*${this_domain}*-[0-9][0-9][0-9][0-9]_modified.rdf.normalized.ttl.trig.gz";
    file_pattern="Thread-*${this_domain}*20220818*-[0-9][0-9][0-9][0-9]*.rdf.normalized.ttl.trig.gz"
    
    ! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
    # we did it wrong (logging progress to convertRDF4import_normal-files-processing-20220519-14h21m44s.log )
    if [ $( ls $file_pattern 2> /dev/null | wc -l ) -gt 0 ];then
      log_process="import_rdf2trig.gz4docker-fuseki-app-${this_domain}-$this_datetime.log"
      log_import="Import_GRAPH-${this_domain}_$this_datetime.log"
      echo "# Import /import-data/$log_import, processing: ${PWD}/$log_process"
      echo "# /import-data/bin/import_rdf2trig.gz4docker-fuseki-app.sh -d CETAF-IDs -w $working_directory -g http://${graph_domain_and_optional_path} -u ${this_domain} -s \"$file_pattern\" -l \"$log_import\" < answer-yes.txt  > \"$log_process\" 2>&1"
      /import-data/bin/import_rdf2trig.gz4docker-fuseki-app.sh \
        -d CETAF-IDs \
        -w $working_directory \
        -g http://${graph_domain_and_optional_path} \
        -u ${this_domain} \
        -s "$file_pattern" \
        -l "$log_import" < answer-yes.txt  > "$log_process" 2>&1 
    else
      echo "# Import: Nothing found with $file_pattern"
    fi
    echo "# - - - End import $this_domain (for http://${graph_domain_and_optional_path}) of $this_datetime at $(date '+%Y%m%d-%Hh%Mm%Ss') ..."
   done


    echo "# - - - End all imports at $(date '+%Y%m%d-%Hh%Mm%Ss') ..."

