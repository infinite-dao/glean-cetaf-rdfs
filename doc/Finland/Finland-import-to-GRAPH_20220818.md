# Help for Documentation

```bash
pandoc -f gfm --toc -s Finland-import-to-GRAPH_20220818.md -o Finland-import-to-GRAPH_20220818-with-TOC.md # to generate TOC
```
# Import (2022-08-18)
## Prepare Data 

Get urilist data from GBIF or from internally harvsted GBIF Index of GUIDs of occurrence id, export those as CSV or better TSV (tab separated values). In this example we took only URI data that were not yet imported (~1700 URIs), the Finland data have about 1 million URIs at the present. And also we decided to include only botanical data.


```sql
# BGBM-SQL04 -- internally harvsted GBIF Index of GUIDs
SELECT occurrenceID
  FROM [syn_raw].[dbo].[cetaf_ids]
  WHERE inst in ('Helsinki', 'OtherFinl', 'OULU') AND kingdom NOT LIKE 'Animalia'
  ORDER BY occurrenceID
  
# BGBM-SQL01 -- internally harvsted GBIF Index of GUIDs -- get all URI and some fields for sorting afterwards
SELECT neu.occurrenceID, neu.inst, neu.kingdom
FROM cetaf_ids neu
  LEFT JOIN cetaf_ids_alt alt ON alt.bioRecordKey=neu.bioRecordKey
WHERE alt.bioRecordKey is NULL
  AND neu.inst in ('Helsinki', 'OtherFinl', 'OULU')
  AND neu.kingdom NOT LIKE 'Animalia'
-- GROUP BY neu.inst, neu.kingdom
ORDER BY neu.inst neu.kingdom  
```

Get data as tab separated values (tsv).

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
this_urilist="urilist_Finland-all-inst_20220818.tsv"
sed --in-place 's@\r@@g' "${this_urilist}" # remove problematic carriage return
head  "${this_urilist}"
# http://id.luomus.fi/MY.11135777 Helsinki        Plantae
# http://id.luomus.fi/MY.11135781 Helsinki        Plantae
# http://id.herb.oulu.fi/MY.12028800      OULU    Plantae
# http://id.herb.oulu.fi/MY.12045827      OULU    Plantae
# http://tun.fi/JX.1004912#21     OtherFinl       incertae sedis
# http://tun.fi/JX.1023434#4      OtherFinl       Fungi

# check comma counts or tab counts
sed 's@[^\t]@@g; s@[[:space:]]@t@g' "${this_urilist}" | sort | uniq -c | sed 's@^@# @'
```

# Harvest Data
## Split Data

We want imports to be separated by named graphs and in case of Finland, the following pattern was found to separate into graphs use it right away:

- Helsinki - http://id.luomus.fi
- OULU - http://id.herb.oulu.fi
- OtherFinl - http://tun.fi

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/Finland

# primary data have inst: Helsinki, OtherFinl, OULU
this_urilist_csv_or_tsv=urilist_Finland-all-inst_20220818.tsv
for inst in Helsinki OtherFinl OULU; do
  new_urilist_by_inst=urilist_20220818_${inst}.tsv
  echo "# write $new_urilist_by_inst (into a tab separated file) …" # add tab as well
  sed -r --silent "/${inst}/{ s@[,[:space:]](${inst})[,[:space:]](.+)@\t\1\t\2@ p}" "$this_urilist_csv_or_tsv" > "$new_urilist_by_inst"
done
  # write urilist_20220818_Helsinki.tsv (into a tab separated file) …
  # write urilist_20220818_OtherFinl.tsv (into a tab separated file) …
  # write urilist_20220818_OULU.tsv (into a tab separated file) …
```

Harvest and run all urilists, write a shell script:

```bash
./run-Finland-all-urilists_20220818.sh > run-Finland-all-urilists_20220818.log 2>&1 &  # try run through all domains using 10 parallel connections
# [1] 32378
tail run-Finland-all-urilists_20220818.log
# cat run-Finland-all-urilists_20220818.log

tail get_RDF4domain_from_urilist_with_ETA_urilist_20220818_Helsinki.log
  # Run id.luomus.fi of urilist_20220818_Helsinki.tsv at 20220818-14:46:30 (logging into get_RDF4domain_from_urilist_with_ETA_urilist_20220818_Helsinki.log)
  # Running 1766 jobs. See progress log files:
    tail Thread-XX_id.luomus.fi_20220818-1446.log       # logging all progress or
    tail Thread-XX_id.luomus.fi_20220818-1446_error.log # loggin errors only: 404 500 aso.
  # ------------------------------
  # To interrupt all the downloads in progress you have to:
  #   (1) kill process ID (PID) of get_RDF4domain_from_urilist_with_ETA.sh, find it by:
  #       ps -fp $( pgrep -d, --full get_RDF4domain_from_urilist_with_ETA.sh ) 
  #   (2) kill process ID (PID) of /usr/bin/perl parallel, find it by:
  #       ps -fp $( pgrep -d, --full parallel ) 

tail get_RDF4domain_from_urilist_with_ETA_urilist_20220818_OtherFinl.log
tail get_RDF4domain_from_urilist_with_ETA_urilist_20220818_OULU.log
```

