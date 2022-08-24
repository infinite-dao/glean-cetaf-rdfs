# Help for Documentation

```bash
pandoc -f gfm --toc -s JACQ-import-to-GRAPH.md -o JACQ-import-to-GRAPH_with-TOC.md # to generate TOC
```


# Import (2022-08-15)
## Prepare Data 

Get urilist data from GBIF or from internally harvsted GBIF Index of GUIDs of occurrence id, export those as CSV or better TSV (tab seperated values)

```sql
# BGBM-SQL04 -- internally harvsted GBIF Index of GUIDs
SELECT occurrenceID
  FROM [syn_raw].[dbo].[cetaf_ids]
  WHERE inst LIKE 'Jacq'
  ORDER BY occurrenceID;

# BGBM-SQL01 -- internally harvsted GBIF Index of GUIDs -- get all URI and some fields for sorting afterwards
SELECT [ObjectURI]
,[InstitutionCode]
,[HerbariumID]
  FROM [Herbar].[dbo].[trRdf_complete]
  WHERE ObjectURI LIKE '%.jacq.org%'
  ORDER BY InstitutionCode, HerbariumID
```

## Check if there are problematic data

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/JACQ/urilists
this_urilist="urilist_JACQ_20220815_todo_sorted.tsv"
this_urilist="urilist_JACQ_20220511.csv"
this_urilist="urilist_JACQ_20220815.csv"

sed --in-place 's@\r@@g' "${this_urilist}" # remove problematic carriage return

grep '"' "${this_urilist}" # check quotes


# check comma counts
sed 's@[^,]@@g' "${this_urilist}" | sort | uniq -c | sed 's@^@# @'
  sed --silent '/.*,.*,.*,.*,/p' "${this_urilist}" # check if tow many CSV comma
  sed --in-place '/.*,.*,.*,.*,/{d}' "${this_urilist}" # delete entries with 4 commata or more

# replace to tab seperated values and compare line counts
if [[ "${this_urilist}" == *.[cC][sS][vV] ]];then
  sed -r 's@^([^,]+),([^,]+),([^,]+)$@\1\t\2\t\3@g' "${this_urilist}" > "${this_urilist%.*}.tsv"
  echo -n "# ${this_urilist} " && cat "${this_urilist}" | wc -l
  echo -n "# ${this_urilist%.*}.tsv " && cat "${this_urilist%.*}.tsv" | wc -l
fi
  # urilist_JACQ_20220815.csv 1249251
  # urilist_JACQ_20220815.tsv 1249251
```

## Compare old and new lists

```bash
# Check for URI-Differences old list vs. new list (in general for CSV or TSV lists)
# ```bash
# comm -13 donelistsorted comparelistsorted > todolistsorted
# comm -13 donelistsorted comparelistsorted > todolistsorted
donelist_source=urilist_JACQ_20220511.tsv;
donelist_sorted=${donelist_source%.*}_sorted.tsv;
donelist_sorted_noprotocol=${donelist_source%.*}_sorted_noprotocol.tsv;

comparelist_source=urilist_JACQ_20220815.tsv;
comparelist_sorted=${comparelist_source%.*}_sorted.tsv;
comparelist_sorted_noprotocol=${comparelist_source%.*}_sorted_noprotocol.tsv;

todolist_sorted=${comparelist_source%.*}_todo.tsv;
todolist_sorted_noprotocol=${comparelist_source%.*}_todo_noprotocol.tsv;

# assume CSV (comma separated values) or TSV (tab separated values)
# assume to have URLs beginning at the line start and after it (word-boundary), any other text herein after gets ignored

# sed --silent --regexp-extended '/http/{ s@[[:space:]]*https?://([^[:space:],]+)\b.*$@\1@; p }'  "$donelist_source"    | sort > "$donelist_sorted_noprotocol"
  # compare by removing any protocol part (http:// https:// ftp:// sftp:// aso.)
  sed --silent --regexp-extended '/[[:alpha:]]+:\/\// { s@[[:space:]]*[[:alpha:]]+://([^[:space:],]+)\b.*$@\1@; p }'  "$donelist_source"    | sort > "$donelist_sorted_noprotocol"
  sed --silent --regexp-extended '/[[:alpha:]]+:\/\// { s@[[:space:]]*[[:alpha:]]+://([^[:space:],]+)\b.*$@\1@; p }'  "$comparelist_source" | sort > "$comparelist_sorted_noprotocol"
  comm -13 "$donelist_sorted_noprotocol" "$comparelist_sorted_noprotocol" > "$todolist_sorted_noprotocol";
  grep --count "/" "$todolist_sorted_noprotocol"; # 222353  

