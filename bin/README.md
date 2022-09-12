# Summary of Binary Files

- [`./generate_sed-expr4ROR-id.sh`](./generate_sed-expr4ROR-id.sh)—generate `sed` pattern for use within `convertRDF4import_normal-files_….sh`

Scripts, and recommended steps up and until import:
1. [`./get_RDF4domain_from_urilist_with_ETA.sh`](./get_RDF4domain_from_urilist_with_ETA.sh)—get RDF files from the internet and amass those simply in parallel each into a large file
2. [`./fixRDF_before_validateRDFs.sh`](./fixRDF_before_validateRDFs.sh)—fix large files to be formally correct XML/RDF
3. [`./validateRDFs.sh`](./validateRDFs.sh)—validate technically XML/RDF files
4. convert specifically for instiutions or project data sets, e.g. (add ROR-IDs, dcterms:hasPart, dcterms:conformsTo aso.)
    - [`./convertRDF4import_normal-files_JACQ.sh`](./convertRDF4import_normal-files_JACQ.sh)
    - [`./convertRDF4import_normal-files_Finland.sh`](./convertRDF4import_normal-files_Finland.sh)
    - [`./convertRDF4import_normal-files_Paris.sh`](./convertRDF4import_normal-files_Paris.sh) aso.
    - optional: with the `gawk` program [`./patternsplit.awk`](./patternsplit.awk) to split a large file into handy pieces (e.g. 50MB uncompressed RDF data)
5. and eventually within the docker-fuseki app: [`./import_rdf2trig.gz4docker-fuseki-app.sh`](./import_rdf2trig.gz4docker-fuseki-app.sh)—import files into the RDF store (which is a docker-container of apache-jena-fuseki)