## Get summary of “Done…” and summary of Errors

| Logfile | Timestamp | Jobs counted |
|-----------------------------------------------------|-----------------|------------|
|  Thread-XX_id.herb.oulu.fi_20220818-1519.log.gz  …  |  20220818-1519  |  Done.  704   jobs took 0d 00h:08m:59s using 10 parallel connections |
|  Thread-XX_id.herb.oulu.fi_20220818-1524.log.gz  …  |  20220818-1524  |  Done.  704   jobs took 0d 00h:05m:28s using 10 parallel connections |
|  Thread-XX_id.luomus.fi_20220818-1443.log.gz     …  |  20220818-1443  |  Done.  1766  jobs took 0d 00h:17m:36s using 10 parallel connections |
|  Thread-XX_id.luomus.fi_20220818-1446.log.gz     …  |  20220818-1446  |  Done.  1766  jobs took 0d 00h:23m:15s using 10 parallel connections |
|  Thread-XX_tun.fi_20220818-1501.log.gz           …  |  20220818-1501  |  Done.  1134  jobs took 0d 00h:18m:08s using 10 parallel connections |
|  Thread-XX_tun.fi_20220818-1509.log.gz           …  |  20220818-1509  |  Done.  1134  jobs took 0d 00h:15m:00s using 10 parallel connections |

```bash
# during get_RDF4domain… the Done-summary had no time calculation so get timestamps from log of "Started:" and "Ended:" and calculate anew
# use *.log.gz (assuming finished downloads)
./check-Done-status-and-errors.sh 
# check Thread-XX_id.herb.oulu.fi_20220818-1519.log.gz …
# check Thread-XX_id.herb.oulu.fi_20220818-1524.log.gz …
# check Thread-XX_id.luomus.fi_20220818-1443.log.gz …
# check Thread-XX_id.luomus.fi_20220818-1446.log.gz …
# check Thread-XX_tun.fi_20220818-1501.log.gz …
# check Thread-XX_tun.fi_20220818-1509.log.gz …
```


## Count errors and OK ones

```bash
for this_uri_log_file in Thread-XX*.log.gz;do 
  zcat "$this_uri_log_file" \
  | sed --silent --regexp-extended '/https?:\/\/[^\/]+\//{s@.+(https?://[^/]+/)[^ ]+ +(Codes:.+)@\1CETAF-ID... \2@p};' \
  | sort | uniq -c \
  | sed -r "s@^@# @; s@([[:digit:]]+) (http)@\1 (${this_uri_log_file}) \2@;"
done
#       3 (Thread-XX_id.herb.oulu.fi_20220621-0656.log.gz) http://id.herb.oulu.fi/CETAF-ID... Codes: ERROR: 404 ;
#   66019 (Thread-XX_id.herb.oulu.fi_20220621-0656.log.gz) http://id.herb.oulu.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#     704 (Thread-XX_id.herb.oulu.fi_20220818-1524.log.gz) http://id.herb.oulu.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#  250000 (Thread-XX_id.luomus.fi_20220616-1704.log.gz) http://id.luomus.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#  250000 (Thread-XX_id.luomus.fi_20220617-1523.log.gz) http://id.luomus.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#    1176 (Thread-XX_id.luomus.fi_20220618-1248.log.gz) http://id.luomus.fi/CETAF-ID... Codes: ERROR: 404 ;
#  137221 (Thread-XX_id.luomus.fi_20220618-1248.log.gz) http://id.luomus.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#    1766 (Thread-XX_id.luomus.fi_20220818-1446.log.gz) http://id.luomus.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#       6 (Thread-XX_tun.fi_20220619-0018.log.gz) http://tun.fi/CETAF-ID... Codes: ERROR: 404 ;
#       4 (Thread-XX_tun.fi_20220619-0018.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;ERROR: 502 Proxy Error;
#  249990 (Thread-XX_tun.fi_20220619-0018.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#       1 (Thread-XX_tun.fi_20220620-0116.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;ERROR: No data received.;OK: 200 ;
#  249961 (Thread-XX_tun.fi_20220620-0116.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#      38 (Thread-XX_tun.fi_20220620-0116.log.gz) http://tun.fi/CETAF-ID... Codes: unknown. 
#   29039 (Thread-XX_tun.fi_20220621-0415.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
#    1134 (Thread-XX_tun.fi_20220818-1509.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
```