# sed --silent --regexp-extended '/http/{ s@[[:space:]]*(https?://[^[:space:]]+)\b.*$@\1@; p }'  "$donelist_source"    | sort > "$donelist_sorted"
  sed --silent --regexp-extended '/[[:alpha:]]+:\/\// { s@[[:space:]]*([[:alpha:]]+://[^[:space:],]+)\b.*$@\1@; p }'  "$donelist_source"    | sort > "$donelist_sorted"
  sed --silent --regexp-extended '/[[:alpha:]]+:\/\// { s@[[:space:]]*([[:alpha:]]+://[^[:space:],]+)\b.*$@\1@; p }'  "$comparelist_source" | sort > "$comparelist_sorted"
  comm -13 "$donelist_sorted" "$comparelist_sorted" > "$todolist_sorted";
  grep --count "/" "$todolist_sorted"; # 222366
# ```
```

## Split Data into Domains

For the later triple store import we want named GRAPHs, so we try to get an overview of all domains and split them accordingly.

```bash
# # # # # # # # # # # # #  
# count all domains
this_urilist=urilist_JACQ_20220815_todo_sorted.tsv
sed -r --silent '/^http/ { s@(https?://)([^/]+)/.+@\2@; p }' $this_urilist | sort | uniq -c | sed 's@^@# @'
# sed -r --silent '/^http/ { s@(https?://)([^/]+|[^/]+/object)/.+@\2@; p }' $this_urilist | sort | uniq -c | sed 's@^@# @'
# sed -r --silent '/http/  { s@.*https?://([^/[:space:]]+)/[^/[:space:]]+[[:space:]]+.*$@\1@; p }' $this_urilist | sort | uniq -c | sed 's@^@# @'
#     590 admont.jacq.org
#     146 bak.jacq.org
#       7 boz.jacq.org
#       1 bp.jacq.org
#    5869 brnu.jacq.org
#   47632 dr.jacq.org
#     243 ere.jacq.org
#    6322 gat.jacq.org
#    4780 gjo.jacq.org
#    4463 gzu.jacq.org
#   15903 hal.jacq.org
#     703 je.jacq.org
#      31 kiel.jacq.org
#     475 lagu.jacq.org
#   29114 lz.jacq.org
#   43134 mjg.jacq.org
#    1249 piagr.jacq.org
#    7058 pi.jacq.org
#    2554 prc.jacq.org
#      23 tbi.jacq.org
#    8897 tub.jacq.org
#   10177 ubt.jacq.org
#   20437 willing.jacq.org
#    9955 w.jacq.org
#    2602 wu.jacq.org

# sed '/./{H;$!d} ; x ; s/REGEXP/REPLACEMENT/' # work through as if there were paragraphs
sed -r --silent '/^http/ { s@(https?://)([^/]+)/.+@\2@; p }' $this_urilist | sort | uniq -c | sed -r 's@[[:space:]]+[[:digit:]]+[[:space:]]+([[:graph:]]+)@\1@; /./{H;$!d} ; x ; s@\n@ @g; s@^[[:space:]]+@@'
# admont.jacq.org bak.jacq.org boz.jacq.org bp.jacq.org brnu.jacq.org dr.jacq.org ere.jacq.org gat.jacq.org gjo.jacq.org gzu.jacq.org hal.jacq.org je.jacq.org kiel.jacq.org lagu.jacq.org lz.jacq.org mjg.jacq.org piagr.jacq.org pi.jacq.org prc.jacq.org tbi.jacq.org tub.jacq.org ubt.jacq.org willing.jacq.org w.jacq.org wu.jacq.org

