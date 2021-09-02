# glean-cetaf-rdfs

Collect and glean RDF data in parallel of stable identifiers of the Consortium of European Taxonomic Facilities (CETAF) and prepare them for import into a SPARQL endpoint.

## Dependencies

BASH
- cat, find, gawk, gunzip, parallel, sed, sort, uniq, wget
- scripts
  - `./get_RDF4domain_from_urilist.sh`
  - `./fixRDF_before_validateRDFs.sh`
  - `./validateRDFs.sh`
  - `./convertRDF4import_normal-files.sh`
  - `./import_rdf2trig.gz4docker-fuseki-app.sh`

RDF checks
- Apache Jena Fuseki
  - https://jena.apache.org/download/index.cgi

SPARQL endpoint
- Apache Jena Fuseki Server 
  - e.g. https://hub.docker.com/r/stain/jena-fuseki/

## (1) Harvesting RDFs

``` bash
./get_RDF4domain_from_urilist.sh
```

## (2) Check Errors and Validation

``` bash
# check for errors
sed --quiet --regexp-extended 's/^.*(ERROR:.*)/\1/p' Thread-X_data.nhm.ac.uk_20201111-1335.log | sort | uniq  --count | sed 's@^@# @'
# 1071846 ERROR: 404 Not Found;
#      15 ERROR: 500 INTERNAL SERVER ERROR;                       # re-capture: works later on
#       7 ERROR: No data received.;OK: 200 OK;                    # re-capture: works later on
#       6 ERROR: No data received.;OK: 303 SEE OTHER;OK: 200 OK;
sed --quiet --regexp-extended 's@.*(https?://[^ ]+).*(ERROR:.*(INTERNAL SERVER ERROR|No data received).*)@\1 # \2@p' \
  Thread-X_data.nhm.ac.uk_20201111-1335.log \
  > data.nhm.ac.uk_occurrenceID_failedFrom_20201111-1335.txt
```

Generate perhaps files of import if neccessary

``` bash
# find . -iname 'Thread-*data.nhm.ac.uk_20201111-1335.rdf' | parallel -j5  cat {} ">>" Threads_import_{%}_$(date '+%Y%m%d').rdf
find . -iname 'Thread-*data.nhm.ac.uk_20201111-1335.rdf' | parallel -j5  cat {} ">>" Threads_import_{%}_20201111-1335.rdf
```

### Validating RDF

Proceed with:
1. run `fixRDF_before_validateRDFs.sh -h` to condense concatenated RDF files into one huge file
2. make sure the RDF prefixes are correct (e.g. possible error: The prefix "foaf" for element "foaf:depiction" is not bound)
3. add possible missing RDF prefixes
4. proceed wiht `validate.sh`



``` bash
./fixRDF_before_validateRDFs.sh -h
```

Check that all the prefixes are there:
``` bash
sed -n '/<rdf:RDF/,/>/{ s@\bxmlns:@\nxmlns:@g; /\nxmlns:/!d; /^[\s\t\n]*$/d; p; }' Thread-1_data.nhm.ac.uk_20201111-1335.rdf | sort --unique | sed '1i\<rdf:RDF 
$a\ >'
# <rdf:RDF 
#   
# xmlns:aiiso="http://purl.org/vocab/aiiso/schema#"
# xmlns:cc="http://creativecommons.org/ns#"
# xmlns:dc="http://purl.org/dc/terms/"
# xmlns:dwc="http://rs.tdwg.org/dwc/terms/"
# xmlns:foaf="http://xmlns.com/foaf/0.1/"
# xmlns:owl="http://www.w3.org/2002/07/owl#"
# xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
# xmlns:void="http://rdfs.org/ns/void#"
#  >

# add rdf:RDF
# xmlns:cc="http://creativecommons.org/ns#"
# xmlns:foaf="http://xmlns.com/foaf/0.1/"
# 
vi Threads_import_5_20201111-1335.rdf
vi Threads_import_4_20201111-1335.rdf
vi Threads_import_3_20201111-1335.rdf
vi Threads_import_2_20201111-1335.rdf
vi Threads_import_1_20201111-1335.rdf
```

Validate date with `validateRDF.sh` to check RDF to be technically correct.

``` bash
./validateRDFs.sh
```
 
## (3) Normalize RDF for subsequent import

1. fix possible errors then normalize data with `convertRDF4import_normal-files.sh` to prepare import into triple store
2. find structural errors (missing values: dc:subject ? etc., e.g. finding '<file:///…>')
3. perhaps filter dwc:collectionCode (fungi, plants, cryptogams, palaeontological findings etc.)

``` bash
convertRDF4import_normal-files.sh -h
convertRDF4import_normal-files.sh -s 'Threads_import*.rdf'
```

## (4) Import Data Into the Triple Store
### Prepare file sizes

Better split data into smaller pieces (~50MB) using `patternsplit.awk`; 50MB may take 4 to 15 minutes to import.
``` bash
gunzip --verbose Threads_import_*20201111-1335.rdf*.trig.gz
for i in {1..5};do
  # set max_strlen=50000000 ?50MB?
  awk -v fileprefix="NHM_import_${i}_" -v fileext=".rdf.normalized.ttl.trig" -f /home/aplank/sandbox/import/bin/patternsplit.awk Threads_import_${i}_20201111-1335.rdf._normalized.ttl.trig
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