# Validate Data
## Fix RDF before validate

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
file_pattern='Thread-*20220818*-[0-9][0-9][0-9][0-9].rdf.gz'
! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
this_datetime=$(date '+%Y%m%d-%Hh%Mm%Ss')
/opt/jena-fuseki/import-sandbox/bin/fixRDF_before_validateRDFs.sh -s "$file_pattern"  < answer-yes.txt > fixRDF_before_validateRDFs_Finland_${this_datetime}.log 2>&1 &
# [1] 2083
tail fixRDF_before_validateRDFs_Finland_${this_datetime}.log
# Time Started: 2022-08-18 16:28:47+02:00
# Time Ended:   2022-08-18 16:31:30+02:00
```

## RDF Validation

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
file_pattern='Thread-*20220818*-[0-9][0-9][0-9][0-9]_modified.rdf.gz'
! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
this_datetime=$(date '+%Y%m%d-%Hh%Mm%Ss')
/opt/jena-fuseki/import-sandbox/bin/validateRDFs.sh -s "$file_pattern" -l "validate_RDF_all-Finland-$this_datetime.log"  < answer-yes.txt > validate_RDF_all-Finland-processing_${this_datetime}.log 2>&1 &

  echo "validate_RDF_all-Finland-$this_datetime.log"
  # validate_RDF_all-Finland-20220818-16h41m01s.log
  
  grep -i 'warn' "validate_RDF_all-Finland-$this_datetime.log" | sed -r 's@.+Thread.+::.+(::.+)@\1@; s@::\s+\[line[^][]+\]\s+\{[^{}]+\}\s+@@;' | sort | uniq -c  | sed 's@^@  # @'
  # OK
```


# Normalisation

- 70 files takes about 1h:32min:44sec to 2h:0min:10sec

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
[ $(ls *_modified.rdf*warn-or-error.log* 2> /dev/null | wc -l) -gt 0 ] && rm *_modified.rdf*warn-or-error.log*

file_pattern='Thread-*20220818*-[0-9][0-9][0-9][0-9]_modified.rdf.gz'
this_datetime=$(date '+%Y%m%d-%Hh%Mm%Ss')
! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
/opt/jena-fuseki/import-sandbox/bin/convertRDF4import_normal-files_Finland.sh -s "$file_pattern" < answer-yes.txt  > convertRDF4import_normal-files-processing-$this_datetime.log 2>&1 &
# [1] 13889
zcat *${file_pattern/%.gz/}*.log* | grep --color=always --ignore-case 'error\|warn'
tail -n 20 convertRDF4import_normal-files-processing-$this_datetime.log
```

# Pattern Split of Data (before Import)

For large data better split URIs into smaller set (above 200000 to 250000).

```bash
/opt/jena-fuseki/import-sandbox/rdf/Finland/patternsplit_id.luomus.fi.sh
/opt/jena-fuseki/import-sandbox/rdf/Finland/patternsplit_tun.fi.sh
# /opt/jena-fuseki/import-sandbox/doc/Finland/patternsplit_id.herb.oulu.fi.sh # not neccessary
```
 
# Check some Data

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
zgrep --max-count=2 'dwciri' *20220818*normalized*.gz
# nothing, no dwciri
zgrep --count 'associatedMedia' *20220818*normalized*.gz
# many associatedMedia
```


# Import into RDF Store

```bash
docker exec -it fuseki-app bash
# root@ec1d7223dd20:/jena-fuseki#   
  working_directory=/import-data/rdf/Finland; cd $working_directory
  ./import-Finland-to-GRAPH_20220818.sh > import-Finland-to-GRAPH_20220818.sh.$(date '+%Y%m%d-%Hh%Mm%Ss').log 2>&1 &
  # [1] 986
  cat import-Finland-to-GRAPH_20220818.sh.20220818-15h17m44s.log
  tail convertRDF4import_normal-files-processing-id.herb.oulu.fi-20220818-15h22m17s.log
  tail convertRDF4import_normal-files-processing-id.luomus.fi-20220818-15h17m45s.log
  tail convertRDF4import_normal-files-processing-tun.fi-20220818-15h24m06s.log
  # all OK
  # - - - Start import id.luomus.fi (for http://id.luomus.fi) at 20220818-15h17m45s ...
  # - - - End all imports at 20220818-15h31m50s ...
```

