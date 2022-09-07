##################################################
#   Description: split a file based on search pattern and max_strlen and optionally compress all split files with gzip
#     DO MODIFY the search pattern to meet your needs, and max_strlen perhaps, where to split
##################################################
#   Usage
#     (before you start this program, check the search pattern in code you want to match)
#     awk -v fileprefix="BGMeise1_" -v compress_files=1 -f ~/bin/patternsplit.awk Thread-1_www.botanicalcollections.be.rdf_rdfparse.ttl
#     awk -v fileprefix="SNSB_1_" -f ~/bin/patternsplit.awk Threads_import_1_20201116.rdf._normalized.ttl.one_lines_filtered.trig
#     awk -v fileprefix="JACQ_1_" -f ~/sandbox/import/bin/patternsplit.awk Thread-1_jacq.org_20211117-1006.rdf._normalized.ttl.trig
#     awk -v fileprefix="cetaf_ids_all-records-splitted_" -v headerprefix="PREFIX dwc: <http://rs.tdwg.org/dwc/terms/>" -f ~/sandbox/import/bin/patternsplit.awk cetaf_ids_all-records_www.mnhn.fr.dwc-institutionID.sparql
#     zcat Thread-10_xx-data.rbge.org.uk_20220302-1115.rdf._normalized.ttl.trig.gz | \
#        awk -v fileprefix="Edinburgh_20220228ff_" -v compress_files=1 -f /opt/jena-fuseki/import-sandbox/bin/patternsplit.awk -
##################################################
#   
BEGIN {
    instruct_to_print_debug=1
    # max_strlen=100000000                                     # can be modified original 100000000
    max_strlen=50000000                                       # can be modified 50000000: about 48MB uncompressed
    file_index = 0 # 0 because of while file++ = file number 1
    
    # check if external variables where given
    if (length(fileprefix) > 0) { this_fileprefix = fileprefix } 
    else { this_fileprefix = "BGBM_1_" }

    if (length(headerprefix) > 0) { this_headerprefix = headerprefix } 
    else { this_headerprefix = "" }

    if (int(compress_files) > 0) { this_compress_files = int(compress_files) } 
    else { this_compress_files = 0 }
      
    if (length(fileext) > 0) { this_fileext = fileext } 
    else { 
      # this_fileext = ".rdf_rdfparse.ttl" 
      this_fileext = ".rdf._normalized.ttl.trig" 
      
    }
    # this_fileext = ".www.mnhn.fr.dwc-institutionID.sparql"   # can be modified
    
    {
      do {
        file_index++
        this_outputfile = sprintf ("%s%02d%s", this_fileprefix,file_index,this_fileext)
        this_outputfile_gz = sprintf ("%s%02d%s.gz", this_fileprefix,file_index,this_fileext)
        # printf "#     DEBUG \033[34mstat\033[0m while-in-doing %s returns %s, file_index %s\n", this_outputfile, system("stat " this_outputfile " >/dev/null 2>/dev/null"),file_index
        # printf "#     DEBUG \033[34mstat\033[0m while-in-doing %s returns %s, file_index %s\n", this_outputfile_gz, system("stat " this_outputfile_gz " >/dev/null 2>/dev/null"),file_index
      }
      while ( system("stat " this_outputfile " >/dev/null 2>/dev/null") == 0 || system("stat " this_outputfile_gz " >/dev/null 2>/dev/null") == 0 ) 
        # stat … 0 indicates an existing file (no error)
        # stat … 1 indicates a non-existing file (i.e. stat return error)
    }
    printf "# Split file based on search pattern (see code) and max %d string length each\n#   to %s01, 02 aso. ...\n", max_strlen, fileprefix;
    if (instruct_to_print_debug) { printf "#   DEBUG BEGIN script\n"; }
    printf "#     Write: \033[32m%s\033[0m ...\n", this_outputfile;
} # BEGIN