# # # # # # # # # # # # #  
# count lll domains including …/object
sed -r --silent '/https?.*\/object\// { s@(https?://)([^/[:space:],]+/object)/.+@\2@; p }; /https?:\/\/[^/[:space:],]+\/[^[:space:],]+\b.*$/ {  s@(https?://)([^/]+)/.+@\2@; p }' $this_urilist | sort | uniq -c 
#     590 admont.jacq.org
#     146 bak.jacq.org
#       7 boz.jacq.org
#       1 bp.jacq.org
#    5869 brnu.jacq.org
#   47632 dr.jacq.org
#     243 ere.jacq.org
#    6322 gat.jacq.org
#    4780 gjo.jacq.org
#    4463 gzu.jacq.org
#   15903 hal.jacq.org
#     703 je.jacq.org
#      31 kiel.jacq.org
#     475 lagu.jacq.org/object
#   29114 lz.jacq.org
#   43134 mjg.jacq.org
#    1249 piagr.jacq.org
#    7058 pi.jacq.org
#    2554 prc.jacq.org
#      23 tbi.jacq.org/object
#    8897 tub.jacq.org
#   10177 ubt.jacq.org
#   20437 willing.jacq.org/object
#    9955 w.jacq.org
#    2602 wu.jacq.org

# get one liner domains including /object
sed -r --silent '/https?.*\/object\// { s@(https?://)([^/[:space:],]+/object)/.+@\2@; p }; /https?:\/\/[^/[:space:],]+\/[^[:space:],]+\b.*$/ {  s@(https?://)([^/]+)/.+@\2@; p }' $this_urilist | sort | uniq -c | sed -r 's@[[:space:]]+[[:digit:]]+[[:space:]]+([[:graph:]]+)@\1@; /./{H;$!d} ; x ; s@\n@ @g; s@^[[:space:]]+@@'
# admont.jacq.org bak.jacq.org boz.jacq.org bp.jacq.org brnu.jacq.org dr.jacq.org ere.jacq.org gat.jacq.org gjo.jacq.org gzu.jacq.org hal.jacq.org je.jacq.org kiel.jacq.org lagu.jacq.org/object lz.jacq.org mjg.jacq.org piagr.jacq.org pi.jacq.org prc.jacq.org tbi.jacq.org/object tub.jacq.org ubt.jacq.org willing.jacq.org/object w.jacq.org wu.jacq.org
```


We later want one GRAPH per domain, so split domains into seperate files:

```bash
this_urilist=urilist_JACQ_20220815_todo_sorted.tsv

for domain in admont.jacq.org bak.jacq.org boz.jacq.org bp.jacq.org brnu.jacq.org dr.jacq.org ere.jacq.org gat.jacq.org gjo.jacq.org gzu.jacq.org hal.jacq.org je.jacq.org kiel.jacq.org lagu.jacq.org lz.jacq.org mjg.jacq.org piagr.jacq.org pi.jacq.org prc.jacq.org tbi.jacq.org tub.jacq.org ubt.jacq.org willing.jacq.org w.jacq.org wu.jacq.org; do
  domain_urilist=${domain}_urilist_JACQ_20220815_sorted.txt
  echo "# write $domain to urilist $domain_urilist …"
  sed --silent "/${domain}/{p}" "$this_urilist" >  "$domain_urilist"
done
# (this is very slow domain extraction and) does not scale to loop with for through
# for uri in $(cat  urilist_JACQ_20220511_sorted.txt);do
#   domain=$(echo $uri | sed -r 's@https?://([^/]+)/.+@\1@;');
#   echo $uri >> ${domain}_urilist_JACQ_20220511_sorted.txt
# done
```

# Harvest Data

1. write a script to run all JACQ, see `run-all-JACQ-urilists_20220817.sh`
2. run script `run-all-JACQ-urilists_20220817.sh` in the background
3. log out of ssh session perhaps to prevent an interruption of the running background processes, and log in again to check if it is running. But sometimes the harvesting process gets interuptey by no given reason.


```bash
cd /opt/jena-fuseki/import-sandbox/rdf/JACQ

./run-all-JACQ-urilists_20220817.sh > run-all-JACQ-urilists_20220817.log 2>&1 & # try run through all domains using 15 parallel connections
  # [1] 10547
  # exit ssh session an log in again
