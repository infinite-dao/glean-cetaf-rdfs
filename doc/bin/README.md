# Print Results from Fuseki JSON

```bash
./print_markdown-table_from_json.sh count_cspp_title_all_20220822.json
```
… should give a table like this

    | # | cspp_example | title_example | all__count | type_example | publisher_example | graph_example |
    |---|--------------|---------------|------------|--------------|-------------------|---------------|
    | 1 | http://id.herb.oulu.fi/MY.7973968                            | PreservedSpecimen http://id.herb.oulu.fi/MY.7973968 of Trigonella alba                                                                         | 52907   | http://purl.org/dc/dcmitype/PhysicalObject | http://gbif.fi                                                     | http://id.herb.oulu.fi                              |
    | 2 | http://id.luomus.fi/MY.7754194                               | PreservedSpecimen http://id.luomus.fi/MY.7754194 of Hyptis septentrionalis                                                                     | 641024  | http://purl.org/dc/dcmitype/PhysicalObject | http://gbif.fi                                                     | http://id.luomus.fi                                 |
    | 3 | http://tun.fi/MY.1238410                                     | PreservedSpecimen http://tun.fi/MY.1238410 of Ulmus glabra                                                                                     | 648116  | http://purl.org/dc/dcmitype/PhysicalObject | http://gbif.fi                                                     | http://tun.fi                                       |
    | 4 | http://coldb.mnhn.fr/catalognumber/mnhn/pc/pc0730561         | Specimen - Palmaria palmata (L.) O.Kuntze                                                                                                      | 500614  | http://purl.org/dc/dcmitype/PhysicalObject | https://science.mnhn.fr/institution/mnhn/collection/pc/item/search | http://coldb.mnhn.fr/catalognumber/mnhn/pc/         |
    | 5 | http://coldb.mnhn.fr/catalognumber/mnhn/p/p04112060          | Specimen - Centaurea pullata L.                                                                                                                | 5191187 | http://purl.org/dc/dcmitype/PhysicalObject | https://science.mnhn.fr/institution/mnhn/collection/p/item/search  | http://coldb.mnhn.fr/catalognumber/mnhn/p/          |
    … … … … …

| # | cspp_example | title_example | all__count | type_example | publisher_example | graph_example |
|---|--------------|---------------|------------|--------------|-------------------|---------------|
| 1 | http://id.herb.oulu.fi/MY.7973968                            | PreservedSpecimen http://id.herb.oulu.fi/MY.7973968 of Trigonella alba                                                                         | 52907   | http://purl.org/dc/dcmitype/PhysicalObject | http://gbif.fi                                                     | http://id.herb.oulu.fi                              |
| 2 | http://id.luomus.fi/MY.7754194                               | PreservedSpecimen http://id.luomus.fi/MY.7754194 of Hyptis septentrionalis                                                                     | 641024  | http://purl.org/dc/dcmitype/PhysicalObject | http://gbif.fi                                                     | http://id.luomus.fi                                 |
| 3 | http://tun.fi/MY.1238410                                     | PreservedSpecimen http://tun.fi/MY.1238410 of Ulmus glabra                                                                                     | 648116  | http://purl.org/dc/dcmitype/PhysicalObject | http://gbif.fi                                                     | http://tun.fi                                       |
| 4 | http://coldb.mnhn.fr/catalognumber/mnhn/pc/pc0730561         | Specimen - Palmaria palmata (L.) O.Kuntze                                                                                                      | 500614  | http://purl.org/dc/dcmitype/PhysicalObject | https://science.mnhn.fr/institution/mnhn/collection/pc/item/search | http://coldb.mnhn.fr/catalognumber/mnhn/pc/         |
| 5 | http://coldb.mnhn.fr/catalognumber/mnhn/p/p04112060          | Specimen - Centaurea pullata L.                                                                                                                | 5191187 | http://purl.org/dc/dcmitype/PhysicalObject | https://science.mnhn.fr/institution/mnhn/collection/p/item/search  | http://coldb.mnhn.fr/catalognumber/mnhn/p/          |

Convert markdown to HTML using pandoc (note: `<http://…>` generates also `<a href="…">…</a>`):

```bash
./print_markdown-table_from_json.sh count_cspp_title_all_20220822.json \
 | sed --regexp-extended 's@(https?://[^[:space:]]+)@<\1>@g;' \
 | pandoc -f markdown -t html
```

# Print Results from Harvesting

```bash
./report_harvest_Done-status-and-log-errors.sh --help # show help and options
./report_harvest_Done-status-and-log-errors.sh \
  --urilist urilist_BGBM_20221107_todo.tsv \
  --searchpattern Thread-XX_*_20221110-1227.log.gz
```
… this can return a table like this:

```
| URI List (Log File)   |   Date Time     |  Notes and Time |
|-----------------------|-----------------|-------------------------------------------------------------------|
| urilist_BGBM_20221107_todo.tsv  (Thread-XX_herbarium.bgbm.org_20221110-1227.log.gz) | 20221110-1227 | Done. 011556 jobs took 0d 01h:44m:45s using 20 parallel connections, having URI-Errors: 67 |
```
