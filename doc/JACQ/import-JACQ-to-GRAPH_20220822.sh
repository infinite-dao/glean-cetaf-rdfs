#!/bin/bash
set -eu
  # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
  # set -e -- option will cause a bash script to exit immediately when a command fails
  # set -o -- exit also on non-existing command, print also BASH settings
  # set -u -- this option causes the bash shell to treat unset variables as an error and exit immediately.
  # set -x -- the -x option causes bash to print each command before executing it. This can be a great help when trying to debug a bash script failure. Note that arguments get expanded before a command gets printed, which will cause our logs to contain the actual argument values that were present at the time of execution!
  # set -E -- traps are pieces of code that fire when a bash script catches certain signals. Aside from the usual signals (e.g. SIGINT, SIGTERM, …), traps can also be used to catch special bash signals like EXIT, DEBUG, RETURN, and ERR. However, reader Kevin Gibbs pointed out that using -e without -E will cause an ERR trap to not fire in certain scenarios.

if grep -q docker /proc/1/cgroup; then 
    echo -e  "# \e[32mOK\e[0m inside docker. Import JACQ domains..."
else
   echo -e  "# \e[31mError:\e[0m script is executet on host but needs to run inside docker (stop)."
   echo -e  "#        You can enter the docker container by «docker exec -it containername bash», e.g. docker exec -it fuseki-app bash"
   exit
fi

# docker exec -it fuseki-app bash
  working_directory=/import-data/rdf/JACQ; 
  cd $working_directory
  # ---  
  # get one liner including /object
  # sed -r --silent '/https?.*\/object\// { s@(https?://)([^/[:space:],]+/object)/.+@\2@; p }; /https?:\/\/[^/[:space:],]+\/[^[:space:],]+\b.*$/ {  s@(https?://)([^/]+)/.+@\2@; p }' $this_urilist | sort | uniq -c | sed -r 's@[[:space:]]+[[:digit:]]+[[:space:]]+([[:graph:]]+)@\1@; /./{H;$!d} ; x ; s@\n@ @g; s@^[[:space:]]+@@'
  # admont.jacq.org bak.jacq.org boz.jacq.org bp.jacq.org brnu.jacq.org dr.jacq.org ere.jacq.org gat.jacq.org gjo.jacq.org gzu.jacq.org hal.jacq.org je.jacq.org kiel.jacq.org lagu.jacq.org/object lz.jacq.org mjg.jacq.org piagr.jacq.org pi.jacq.org prc.jacq.org tbi.jacq.org/object tub.jacq.org ubt.jacq.org willing.jacq.org/object w.jacq.org wu.jacq.org
  
  for graph_domain_and_optional_path in admont.jacq.org bak.jacq.org boz.jacq.org bp.jacq.org brnu.jacq.org dr.jacq.org ere.jacq.org gat.jacq.org gjo.jacq.org gzu.jacq.org hal.jacq.org je.jacq.org kiel.jacq.org lagu.jacq.org/object lz.jacq.org mjg.jacq.org piagr.jacq.org pi.jacq.org prc.jacq.org tbi.jacq.org/object tub.jacq.org ubt.jacq.org willing.jacq.org/object w.jacq.org wu.jacq.org;do
    this_domain=$(echo $graph_domain_and_optional_path | sed -r 's@/.+$@@' )
    this_datetime=$(date '+%Y%m%d-%Hh%Mm%Ss')
    echo "# - - - Start import $this_domain (for http://${graph_domain_and_optional_path}) at $this_datetime ..."

    file_pattern="Thread-*${this_domain}*202208*-[0-9][0-9][0-9][0-9]_modified.rdf.normalized.ttl.trig.gz";

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