tail run-all-JACQ-urilists_20220817.log
ls *_urilist_JACQ_20220815_sorted_get_RDF4domain_from_urilist_with_ETA.log
```


## Get Summary of “Done…” and Summary of Errors

```bash
# during get_RDF4domain… the Done-summary had no time calculation so get timestamps from log of "Started:" and "Ended:" and calculate anew
./check-Done-status-and-errors.sh
```

| urilist                                           |   datetime    |  notes |
|---------------------------------------------------|---------------|-----------------------|
|  Thread-XX_admont.jacq.org_20220817-1154.log.gz   …  |  20220817-1154  |  Done.  590    jobs took 0d 00h:00m:10s using 15 parallel connections |
|  Thread-XX_bak.jacq.org_20220817-1154.log.gz      …  |  20220817-1154  |  Done.  146    jobs took 0d 00h:01m:51s using 15 parallel connections |
|  Thread-XX_boz.jacq.org_20220817-1156.log.gz      …  |  20220817-1156  |  Done.  7      jobs took 0d 00h:00m:04s using 15 parallel connections |
|  Thread-XX_bp.jacq.org_20220817-1156.log.gz       …  |  20220817-1156  |  Done.  1      jobs took 0d 00h:00m:00s using 15 parallel connections, having URI-Errors: 1 |
|  Thread-XX_brnu.jacq.org_20220817-1156.log.gz     …  |  20220817-1156  |  Done.  5869   jobs took 0d 01h:03m:10s using 15 parallel connections, having URI-Errors: 30 |
|  Thread-XX_dr.jacq.org_20220817-1504.log.gz       …  |  20220817-1504  |  Done.  47632  jobs took 0d 08h:06m:03s using 15 parallel connections, having URI-Errors: 7 |
|  Thread-XX_ere.jacq.org_20220817-2310.log.gz      …  |  20220817-2310  |  Done.  243    jobs took 0d 00h:02m:32s using 15 parallel connections, having URI-Errors: 1 |
|  Thread-XX_gat.jacq.org_20220817-2313.log.gz      …  |  20220817-2313  |  Done.  6322   jobs took 0d 01h:03m:32s using 15 parallel connections |
|  Thread-XX_gjo.jacq.org_20220818-0017.log.gz      …  |  20220818-0017  |  Done.  4780   jobs took 0d 00h:51m:28s using 15 parallel connections |
|  Thread-XX_gzu.jacq.org_20220818-0108.log.gz      …  |  20220818-0108  |  Done.  4463   jobs took 0d 00h:46m:37s using 15 parallel connections, having URI-Errors: 1 |
|  Thread-XX_hal.jacq.org_20220818-0155.log.gz      …  |  20220818-0155  |  Done.  15903  jobs took 0d 02h:45m:42s using 15 parallel connections, having URI-Errors: 4 |
|  Thread-XX_je.jacq.org_20220818-0440.log.gz       …  |  20220818-0440  |  Done.  703    jobs took 0d 00h:08m:36s using 15 parallel connections |
|  Thread-XX_kiel.jacq.org_20220818-0449.log.gz     …  |  20220818-0449  |  Done.  31     jobs took 0d 00h:00m:20s using 15 parallel connections |
|  Thread-XX_lagu.jacq.org_20220818-0449.log.gz     …  |  20220818-0449  |  Done.  475    jobs took 0d 00h:05m:25s using 15 parallel connections |
|  Thread-XX_lz.jacq.org_20220818-0455.log.gz       …  |  20220818-0455  |  Done.  29114  jobs took 0d 04h:29m:02s using 15 parallel connections, having URI-Errors: 1691 |
|  Thread-XX_mjg.jacq.org_20220818-0924.log.gz      …  |  20220818-0924  |  Done.  43134  jobs took 0d 07h:17m:28s using 15 parallel connections |
|  Thread-XX_piagr.jacq.org_20220818-1641.log.gz    …  |  20220818-1641  |  Done.  1249   jobs took 0d 00h:14m:01s using 15 parallel connections |
|  Thread-XX_pi.jacq.org_20220818-1655.log.gz       …  |  20220818-1655  |  Done.  7058   jobs took 0d 01h:09m:02s using 15 parallel connections |
|  Thread-XX_prc.jacq.org_20220818-1804.log.gz      …  |  20220818-1804  |  Done.  2554   jobs took 0d 00h:24m:03s using 15 parallel connections, having URI-Errors: 1 |
|  Thread-XX_tbi.jacq.org_20220818-1829.log.gz      …  |  20220818-1829  |  Done.  23     jobs took 0d 00h:00m:13s using 15 parallel connections |
|  Thread-XX_tub.jacq.org_20220818-1829.log.gz      …  |  20220818-1829  |  Done.  8897   jobs took 0d 01h:26m:10s using 15 parallel connections |
|  Thread-XX_ubt.jacq.org_20220818-1955.log.gz      …  |  20220818-1955  |  Done.  10177  jobs took 0d 01h:36m:45s using 15 parallel connections |
|  Thread-XX_willing.jacq.org_20220818-2132.log.gz  …  |  20220818-2132  |  Done.  20437  jobs took 0d 03h:41m:23s using 15 parallel connections |
|  Thread-XX_w.jacq.org_20220819-0113.log.gz        …  |  20220819-0113  |  Done.  9955   jobs took 0d 01h:40m:58s using 15 parallel connections, having URI-Errors: 3 |
|  Thread-XX_wu.jacq.org_20220819-0254.log.gz       …  |  20220819-0254  |  Done.  2602   jobs took 0d 00h:34m:05s using 15 parallel connections |


## Check for Errors

```bash
  echo "" > this_temporary_list.txt
  for this_logfile in Thread-XX_*_202208[0-9][0-9]-[0-9][0-9][0-9][0-9]_error.log;do 
    echo -n "# $this_logfile …" >> this_temporary_list.txt;
    echo -n "$this_logfile" | sed -r 's@Thread.+([[:digit:]]{8}-[[:digit:]]{4}).+@ # \1 @' >> this_temporary_list.txt
    echo -n "# URI-Errors: " >> this_temporary_list.txt; 
    cat "$this_logfile" | wc -l >> this_temporary_list.txt
  done
  cat this_temporary_list.txt | column -t | tr '#' '|'
  # |  Thread-XX_bak.jacq.org_20220518-1517_error.log   …  |  20220518-1517  |  URI-Errors:  1
  # …
  
