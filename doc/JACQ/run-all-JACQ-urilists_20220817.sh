#!/bin/bash
set -eu
  # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
  # set -e -- option will cause a bash script to exit immediately when a command fails
  # set -o -- exit also on non-existing command, print also BASH settings
  # set -u -- this option causes the bash shell to treat unset variables as an error and exit immediately.
  # set -x -- the -x option causes bash to print each command before executing it. This can be a great help when trying to debug a bash script failure. Note that arguments get expanded before a command gets printed, which will cause our logs to contain the actual argument values that were present at the time of execution!
  # set -E -- traps are pieces of code that fire when a bash script catches certain signals. Aside from the usual signals (e.g. SIGINT, SIGTERM, …), traps can also be used to catch special bash signals like EXIT, DEBUG, RETURN, and ERR. However, reader Kevin Gibbs pointed out that using -e without -E will cause an ERR trap to not fire in certain scenarios.

# domain_list="admont.jacq.org bak.jacq.org boz.jacq.org bp.jacq.org brnu.jacq.org dr.jacq.org ere.jacq.org gat.jacq.org gjo.jacq.org gzu.jacq.org hal.jacq.org je.jacq.org kiel.jacq.org lagu.jacq.org lz.jacq.org mjg.jacq.org piagr.jacq.org pi.jacq.org prc.jacq.org tbi.jacq.org tub.jacq.org ubt.jacq.org willing.jacq.org w.jacq.org wu.jacq.org"
domain_list="dr.jacq.org ere.jacq.org gat.jacq.org gjo.jacq.org gzu.jacq.org hal.jacq.org je.jacq.org kiel.jacq.org lagu.jacq.org lz.jacq.org mjg.jacq.org piagr.jacq.org pi.jacq.org prc.jacq.org tbi.jacq.org tub.jacq.org ubt.jacq.org willing.jacq.org w.jacq.org wu.jacq.org"
domain_first=${domain_list%% *}
domain_last=${domain_list##* }
urilist_template="…domain…_urilist_JACQ_20220815_sorted.txt"; # replace …domain… by actual domain
n_jobs=15
# this_domain=data.biodiversitydata.nl
this_wd=/opt/jena-fuseki/import-sandbox/rdf/JACQ
command_RDF4domain=get_RDF4domain_from_urilist_with_ETA.sh

urilist_log_search_pattern="$(echo ${urilist_template} | sed 's@…domain…@*@; s@.txt@@')_${command_RDF4domain%.*}.log"


echo "# Running JACQ urilists from $domain_first .. to $domain_last (for running urilists see in ${urilist_log_search_pattern}, starting at $(date '+%Y%m%d-%Hh%Mm%Ss')) …"

# from BGBM-SQL01
for this_domain in ${domain_list}; do
  cd "${this_wd}";
  this_urilist=$(echo $urilist_template | sed "s@…domain…@${this_domain}@" );
  this_script_logfile="${this_urilist%.*}_${command_RDF4domain%.*}.log"; 
  
  if [[ -e "${this_wd}/urilists/${this_urilist}" ]]; then
    echo "# Run for $this_domain at $(date '+%Y%m%d-%Hh%Mm%Ss') of $this_urilist (logging into ${this_script_logfile})";
    echo "# Run for $this_domain at $(date '+%Y%m%d-%Hh%Mm%Ss') of $this_urilist (logging into ${this_script_logfile})"  > "${this_script_logfile}";
    /opt/jena-fuseki/import-sandbox/bin/${command_RDF4domain} -u "${this_wd}/urilists/${this_urilist}" \
    -j $n_jobs -l \
    -d $this_domain >> "${this_script_logfile}" 2>&1;
    echo "#   Finished $this_domain and done somehow at $(date '+%Y%m%d-%Hh%Mm%Ss')";
    echo "# Finished $this_domain and done somehow at $(date '+%Y%m%d-%Hh%Mm%Ss')"  >> "${this_script_logfile}";
  else
    echo "# Failed to run $this_domain at $(date '+%Y%m%d-%Hh%Mm%Ss'): no urilist file ${this_wd}/urilists/${this_urilist} (logging into ${this_script_logfile})";
    echo "# Failed to run $this_domain at $(date '+%Y%m%d-%Hh%Mm%Ss'): no urilist file ${this_wd}/urilists/${this_urilist} (logging into ${this_script_logfile})"  > "${this_script_logfile}";
  fi
done
echo "# Done. Finnshed running JACQ urilists from $domain_first .. to $domain_last (end at $(date '+%Y%m%d-%Hh%Mm%Ss'))"

