<!-- TODO describe for GRAPH usage -->

# glean-cetaf-rdfs (BASH)

Collect and glean RDF data in parallel of stable identifiers of the Consortium of European Taxonomic Facilities (CETAF, ☞&nbsp;[cetaf.org](https://cetaf.org)) and prepare them for import into a SPARQL endpoint. For the documentation of <abbr title="Consortium of European Taxonomic Facilities">CETAF</abbr> identifiers read in&#8239;…
- the wiki ☞&nbsp;[cetafidentifiers.biowikifarm.net](https://cetafidentifiers.biowikifarm.net)
- the **C**ETAF **S**pecimen **P**review **P**rofile (CSPP) on ☞&nbsp;[cetafidentifiers.biowikifarm.net/wiki/CSPP](https://cetafidentifiers.biowikifarm.net/wiki/CSPP)

So in essence these are *C*ETAF *S*pecimen *P*review *P*rofile (CSPP)-identifiers for the preview a real specimen.

## Overview

Steps we do:
1. get RDF files from the internet and amass those simply in parallel each into a large file
2. fix large files to be formally correct XML/RDF
3. validate technically XML/RDF files
4. normalize and convert them to TriG[^Trig] format and modify them to the needs of the botany pilot project (add ROR-IDs, dcterms:hasPart, dcterms:conformsTo aso.)
5. import files into the RDF store (which is a docker-container of apache-jena-fuseki)

More technically:
```
0. get an URI list for gathering RDF data (e.g. from GBIF)

1. download RDF into:
   Thread-01….rdf
   Thread-02….rdf aso.

2. fixing …
   Thread-01….rdf          → archive to → Thread-01….rdf.gz 
   Thread-02….rdf          → archive to → Thread-02….rdf.gz
     ↓ 2. fix basically files
   Thread-01…_modified.rdf – further processing
   Thread-02…_modified.rdf – further processing

3. validation (jena-apache’s rdfxml --validate)

4. normalize …
   Thread-01…_modified.rdf
   Thread-02…_modified.rdf
     ↓ 4. normalize and modify files
   Thread-01…normalized.ttl.trig
   Thread-02…normalized.ttl.trig

5. importing … 
   Thread-01…normalized.ttl.trig via s-put (SOH - SPARQL over HTTP)
   Thread-02…normalized.ttl.trig via s-put (SOH - SPARQL over HTTP)
```
See also in directory [`./doc/`](./doc/) for some documented imports.

## Advise to Manage Data

Managing later many data sets at once and keep track of them in the triple store, we can help it by organizing our URI lists and data to belong to URLs which we name later to a named GRAPH-URL, e.g.:

- http://coldb.mnhn.fr/catalognumber/mnhn/p/ (Paris plants data set)
- http://coldb.mnhn.fr/catalognumber/mnhn/pc/ (Paris cryptogams data set)
- http://herbarium.bgbm.org/object/ (BGBM, Berlin all the data)
- in general, skip the ID-part from the CSPP-ID from the GUID delivered to GBIF occurrences, i.e. `http:// + URL-path-GUID`
- aso.

In that way we can query specific GRAPHs and delete, add or overwrite GRAPHs more easily.

## Dependencies

BASH
- cat, dateutils (for date diff), date, bc, find, gawk, grep, gunzip, gzip, parallel, sed, sort, uniq, wget
- scripts, and recommended steps up and until import:
  1. [`./get_RDF4domain_from_urilist_with_ETA.sh`](./bin/get_RDF4domain_from_urilist_with_ETA.sh)
  2. [`./fixRDF_before_validateRDFs.sh`](./bin/fixRDF_before_validateRDFs.sh)
  3. [`./validateRDFs.sh`](./bin/validateRDFs.sh)
  4. convert specifically for instiutions or project data sets, e.g.
     - [`./convertRDF4import_normal-files_JACQ.sh`](./bin/convertRDF4import_normal-files_JACQ.sh)
     - [`./convertRDF4import_normal-files_Finland.sh`](./bin/convertRDF4import_normal-files_Finland.sh)
     - [`./convertRDF4import_normal-files_Paris.sh`](./bin/convertRDF4import_normal-files_Paris.sh) aso.
     - optional: with the `gawk` program [`./patternsplit.awk`](./bin/patternsplit.awk) to split a large file into handy pieces (e.g. 50MB uncompressed RDF data)
  5. and eventually within the docker-fuseki app: [`./import_rdf2trig.gz4docker-fuseki-app.sh`](./bin/import_rdf2trig.gz4docker-fuseki-app.sh)

RDF checks
- Apache Jena Fuseki<br/>☞&nbsp;[jena.apache.org/download/](https://jena.apache.org/download/index.cgi)

SPARQL endpoint
- Apache Jena Fuseki Server<br/>e.g. ☞&nbsp;[hub.docker.com/r/stain/jena-fuseki/](https://hub.docker.com/r/stain/jena-fuseki/), i.e. 
  `jena-fuseki` from [stain/jena-docker](https://github.com/stain/jena-docker)

## (0) Getting Data

In any way you have to prepare and check available data first to deliver RDF from an URI aso.. If you get data lists from GBIF, you need to query the `occurrencID`, which GBIF defines it as *«a single globally unique identifier for the occurrence record as provided by the publisher»*, it can be characters or an URI. See also the technical documentation https://www.gbif.org/developer/occurrence#predicates — and to get only herbarium sheets or preserved specimens, and not just observations for instance, use the filter `basisOfRecord` with the value `"PRESERVED_SPECIMEN"`.

Another way of getting GBIF data basically is, using the normal (table) interface and click through the occurrences until you get a table and save it locally (“download”), here an example:

1. https://www.gbif.org/country/DE/about show data sets from Germany
2. select, e.g. Plantae (at OCCURRENCES PER KINGDOM)
3. you get a table view https://www.gbif.org/occurrence/search?country=DE&taxon_key=6 and can narrow further if you will (basis of record: *Preserved specimen*, publisher: *Botanical Garden and Museum Berlin* https://www.gbif.org/occurrence/search?basis_of_record=PRESERVED_SPECIMEN&country=DE&publishing_org=57254bd0-8256-11d8-b7ed-b8a03c50a862&taxon_key=6)
4. on the table header click on the 3 vertical points (⋮) then you can add/remove columns, and add `Occurrence ID`
5. then you can save (“download”) this filter combination and proceed to check for http-URI in the occurrencIDs

## (1) Download and Harvesting RDFs

In this example we organize all the data (the `/rdf`), and binaries (`./bin`) in `/opt/jena-fuseki/import-sandbox/` that can be read by all necessary users.

``` bash
# get RDF files, the urilist is a simple list, e.g. with CSPP-IDs like … 
#   https://dr.jacq.org/DR001571
#   https://dr.jacq.org/DR001583
#   https://dr.jacq.org/DR001584
#   https://dr.jacq.org/DR001585
# OR it can have comments too after space or tab character:
#   https://dr.jacq.org/DR001584 [space-character] any other information, column, comment or anything
#   https://dr.jacq.org/DR001585 [tabulator-character] any other information, column, comment or anything
# aso.

/opt/jena-fuseki/import-sandbox/bin/get_RDF4domain_from_urilist_with_ETA.sh -h # show help

# example call, that runs in background (data of https://www.jacq.org)
cd /opt/jena-fuseki/import-sandbox/rdf/JACQ


# run background job to get RDF
/opt/jena-fuseki/import-sandbox/bin/get_RDF4domain_from_urilist_with_ETA.sh \
  -u urilist_dr.jacq.org_20220112.txt \
  -j 10 -l \
  -d dr.jacq.org &
  # -u …… → a simple CSV/TSV/TXT list to read from the URIs
  # -j 10 → 10 jobs in parallel
  # -l    → log progress into log file (no console prompt before starting)
  # -d …… → is the label for the “domain“: “dr.jacq.org” to name log files and data files
```

### Split Huge URI Lists

One may choose to split huge lists of URIs (perhaps above 500.000) because they tend to be interrupted during the RDF gathering, so we split the URI-list into smaller packages. In this example we want to get overall ~12.000.000 RDF files from Paris (`pc` means cryptogams and `p` vascular plants, i.e. only plantish data from Paris URI parts: `…/pc/…` and `…/p/…`), to split the whole ~12.000.000 URIs in the list file `URI_List_Paris_pc-p_20220317.txt` we use `split` command as follows and split all records into parts of 500.000 lines each:

```bash
# command usage:
# split [OPTIONS] ... [FILE                               [PREFIX]]
# split [OPTIONS] ... URI_List_Paris_pc-p_20220317.txt    URIList20220317_pc-p_per_

# split up the p-collection
grep "http://coldb.mnhn.fr/catalognumber/mnhn/p/" URI_List_Paris_pc-p_20220317.csv \
  | split --verbose --numeric-suffixes=1 \
  --additional-suffix=x500000.txt \
  --suffix-length=2 \
  --lines=500000 - \
  URIList20220317_collection-p_per_
# creating file 'URIList20220317_collection-p_per_01x500000.txt'
# creating file 'URIList20220317_collection-p_per_02x500000.txt'
# creating file 'URIList20220317_collection-p_per_03x500000.txt'
# creating file 'URIList20220317_collection-p_per_04x500000.txt'
# creating file 'URIList20220317_collection-p_per_05x500000.txt'
# creating file 'URIList20220317_collection-p_per_06x500000.txt'
# creating file 'URIList20220317_collection-p_per_07x500000.txt'
# creating file 'URIList20220317_collection-p_per_08x500000.txt'
# creating file 'URIList20220317_collection-p_per_09x500000.txt'
# creating file 'URIList20220317_collection-p_per_10x500000.txt'
# creating file 'URIList20220317_collection-p_per_11x500000.txt'

# split up the pc-collection
grep "http://coldb.mnhn.fr/catalognumber/mnhn/pc/" URI_List_Paris_pc-p_20220317.csv \
  | split --verbose --numeric-suffixes=1 \
  --additional-suffix=x500000.txt \
  --suffix-length=2 \
  --lines=500000 - \
  URIList20220317_collection-pc_per_
# creating file 'URIList20220317_collection-pc_per_01x500000.txt'
```

Then harvesting of it could be done with, e. g. the first URI list `URIList20220317_collection-p_per_01x500000.txt`, like:

```bash
# mkdir --parents /opt/jena-fuseki/import-sandbox/rdf/Paris
cd /opt/jena-fuseki/import-sandbox/rdf/Paris

# we run it by using logging (-l) into files
# -u urilist
# -j number of parallel jobs
# -l do log into files
# -d “domain name” or “descriptor” (here with prefix to describe the steps)
/opt/jena-fuseki/import-sandbox/bin/get_RDF4domain_from_urilist_with_ETA.sh \
  -u URIList20220317_collection-p_per_01x500000.txt \
  -j 10 -l \
  -d 01x500000-coldb.mnhn.fr &
  
# Above script will also prompt informative messages for log files or breaking and interrupting all downloads
  tail Thread-XX_01x500000-coldb.mnhn.fr_20220317-1639.log       # logging all progress or
  tail Thread-XX_01x500000-coldb.mnhn.fr_20220317-1639_error.log # logging errors only: 404 500 etc.
# ------------------------------
# To interrupt all the downloads in progress you have to:
#   (1) kill process ID (PID) of get_RDF4domain_from_urilist_with_ETA.sh, find it by:
#       ps -fp $( pgrep -d, --full get_RDF4domain_from_urilist_with_ETA.sh )
#   (2) kill process ID (PID) of /usr/bin/perl parallel, find it by: 
#       ps -fp $( pgrep -d, --full parallel )
```


To run multiple urilist one after another, you can write a small script looping through different lists and let it run in the background, for instance:

```bash
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
/opt/jena-fuseki/import-sandbox/bin/run-Finland-all-urilists.sh \
  > run-Finland-all-urilists_$(date '+%Y%m%d-%Hh%Mm%Ss').log 2>&1 & 
  # [1] 1916 (this is the Process ID (could be stopped by "kill 1916"))
```


### Check Download Errors

Usually `get_RDF4domain_from_urilist_with_ETA.sh` will output an error log file containing URIs with any return code error 400 … 500

``` bash
# check for errors
sed --quiet --regexp-extended 's/^.*(ERROR:.*)/\1/p' Thread-X_data.nhm.ac.uk_20201111-1335.log \
  | sort | uniq  --count | sed 's@^@# @'
# 1071846 ERROR: 404 Not Found;
#      15 ERROR: 500 INTERNAL SERVER ERROR;                       # re-capture: works later on
#       7 ERROR: No data received.;OK: 200 OK;                    # re-capture: works later on
#       6 ERROR: No data received.;OK: 303 SEE OTHER;OK: 200 OK;
  
# get only the failed URIs
sed --quiet --regexp-extended 's@.*(https?://[^ ]+).*(ERROR:.*(INTERNAL SERVER ERROR|No data received).*)@\1 # \2@p' \
  Thread-X_data.nhm.ac.uk_20201111-1335.log \
  > data.nhm.ac.uk_occurrenceID_failedFrom_20201111-1335.txt

# get and count error codes of harvested Finland data (here using zipped *.log.gz)
for this_uri_log_file in Thread-XX*.log.gz;do 
  zcat "$this_uri_log_file" \
  | sed --silent --regexp-extended '/https?:\/\/[^\/]+\//{s@.+(https?://[^/]+/)[^ ]+ +(Codes:.+)@\1CETAF-ID... \2@p};' \
  | sort | uniq -c| sed -r "s@^@# @; s@([[:digit:]]+) (http)@\1 (${this_uri_log_file}) \2@;"
done
  #       3 (Thread-XX_id.herb.oulu.fi_20220621-0656.log.gz) http://id.herb.oulu.fi/CETAF-ID... Codes: ERROR: 404 ;
  #   66019 (Thread-XX_id.herb.oulu.fi_20220621-0656.log.gz) http://id.herb.oulu.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
  #  250000 (Thread-XX_id.luomus.fi_20220616-1704.log.gz) http://id.luomus.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
  #  250000 (Thread-XX_id.luomus.fi_20220617-1523.log.gz) http://id.luomus.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
  #    1176 (Thread-XX_id.luomus.fi_20220618-1248.log.gz) http://id.luomus.fi/CETAF-ID... Codes: ERROR: 404 ;
  #  137221 (Thread-XX_id.luomus.fi_20220618-1248.log.gz) http://id.luomus.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
  #       6 (Thread-XX_tun.fi_20220619-0018.log.gz) http://tun.fi/CETAF-ID... Codes: ERROR: 404 ;
  #       4 (Thread-XX_tun.fi_20220619-0018.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;ERROR: 502 Proxy Error;
  #  249990 (Thread-XX_tun.fi_20220619-0018.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
  #       1 (Thread-XX_tun.fi_20220620-0116.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;ERROR: No data received.;OK: 200 ;
  #  249961 (Thread-XX_tun.fi_20220620-0116.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
  #      38 (Thread-XX_tun.fi_20220620-0116.log.gz) http://tun.fi/CETAF-ID... Codes: unknown. 
  #   29039 (Thread-XX_tun.fi_20220621-0415.log.gz) http://tun.fi/CETAF-ID... Codes: OK: 303 ;OK: 200 ;
```

### Manage or Merging Data

If you want to condense and merge downloaded files into a less number of files, you can use the following parallel merging

``` bash
find . -iname 'Thread-*coldb.mnhn.fr*.rdf' | parallel -j5  cat {} ">>" Threads_import_{%}_$(date '+%Y%m%d').rdf
# e.g. the number of files get merged to -j5, i.e. 5 files …
# Thread-01_01x500000-coldb.mnhn.fr_20220317-2156_modified.rdf
# Thread-01_02x500000-coldb.mnhn.fr_20220318-1431_modified.rdf
# Thread-01_03x500000-coldb.mnhn.fr_20220320-1535_modified.rdf   …  -> Threads_import_1_20220406.rdf
# Thread-01_04x500000-coldb.mnhn.fr_20220320-2050_modified.rdf   …  -> Threads_import_2_20220406.rdf
# Thread-01_05x500000-coldb.mnhn.fr_20220321-0940_modified.rdf   …  -> Threads_import_3_20220406.rdf
# Thread-01_05x500000-coldb.mnhn.fr_20220321-1612_modified.rdf   …  -> Threads_import_4_20220406.rdf
# Thread-01_06x500000-coldb.mnhn.fr_20220321-1817_modified.rdf   …  -> Threads_import_5_20220406.rdf
# Thread-01_07x500000-coldb.mnhn.fr_20220321-2230_modified.rdf
# Thread-01_08x500000-coldb.mnhn.fr_20220322-1228_modified.rdf
# Thread-01_09x500000-coldb.mnhn.fr_20220323-0229_modified.rdf
# Thread-01_10x500000-coldb.mnhn.fr_20220323-0943_modified.rdf
# aso.
```

## (2) Cleaning and Fixing of Downloaded RDF

Proceed with:
1. run `fixRDF_before_validateRDFs.sh -h` to fix and clean the concatenated RDF files to be each a valid RDF
2. make sure the RDF prefixes are correct, this can take time depending on the input data

  - e.g. possible error: The prefix `foaf` for element "foaf:depiction" is not bound, used in data but not definded on top of the RDF
  
3. add missing RDF prefixes if possible

… and proceed with `validate.sh`

**1. Run the script**

``` bash
/opt/jena-fuseki/import-sandbox/bin/fixRDF_before_validateRDFs_modified.sh -h # show help

/opt/jena-fuseki/import-sandbox/bin/fixRDF_before_validateRDFs_modified.sh -s \
  'Thread-*x500000-coldb.mnhn.fr_202203[0-9][0-9]-[0-9][0-9][0-9][0-9].rdf.gz'

# Or run multiple files in the background (log terminal output to log file)
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
  file_pattern='Thread-*2022*-[0-9][0-9][0-9][0-9].rdf.gz'
  this_datetime=$(date '+%Y%m%d-%Hh%Mm%Ss');
  ! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
  /opt/jena-fuseki/import-sandbox/bin/fixRDF_before_validateRDFs.sh -s "$file_pattern" \
    < answer-yes.txt > fixRDF_before_validateRDFs_Finland_${this_datetime}.log 2>&1 &
  # [1] 29542 (this is the Process ID (could be stopped by "kill 29542"))
  tail fixRDF_before_validateRDFs_Finland_${this_datetime}.log # e.g. output:
  # …
  # Process 002 of 070 in Thread-01_id.luomus.fi_20220616-1704.rdf.gz …
  #    Still 69 job to do, estimated end 0day(s) 0h:9min:55sec
  #    Read out comperessd Thread-01_id.luomus.fi_20220616-1704.rdf.gz (4028279 bytes) using 
  #      zcat … > Thread-01_id.luomus.fi_20220616-1704_modified.rdf …
  #    Extract all <rdf:RDF …> to Thread-01_id.luomus.fi_20220616-1704_rdfRDF_headers_extracted.rdf ... 
  #    fix common errors (also check or fix decimalLatitude decimalLongitude data type) ... 
  #    fix RDF (tag ranges: XML-head; XML-stylesheet; DOCTYPE rdf:RDF aso.) ... 
  # …
  # Time Started: 2022-06-29 13:15:41+02:00
  # Time Ended:   2022-06-29 13:45:52+02:00
```

**2. Compare RDF headers**

`fixRDF_before_validateRDFs_modified.sh` will printout and log for checking RDF headers manually, to compare the prefixes side by side: from the first obtained RDF and after amassing RDFs.

This step could be skipped possibly as the script will merge all found RDF headers of one amassed harvest file. Bear in mind that theoretically one individual RDF could ascribe `dc:…` for one URI namespace and another individual RDF could use the same `dc:…` prefix but meaning another URI namespace but both may have merged into one file, in which case one has to take care manually for the right resolving URI namespace.

However, if you want to compare them, the output can be look like:

```bash
# -----------------------
# Compare RDF headers 070 of 070 based on Thread-10_tun.fi_20220621-0415.rdf.gz …
# -----------------------
# For checking unzippd modified files …
  sed --quiet --regexp-extended '/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/!b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\n  \1@g; s@\n\n@\n@g; p;
  }' 'Thread-10_tun.fi_20220621-0415_modified.rdf' \
  | pr --page-width 140 --merge --omit-header \
  'Thread-10_tun.fi_20220621-0415_rdfRDF_headers_extracted.rdf' -
# For checking zipped modified files …
 zcat Thread-10_tun.fi_20220621-0415_modified.rdf.gz | sed --quiet --regexp-extended '/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/!b rdf_anchor; 
    s@[[:space:]]+(xmlns:)@\n  \1@g; s@\n\n@\n@g; p;
  }' \
  | pr --page-width 140 --merge --omit-header \
  'Thread-10_tun.fi_20220621-0415_rdfRDF_headers_extracted.rdf' -
# <rdf:RDF                                                              <rdf:RDF
#   xmlns:dc="http://purl.org/dc/terms/"                                  xmlns:dc="http://purl.org/dc/terms/"
#   xmlns:dwc="http://rs.tdwg.org/dwc/terms/"                             xmlns:dwc="http://rs.tdwg.org/dwc/terms/"
#   xmlns:dwciri="http://rs.tdwg.org/dwc/iri/"                            xmlns:dwciri="http://rs.tdwg.org/dwc/iri/"
#   xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"                  xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"
#   xmlns:owl="http://www.w3.org/2002/07/owl"                             xmlns:owl="http://www.w3.org/2002/07/owl"
#   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"               xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
#   xmlns:rdfschema="http://www.w3.org/TR/2014/REC-rdf-schema-20140225/   xmlns:rdfschema="http://www.w3.org/TR/2014/REC-rdf-schema-20140225/
# >                                                                     
# <!-- *Initially* extracted RDF-headers from                           
#      Thread-10_tun.fi_20220621-0415.rdf.gz -->                          
```

**3. add missing RDF prefixes** — may be necessary depending on the data; must be done by hand.


## (3) Validation

Validate data with `validateRDF.sh` to check if each RDF file is technically correct, now we use the `_modified` files:

``` bash
/opt/jena-fuseki/import-sandbox/bin/validateRDFs.sh -h # show help
/opt/jena-fuseki/import-sandbox/bin/validateRDFs.sh -s \
  'Thread-*x500000-coldb.mnhn.fr_202203[0-9][0-9]-[0-9][0-9][0-9][0-9]_modified.rdf.gz'

# Or run multiple files in the background (log terminal output to log file)
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
  file_pattern='Thread-*2022*-[0-9][0-9][0-9][0-9]_modified.rdf.gz'
  ! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
  this_datetime=$(date '+%Y%m%d-%Hh%Mm%Ss')
  /opt/jena-fuseki/import-sandbox/bin/validateRDFs.sh -s "$file_pattern" \
  -l "validate_RDF_all-Finland-$this_datetime.log" \
  < answer-yes.txt > validate_RDF_all-Finland-processing_${this_datetime}.log 2>&1 &
  # run in background
```

Note that IRI warnings can also prohibit data import to Fuseki (e.g. by encoding those special IRI characters). Sample output:

```
# (Error and Bad IRI warnings will not import, they must be fixed beforehand; most warnings could be imported)
# [line: …, col: …] Illegal character in IRI (Not a ucschar: 0xF022): <https://image.laji.fi/MM.157358/globispora_vuosaari_2.8.2017[U+F022]
# [line: …, col: …] Bad IRI: <https://image.laji.fi/MM.157358/globispora_vuosaari_2.8.2017939_kn_IMG_2863.JPG> Code: 50/PRIVATE_USE_CHARACTER in PATH: TODO
```
 
## (4) Normalize RDF for Subsequent Import

Normalize data is done with `convertRDF4import_normal-files_……….sh` to prepare the import into the triple store. Here many modifications are introduced and done:
- find structural errors (missing values: dc:subject ? etc., e.g. finding '<file:///…>')
- add instiution IDs (ROR-ID or VIAF-ID aso.), data type adjustments
- add properties to manage query handling using URIs in the SPARQL storage (e. g. `dcterms:isPartOf`)

``` bash
/opt/jena-fuseki/import-sandbox/bin/convertRDF4import_normal-files_Paris.sh -h # show help
/opt/jena-fuseki/import-sandbox/bin/convertRDF4import_normal-files_Paris.sh -s \
  'Thread-*x500000-coldb.mnhn.fr_202203[0-9][0-9]-[0-9][0-9][0-9][0-9]_modified.rdf.gz'

# Or run multiple files in the background (log terminal output to log file)
cd /opt/jena-fuseki/import-sandbox/rdf/Finland
  [ $(ls *_modified.rdf*warn-or-error.log* 2> /dev/null | wc -l) -gt 0 ] && rm *_modified.rdf*warn-or-error.log*
  # remove any previous error files
  file_pattern='Thread-*2022*-[0-9][0-9][0-9][0-9]_modified.rdf.gz'
  ! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
  /opt/jena-fuseki/import-sandbox/bin/convertRDF4import_normal-files_Finland.sh \
    -s "$file_pattern" \
    < answer-yes.txt  > \
    convertRDF4import_normal-files-processing-$(date '+%Y%m%d-%Hh%Mm%Ss').log 2>&1 &
    # run in the background
  zcat *${file_pattern/%.gz/}*.log* | grep --color=always --ignore-case 'error\|warn'
  # get error or warn(ings) of all zipped log files
```

## (5) Import Data Into the Triple Store

Data are imported into the RDF store via **S**PARQL **O**ver **H**TTP (SOH: https://jena.apache.org/documentation/fuseki2/soh.html) using `s-post` in the end. It is important to know that data imports do not overwrite, so if you update data (and perhaps there is a smarter update procedure (?using named graphs?) but) you have to delete previous data sets in apache jena fuseki by hand doing SPARQL update using DELETE query.

TODO describe examples to delete

### Prepare file sizes

(TODO describe more)

Better split data into smaller pieces (~50MB) using `patternsplit.awk`; 50MB may take 4 to 15 minutes to import. Before you ran `patternsplit.awk` edit the code section matching the desired matching to split at.

``` bash
gunzip --verbose Threads_import_*20201111-1335.rdf*.trig.gz
for i in {1..5};do
  # set max_strlen=50000000 ?50MB?
  awk \
  -v fileprefix="NHM_import_${i}_" \
  -v fileext=".rdf.normalized.ttl.trig" \
  -v compress_files=1 \
  -f /opt/jena-fuseki/import-sandbox/bin/patternsplit.awk \
  Threads_import_${i}_20201111-1335.rdf._normalized.ttl.trig
done
```

Import the data into the docker app, here as default GRAPH (not recommended, better use named GRAPHs) and interactively:

``` bash
# docker ps # list only running containers
docker exec -it fuseki-app bash  # enter docker-container
  cd /import-data/bin/
  # import data 
  /import-data/bin/import_rdf2trig.gz4docker-fuseki-app.sh -h  # get help
  /import-data/bin/import_rdf2trig.gz4docker-fuseki-app.sh \
    -w '/import-data/rdf/tmpimport-nhm' \
    -s 'NHM_import_*.trig' \
    -d 'data.nhm.ac.uk'
```

Import the data unsing a named GRAPH-IRI and also run it in the background:

```bash
docker exec -it fuseki-app bash
# enter docker-container

  cd /import-data/rdf/Finland
  this_domain="id.luomus.fi"         # 
  this_graph="http://${this_domain}" # http://id.luomus.fi will be the GRAPH
  file_pattern="Thread-*${this_domain}*normalized.ttl.trig.gz"
  
  ! [ -e answer-yes.txt ] && echo 'yes' > answer-yes.txt;
  # run in the background
  # -d data base
  # -w working directory
  # -g graph name to use
  # -u domain (ULR)
  # -s search pattern
  # -l log file of the core import
  # import_rdf2trig.gz4docker… the log file storing the script’s output
  /import-data/bin/import_rdf2trig.gz4docker-fuseki-app.sh -d CETAF-IDs \
    -w /import-data/rdf/Finland \
    -g ${this_graph} \
    -u ${this_domain} \
    -s "$file_pattern" \
    -l Import_GRAPH-${this_domain}_$(date '+%Y%m%d-%H%M%S').log \
    < answer-yes.txt  > \
    import_rdf2trig.gz4docker-fuseki-app_GRAPH-${this_domain}_$(date '+%Y%m%d-%Hh%Mm%Ss').log 2>&1 &
```


<hr/>
Footnotes:

[^Trig]:
  _Bizer, C. and Cyganiak, R._ 2014. ‘RDF 1.1 TriG — RDF Dataset Language. W3C Recommendation 25 February 2014’. Edited by Gavin Carothers and Andy Seaborne. https://www.w3.org/TR/trig/.