URI_LOG_FILE=Thread-XX_xx-jacq.org_20220113-1511.log
URI_LOG_FILE=Thread-XX_*_202208[0-9][0-9]-[0-9][0-9][0-9][0-9]_error.log
sed --silent --regexp-extended '/https?:\/\/[^\/]+\//{s@.+(https?://[^/]+/)[^ ]+ +(Codes:.+)@| \1CETAF-ID... | \2@p};' $URI_LOG_FILE \
  | sort | uniq -c | \
  sed 's@^@| @;s@$@ |@' > this_temporary_list.txt
column -t this_temporary_list.txt | sed -r '/Codes:/{ :label.space; s@(Codes:.*)\s{2}@\1 @; tlabel.space; }; s@^@# @'
```


|  counts | domain                            | Codes of ERROR |
|---------|-----------------------------------|------------------------------|
|  1     |  https://bp.jacq.org/CETAF-ID...    |  Codes: ERROR: 404 Not Found; |
|  30    |  https://brnu.jacq.org/CETAF-ID...  |  Codes: OK: 303 See Other;ERROR: 404 Not Found; |
|  7     |  https://dr.jacq.org/CETAF-ID...    |  Codes: OK: 303 See Other;ERROR: 404 Not Found; |
|  1     |  https://ere.jacq.org/CETAF-ID...   |  Codes: OK: 303 See Other;ERROR: 404 Not Found; |
|  1     |  https://gzu.jacq.org/CETAF-ID...   |  Codes: OK: 303 See Other;ERROR: 404 Not Found; |
|  4     |  https://hal.jacq.org/CETAF-ID...   |  Codes: OK: 303 See Other;ERROR: 404 Not Found; |
|  1691  |  https://lz.jacq.org/CETAF-ID...    |  Codes: OK: 303 See Other;ERROR: 404 Not Found; |
|  1     |  https://prc.jacq.org/CETAF-ID...   |  Codes: OK: 303 See Other;ERROR: 404 Not Found; |
|  3     |  https://w.jacq.org/CETAF-ID...     |  Codes: OK: 303 See Other;ERROR: 404 Not Found; |


Decisions:
- removed bp.jacq.org entirely `rm *bp.jacq*.gz` (keep error log)
- remaining errors ignored: URIs should be corrected


# Valdate Data
## Step Fix Data

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/JACQ
file_pattern='Thread-*202208*-[0-9][0-9][0-9][0-9].rdf.gz'
! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
/opt/jena-fuseki/import-sandbox/bin/fixRDF_before_validateRDFs.sh -s "$file_pattern"  < answer-yes.txt > fixRDF_before_validateRDFs_JACQ_$(date '+%Y%m%d-%Hh%Mm%Ss').log 2>&1 &
# [1] 11735
  tail fixRDF_before_validateRDFs_JACQ_20220822-09h46m53s.log
  tail fixRDF_before_validateRDFs_JACQ_20220822-10h06m49s.log
```