{ # do each text line
    current_strlength += length()
}
################################################################
# Search pattern where to split the file according to max_strlen
# search pattern between /.../ sets the splitting point (we attempt to cut at triple-data-set level)
################################################################
# current_strlength > max_strlen && /^<http:\/\/rs.tdwg.org\/dwc\/terms\/InstitutionCode> "Botanic Garden Meise"/ {
# current_strlength > max_strlen && /^<http:\/\/services.snsb.info\// {
# # # # # NHM London
# current_strlength > max_strlen && /^<https?:\/\/data.nhm.ac.uk\/object\/[^>]+\.rdf>/ {
# # # # # JACQ
# current_strlength > max_strlen && /^<https?:\/\/.*jacq.org\/data\/rdf\/[^>]+>/ {
# # # # # RBGE (Edinburgh)
# current_strlength > max_strlen && /^<https?:\/\/data.rbge.org.uk\/herb\/[^>]+>/ {
# # # # # RBGK (Kew) 
# current_strlength > max_strlen && /^<https?:\/\/specimens.kew.org\/herbarium\/[^>]+>/ {
# # # # # MNHN Paris
# current_strlength > max_strlen && /INSERT DATA .* <http:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\// {
# current_strlength > max_strlen && /^<https?:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\/[a-z]+\// {
current_strlength > max_strlen && /^<https?:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\/p\// {
# current_strlength > max_strlen && /^<https?:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\/pc\// {
# # # # # Finland
# current_strlength > max_strlen && /^<https?:\/\/id.luomus.fi\/[^<>]+>/ {
# current_strlength > max_strlen && /^<https?:\/\/tun.fi\/[^<>]+>/ {
# current_strlength > max_strlen && /^<https?:\/\/id.herb.oulu.fi\/[^<>]+>/ {
# # # # # Meise
# current_strlength > max_strlen && /^<https?:\/\/www.botanicalcollections.be\/specimen\/[^<>]+>/ {
  
    this_outputfile = sprintf ("%s%02d%s", this_fileprefix,file_index,this_fileext);
    if (instruct_to_print_debug) { printf "#     REACHED MAX_STRLEN close: %s ...\n", this_outputfile; }
    close(this_outputfile) # old file
    
    this_outputfile = sprintf ("%s%02d%s", this_fileprefix,file_index,this_fileext)
    this_outputfile_gz = sprintf ("%s%02d%s.gz", this_fileprefix,file_index,this_fileext)
    if (instruct_to_print_debug) {
      printf "#     REACHED MAX_STRLEN check for existing files (do not overwrite them) ...\n", this_fileprefix,file_index,this_fileext;
      # printf "#     DEBUG \033[34mstat\033[0m while-before %s returns %s, file_index %s\n", this_outputfile, system("stat " this_outputfile " >/dev/null 2>/dev/null"),file_index
      # printf "#     DEBUG \033[34mstat\033[0m while-before %s returns %s, file_index %s\n", this_outputfile_gz, system("stat " this_outputfile_gz " >/dev/null 2>/dev/null"),file_index
    }
    {
      do {
        file_index++
        this_outputfile = sprintf ("%s%02d%s", this_fileprefix,file_index,this_fileext)
        this_outputfile_gz = sprintf ("%s%02d%s.gz", this_fileprefix,file_index,this_fileext)
        # printf "#     DEBUG \033[34mstat\033[0m while-in-doing %s returns %s, file_index %s\n", this_outputfile, system("stat " this_outputfile " >/dev/null 2>/dev/null"),file_index
        # printf "#     DEBUG \033[34mstat\033[0m while-in-doing %s returns %s, file_index %s\n", this_outputfile_gz, system("stat " this_outputfile_gz " >/dev/null 2>/dev/null"),file_index
      }
      while ( system("stat " this_outputfile " >/dev/null 2>/dev/null") == 0 || system("stat " this_outputfile_gz " >/dev/null 2>/dev/null") == 0 ) 
        # stat … 0 indicates an existing file (no error)
        # stat … 1 indicates a non-existing file (i.e. stat return error)
    }
    # printf "#     DEBUG \033[34mstat\033[0m while-after %s returns %s, file_index %s\n", this_outputfile, system("stat " this_outputfile " >/dev/null 2>/dev/null"),file_index
    # printf "#     DEBUG \033[34mstat\033[0m while-after %s returns %s, file_index %s\n", this_outputfile_gz, system("stat " this_outputfile_gz " >/dev/null 2>/dev/null"),file_index
    printf "#     Write: \033[32m%s\033[0m ...\n", this_outputfile;
    current_strlength = 0 # reset 
}
{ # do each text line
    this_outputfile = sprintf ("%s%02d%s", this_fileprefix,file_index,this_fileext);
    if (length(headerprefix) > 0 && current_strlength == 0 ) { print headerprefix > this_outputfile; } 
    print $0 > this_outputfile; # write file
}
END {
  if (int(this_compress_files) > 0) { 
    this_outputfile_pattern = sprintf ("%s%s%s", this_fileprefix, "*",this_fileext);
    if (instruct_to_print_debug) { print "#   DEBUG END script" } 
    print "#   Compressing files: \033[34mgzip\033[0m --quiet --force … " this_outputfile_pattern
    system ("gzip --quiet --force " this_outputfile_pattern)
  } 
}
