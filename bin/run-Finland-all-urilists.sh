#!/bin/bash
# Description: Run RDF harvest through all urilists from gbif.fi one after another (i.e. contains also multiple institutions)
# Example files:
# urilist_Helsinki_20220616_per_01x250000.txt
# urilist_Helsinki_20220616_per_02x250000.txt
# urilist_Helsinki_20220616_per_03x250000.txt
# urilist_OtherFinl_20220616_per_01x250000.txt
# urilist_OtherFinl_20220616_per_02x250000.txt
# urilist_OtherFinl_20220616_per_03x250000.txt
# urilist_OULU_20220616_per_01x250000.txt

echo "# # # Run Finland Institutions Data at $(date '+%Y%m%d-%H:%M:%S') …"
command_RDF4domain=get_RDF4domain_from_urilist_with_ETA.sh
n_jobs=10
# this_domain=data.biodiversitydata.nl
this_wd=/opt/jena-fuseki/import-sandbox/rdf/Finland/
cd $this_wd;

for institute in Helsinki OtherFinl OULU; do
  for this_urilist in urilist_${institute}_20220616_per_*x250000.txt; do 
  this_script_logfile="${command_RDF4domain%.*}_${this_urilist%.*}.log";
    # logfile e.g.: get_RDF4domain_from_urilist_with_ETA_urilist_Helsinki_20220616_per_01x250000.log
  if [[ -e "${this_urilist}" ]]; then
    this_domain=$(sed --silent -r '/^https?/{ s@https?://([^/]+)/.+@\1@p; q }' "$this_urilist"); # get domain from first http-entry
    if [[ "$this_domain" == "" ]]; then 
      echo "# No domain found in $this_urilist at $(date '+%Y%m%d-%H:%M:%S'), skip step (logging into ${this_script_logfile})"  > "${this_script_logfile}";
      continue
    else 
      echo "# Run $this_domain of $this_urilist at $(date '+%Y%m%d-%H:%M:%S') (logging into ${this_script_logfile})"  > "${this_script_logfile}";
      /opt/jena-fuseki/import-sandbox/bin/${command_RDF4domain} -u "${this_urilist}" \
      -j $n_jobs -l \
      -d "$this_domain" >> "${this_script_logfile}" 2>&1;
      echo "# Finished $this_domain of $this_urilist and done somehow at $(date '+%Y%m%d-%H:%M:%S')"  >> "${this_script_logfile}";
    fi
  else
    echo "# Failed to read $this_urilist at $(date '+%Y%m%d-%H:%M:%S'): no harvest logging file"  > "${this_script_logfile}";
  fi
  done
done
echo "# # # Finished to run Finland Institutions Data at $(date '+%Y%m%d-%H:%M:%S') …"