## Step Validation

```bash
file_pattern='Thread-*202208*-[0-9][0-9][0-9][0-9]_modified.rdf.gz' # take _modified
/opt/jena-fuseki/import-sandbox/bin/validateRDFs.sh -s "$file_pattern" -l "validate_RDF_all-JACQ-$(date '+%Y%m%d-%Hh%Mm%Ss').log" < answer-yes.txt  > validate_RDF_all-JACQ-processing-$(date '+%Y%m%d-%Hh%Mm%Ss').log 2>&1 &
cat validate_RDF_all-JACQ-20220822-10h12m47s.log
grep -i 'warn\|error' validate_RDF_all-JACQ-20220822-10h12m47s.log
# Validate Thread-01_bp.jacq.org_20220817-1156_modified.rdf.gz :: 10:12:57 ERROR riot            :: [line: 1, col: 1 ] Premature end of file. 
# 1 errors found using the following command => rm *bp.jacq.org*
```

# Normalize Data

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/JACQ
[ $(ls *_modified.rdf*warn-or-error.log* 2> /dev/null | wc -l) -gt 0 ] && rm *_modified.rdf*warn-or-error.log*

file_pattern='Thread-*202208*-[0-9][0-9][0-9][0-9]_modified.rdf.gz'
! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
/opt/jena-fuseki/import-sandbox/bin/convertRDF4import_normal-files_JACQ.sh -s "$file_pattern" < answer-yes.txt  > convertRDF4import_normal-files-processing-$(date '+%Y%m%d-%Hh%Mm%Ss').log 2>&1 &
# [1] 5861
tail convertRDF4import_normal-files-processing-20220822-11h21m25s.log 

zcat *${file_pattern/%.gz/}*.log* | grep --color=always --ignore-case 'error\|warn' # OK, no warning or error
```
        
# Import into RDF Store
## Test Import Data (TBD Loader)

TODO

## Import via SOH - SPARQL over HTTP


```bash
docker exec -it fuseki-app bash
# root@ec1d7223dd20:/jena-fuseki#   
  working_directory=/import-data/rdf/JACQ; cd $working_directory
  ./import-JACQ-to-GRAPH_20220822.sh > import-JACQ-to-GRAPH_20220822.sh.$(date '+%Y%m%d-%Hh%Mm%Ss').log 2>&1 & # all graph
  # [1] 1503
exit
cd /opt/jena-fuseki/import-sandbox/rdf/JACQ
find . -maxdepth 1 -iname 'import_rdf2trig*log' -exec grep -H 'report status' '{}' ';' | column -t -s '#'
# NOTE convertRDF4import_normal-files-processing- → renamed to import_rdf2trig.gz4docker-fuseki-app-
  # ./import_rdf2trig.gz4docker-fuseki-app-admont.jacq.org-20220822-11h51m42s.log:    15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-bak.jacq.org-20220822-11h52m05s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-boz.jacq.org-20220822-11h52m16s.log:       07 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-brnu.jacq.org-20220822-11h52m18s.log:      15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-dr.jacq.org-20220822-12h00m35s.log:        15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-ere.jacq.org-20220822-12h13m07s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-gat.jacq.org-20220822-12h13m14s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-gjo.jacq.org-20220822-12h13m48s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-gzu.jacq.org-20220822-12h16m52s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-hal.jacq.org-20220822-12h19m26s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-je.jacq.org-20220822-12h21m02s.log:        15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-kiel.jacq.org-20220822-12h21m27s.log:      15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-lagu.jacq.org-20220822-12h21m30s.log:      15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-lz.jacq.org-20220822-12h22m03s.log:        15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-mjg.jacq.org-20220822-12h29m17s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-pi.jacq.org-20220822-12h34m42s.log:        15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-piagr.jacq.org-20220822-12h34m33s.log:     15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-prc.jacq.org-20220822-12h39m20s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-tbi.jacq.org-20220822-12h40m15s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-tub.jacq.org-20220822-12h40m20s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-ubt.jacq.org-20220822-13h11m29s.log:       15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-w.jacq.org-20220822-13h15m55s.log:         15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-willing.jacq.org-20220822-13h14m16s.log:   15 files report status “200 OK” (details see in log file below)
  # ./import_rdf2trig.gz4docker-fuseki-app-wu.jacq.org-20220822-13h23m23s.log:        15 files report status “200 OK” (details see in log file below)
```


# TODO
