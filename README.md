# glean-cetaf-rdfs (BASH)

Collect and glean RDF data in parallel of stable identifiers of the Consortium of European Taxonomic Facilities (CETAF, ☞&nbsp;[cetaf.org](https://cetaf.org)) and prepare them for import into a SPARQL endpoint. For the documentation of CETAF identifiers read in&#8239;…
- the wiki ☞&nbsp;[cetafidentifiers.biowikifarm.net](https://cetafidentifiers.biowikifarm.net)
- the **C**ETAF **S**pecimen **P**review **P**rofile (CSPP) on ☞&nbsp;[cetafidentifiers.biowikifarm.net/wiki/CSPP](https://cetafidentifiers.biowikifarm.net/wiki/CSPP)

## Overview

Steps we do:
1. get RDF files from the internet and amass those simply in parallel each into a large file
2. fix large files to be formally correct XML/RDF
3. validate technically XML/RDF files
4. normalize and convert them to TriG[^Trig] format and modify them to the needs of the botany pilot project (add ROR-IDs, dcterms:hasPart, dcterms:conformsTo aso.)
5. import files into the RDF store (which is a docker-container of apache-jena-fuseki)

More technically:
```
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

## Dependencies

BASH
- cat, dateutils (for date diff), date, find, gawk, grep, gunzip, gzip, parallel, sed, sort, uniq, wget
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

  
## (1) Download and Harvesting RDFs

In this example we organize all the data (the `/rdf`), and binaries (`./bin`) in `/opt/jena-fuseki/import-sandbox/` that can be read by all necessary users.

``` bash
/opt/jena-fuseki/import-sandbox/bin/get_RDF4domain_from_urilist_with_ETA.sh -h # show help

# example call, that runs in background (data of https://www.jacq.org)
cd /opt/jena-fuseki/import-sandbox/rdf/JACQ

# get RDF files, the urilist is a simple list, e.g. with CETAF-IDs like … 
#   https://dr.jacq.org/DR001571
#   https://dr.jacq.org/DR001583
#   https://dr.jacq.org/DR001584
#   https://dr.jacq.org/DR001585
# aso.
# run background job to get RDF
/opt/jena-fuseki/import-sandbox/bin/get_RDF4domain_from_urilist_with_ETA.sh \
  -u list-of-JACQ-URIs_20220112.txt \
  -j 10 -l \
  -d xx-jacq.org &
  # -u …… → a simple CSV list to read from the URIs
  # -j 10 → 10 jobs in parallel
  # -l    → log progress into log file (no console prompt before starting)
  # -d …… → is the label for the “domain“: “xx-jacq.org” to name log files and data files
```

### Split Huge URI Lists

One may choose to split huge lists of URIs (perhaps above 500.000) because they tend to be interrupted during the RDF gathering, so we split the URI-list into smaller packages. In this example we want to get overall ~12.000.000 RDF files from Paris (`pc` means cryptogams and `p` vascular plants, i.e. only plantish data from Paris URI parts: `…/pc/…` and `…/p/…`), to split the whole ~12.000.000 URIs in the list file `URI_List_Paris_pc-p_20220317.txt` we use `split` command as follows and split all records into parts of 500.000 lines each:
```bash
# command usage:
# split [OPTIONS] ... [FILE                               [PREFIX]]
# split [OPTIONS] ... URI_List_Paris_pc-p_20220317.txt    URIList20220317_pc-p_per_
split --verbose \
  --lines=500000 \
  --numeric-suffixes=1 \
  --suffix-length=2 \
  --additional-suffix=x500000.txt \
  URI_List_Paris_pc-p_20220317.txt     URIList20220317_pc-p_per_
# creating file 'URIList20220317_pc-p_per_01x500000.txt'
# creating file 'URIList20220317_pc-p_per_02x500000.txt'
# creating file 'URIList20220317_pc-p_per_03x500000.txt'
# creating file 'URIList20220317_pc-p_per_04x500000.txt'
# creating file 'URIList20220317_pc-p_per_05x500000.txt'
# creating file 'URIList20220317_pc-p_per_06x500000.txt'
# creating file 'URIList20220317_pc-p_per_07x500000.txt'
# creating file 'URIList20220317_pc-p_per_08x500000.txt'
# creating file 'URIList20220317_pc-p_per_09x500000.txt'
# creating file 'URIList20220317_pc-p_per_10x500000.txt'
# creating file 'URIList20220317_pc-p_per_11x500000.txt'
# creating file 'URIList20220317_pc-p_per_12x500000.txt'
```

Then harvesting of it could be done with, e. g. the first URI list `URIList20220317_pc-p_per_01x500000.txt`, like:

```bash
# mkdir --parents /opt/jena-fuseki/import-sandbox/rdf/Paris
cd /opt/jena-fuseki/import-sandbox/rdf/Paris

# we run it by using logging (-l) into files
# -u urilist
# -j number of parallel jobs
# -l do log into files
# -d domain name (here with prefix to describe the steps)
/opt/jena-fuseki/import-sandbox/bin/get_RDF4domain_from_urilist_with_ETA.sh \
  -u URIList20220317_pc-p_per_01x500000.txt \
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
```

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
  - e.g. possible error: The prefix `foaf` for element "foaf:depiction" is not bound
3. add missing RDF prefixes if possible

… and proceed with `validate.sh`

**1. Run the script**

``` bash
/opt/jena-fuseki/import-sandbox/bin/fixRDF_before_validateRDFs_modified.sh -h # show help

/opt/jena-fuseki/import-sandbox/bin/fixRDF_before_validateRDFs_modified.sh -s 'Thread-*x500000-coldb.mnhn.fr_202203[0-9][0-9]-[0-9][0-9][0-9][0-9].rdf.gz'
```

**2. Compare RDF headers**

It will printout and log for checking RDF headers manually, compare the prefixes side by side: from the initial RDF and after processing, e.g. the following sample output:
```bash
# -----------------------
# Compare RDF headers 001 of 260 based on Thread-01_01x500000-coldb.mnhn.fr_20220317-2156.rdf.gz …
# -----------------------
# For checking zipped modified files …
 zcat Thread-01_01x500000-coldb.mnhn.fr_20220317-2156_modified.rdf.gz | sed --quiet --regexp-extended '/<rdf:RDF/{ 
    :rdf_anchor;N;
    /<rdf:RDF[^>]*>/!b rdf_anchor; 
    s@[ \t\s]+(xmlns:)@\n  \1@g; s@\n\n@\n@g; p;
  }' \
  | pr --page-width 140 --merge --omit-header \
  'Thread-01_01x500000-coldb.mnhn.fr_20220317-2156_rdfRDF_headers_extracted.rdf' -
# left: initially extracted  … right: after processing
# <rdf:RDF                                                              <rdf:RDF
#   xmlns:dc="http://purl.org/dc/terms/"                                  xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
#   xmlns:dwcc="http://rs.tdwg.org/dwc/curatorial/"                       xmlns:rdfs="http://www.w3.org/TR/2014/REC-rdf-schema-20140225/"
#   xmlns:dwc="http://rs.tdwg.org/dwc/terms/"                             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
#   xmlns:foaf="http://xmlns.com/foaf/spec/"                              xmlns:tap="http://rs.tdwg.org/tapir/1.0"
#   xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#"                  xmlns:xs="http://www.w3.org/2001/XMLSchema"
#   xmlns:hyam="http://hyam.net/tapir2sw#"                                xmlns:hyam="http://hyam.net/tapir2sw#"
#   xmlns:ma="https://www.w3.org/ns/ma-ont#"                              xmlns:dwc="http://rs.tdwg.org/dwc/terms/"
#   xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"               xmlns:dwcc="http://rs.tdwg.org/dwc/curatorial/"
#   xmlns:rdfs="http://www.w3.org/TR/2014/REC-rdf-schema-20140225/"       xmlns:dc="http://purl.org/dc/terms/"
#   xmlns:tap="http://rs.tdwg.org/tapir/1.0"                              xmlns:foaf="http://xmlns.com/foaf/spec/"
#   xmlns:xs="http://www.w3.org/2001/XMLSchema"                           xmlns:ma="https://www.w3.org/ns/ma-ont#"
#   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"                 xmlns:geo="http://www.w3.org/2003/01/geo/wgs84_pos#">
# >                                                                     
# <!-- *Initially* extracted RDF-headers from                           
#      Thread-01_01x500000-coldb.mnhn.fr_20220317-2156.rdf.gz -->       
```

**3. add missing RDF prefixes** — may be necessary depending on the data; must be done by hand.


## (3) Validation

Validate data with `validateRDF.sh` to check if each RDF file is technically correct:

``` bash
/opt/jena-fuseki/import-sandbox/bin/validateRDFs.sh -h # show help
/opt/jena-fuseki/import-sandbox/bin/validateRDFs.sh -s 'Thread-*x500000-coldb.mnhn.fr_202203[0-9][0-9]-[0-9][0-9][0-9][0-9]_modified.rdf.gz'
```
 
## (4) Normalize RDF for Subsequent Import

Normalize data is done with `convertRDF4import_normal-files_……….sh` to prepare import into triple store. Here many modifications are introduced and done:
- find structural errors (missing values: dc:subject ? etc., e.g. finding '<file:///…>')
- add ROR-IDs, data type adjustments, add properties to manage query handling using URIs in the SPARQL storage (e. g. `dcterms:isPartOf`)

``` bash
/opt/jena-fuseki/import-sandbox/bin/convertRDF4import_normal-files_Paris.sh -h # show help
/opt/jena-fuseki/import-sandbox/bin/convertRDF4import_normal-files_Paris.sh -s 'Thread-*x500000-coldb.mnhn.fr_202203[0-9][0-9]-[0-9][0-9][0-9][0-9]_modified.rdf.gz'
```

## (5) Import Data Into the Triple Store

Data are imported into the RDF store via **S**PARQL **O**ver **H**TTP (SOH: https://jena.apache.org/documentation/fuseki2/soh.html) using `s-post` in the end.


### TODO Prepare file sizes

Better split data into smaller pieces (~50MB) using `patternsplit.awk`; 50MB may take 4 to 15 minutes to import.
``` bash
gunzip --verbose Threads_import_*20201111-1335.rdf*.trig.gz
for i in {1..5};do
  # set max_strlen=50000000 ?50MB?
  awk -v fileprefix="NHM_import_${i}_" -v fileext=".rdf.normalized.ttl.trig" -f ~/sandbox/import/bin/patternsplit.awk Threads_import_${i}_20201111-1335.rdf._normalized.ttl.trig
done
```

Import the data into the docker app:

``` bash
# docker ps # list only running containers
docker exec -it fuseki-app bash
  cd /import-data/bin/
  ./import_rdf2trig.gz4docker-fuseki-app.sh -h  # get help
  ./import_rdf2trig.gz4docker-fuseki-app.sh -w '/import-data/rdf/tmpimport-nhm' -s 'NHM_import_*.trig' -d 'data.nhm.ac.uk'
```

[^TriG] _Bizer, C. and Cyganiak, R._ 2014. ‘RDF 1.1 TriG — RDF Dataset Language. W3C Recommendation 25 February 2014’. Edited by Gavin Carothers and Andy Seaborne. https://www.w3.org/TR/trig/.
