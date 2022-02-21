##################################################
#   Description: split a file based on search pattern and max_strlen and eventually compress all split files with gzip
#     modify the search pattern to meet your needs, where to split
##################################################
#   Usage
#     (before you start this program, check the search pattern in code you want to match)
#     awk -v fileprefix="BGMeise1_" -v compress_files=1 -f ~/bin/patternsplit.awk Thread-1_www.botanicalcollections.be.rdf_rdfparse.ttl
#     awk -v fileprefix="SNSB_1_" -f ~/bin/patternsplit.awk Threads_import_1_20201116.rdf._normalized.ttl.one_lines_filtered.trig
#     awk -v fileprefix="JACQ_1_" -f ~/sandbox/import/bin/patternsplit.awk Thread-1_jacq.org_20211117-1006.rdf._normalized.ttl.trig
#     awk -v fileprefix="cetaf_ids_all-records-splitted_" -v headerprefix="PREFIX dwc: <http://rs.tdwg.org/dwc/terms/>" -f ~/sandbox/import/bin/patternsplit.awk cetaf_ids_all-records_www.mnhn.fr.dwc-institutionID.sparql
##################################################
#   
BEGIN {
    fileno = 1
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
    # max_strlen=100000000                                     # can be modified original 100000000
    
    max_strlen=50000000                                       # can be modified 50000000: about 48MB uncompressed
    
    printf "# Split file based on search pattern (see code) and max %d string length each to %s01, %s02 etc. ...\n", max_strlen, fileprefix, fileprefix;
    printf "#   Write: %s%02d%s ...\n", this_fileprefix,fileno,this_fileext;
}
{
    current_strlength += length()
}
##################################################
# check or modify search pattern between /.../
##################################################
# current_strlength > max_strlen && /<http:\/\/rs.tdwg.org\/dwc\/terms\/InstitutionCode> "Botanic Garden Meise"/ {
# current_strlength > max_strlen && /<http:\/\/services.snsb.info\// {
# current_strlength > max_strlen && /<https?:\/\/data.nhm.ac.uk\/object\/[^>]+\.rdf>/ {
current_strlength > max_strlen && /<https?:\/\/.*jacq.org\/data\/rdf\/[^>]+>/ {
# current_strlength > max_strlen && /INSERT DATA .* <http:\/\/coldb.mnhn.fr\/catalognumber\/mnhn\// {
    this_outputfile = sprintf ("%s%02d%s", this_fileprefix,fileno,this_fileext);
    close(this_outputfile) # old file
    fileno++
    current_strlength = 0
    printf "#   Write: %s%02d%s ...\n", this_fileprefix,fileno,this_fileext;
}
{
    this_outputfile = sprintf ("%s%02d%s", this_fileprefix,fileno,this_fileext);
    if (length(headerprefix) > 0 && current_strlength == 0 ) { print headerprefix > this_outputfile; } 
    print $0 > this_outputfile;
}
END {
  if (int(this_compress_files) > 0) { 
    print "# compress files to .gz"
    this_outputfile_pattern = sprintf ("%s%s%s", this_fileprefix, "*",this_fileext);
    system ("gzip --verbose " this_outputfile_pattern)
  } 
}
