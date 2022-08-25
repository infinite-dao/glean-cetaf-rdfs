#!/bin/bash
set -eu
  # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
  # set -e -- option will cause a bash script to exit immediately when a command fails
  # set -o -- exit also on non-existing command, print also BASH settings
  # set -u -- this option causes the bash shell to treat unset variables as an error and exit immediately.
  # set -x -- the -x option causes bash to print each command before executing it. This can be a great help when trying to debug a bash script failure. Note that arguments get expanded before a command gets printed, which will cause our logs to contain the actual argument values that were present at the time of execution!
  # set -E -- traps are pieces of code that fire when a bash script catches certain signals. Aside from the usual signals (e.g. SIGINT, SIGTERM, …), traps can also be used to catch special bash signals like EXIT, DEBUG, RETURN, and ERR. However, reader Kevin Gibbs pointed out that using -e without -E will cause an ERR trap to not fire in certain scenarios.

this_json_file=$1

function usage() { 
  echo    "############ Print Markdown Table from JSON (Fuseki Results) #########"
  echo -e "# Usage example: \e[32m${0##*/}\e[0m count_cspp_title_Paris_20220822.json" 1>&2; 
  echo -e "# (sorting is done as well see «sort … --key=5.1b» for the 5th field/column)" 1>&2; 
  echo    "#   -h  ...................................... show this help usage" 1>&2; 
}

while getopts ":h" o; do
    case "${o}" in
        h)
            usage; exit 0;
            ;;
        *)
            usage; exit 0;
            ;;
    esac
done
shift "$((OPTIND-1))"

if [[ ${#} -eq 0 ]]; then usage; exit 0; fi
# 
if ! [[ -e "$this_json_file" ]]; then
    usage; 
    echo -e "# \e[31mError:\e[0m \e[33m$this_json_file\e[0m was not found (stop)"
    exit 1;  
fi

this_file_type_summary=$(file "$this_json_file" )
if ! [[ $(echo "$this_file_type_summary" | grep --ignore-case "json text data" ) ]]; then
    usage; 
    echo -e "# \e[31mError:\e[0m \e[33m$this_json_file\e[0m seems not to be a JSON file: «$this_file_type_summary» (stop)"
    exit 1;
fi

# --key=5.1b sorts type_example
cat "$this_json_file"  | jq --raw-output '.head.vars | @tsv' | sed --regexp-extended 's@^@| # | @; s@$@ |@; s@[\t]@ | @g; h; s@[^|]@-@g;x;G;'
cat "$this_json_file" | jq --raw-output '.head.vars as $fields | .results.bindings[] |  [.[($fields[])].value] |@tsv' \
    | sed --regexp-extended 's@^@| @; s@$@ |@; s@[\t]@ | @g;' | column --table --separator '|' --output-separator '|' | sort --field-separator='|' --key=5.1b \
    | sed "=" | sed --regexp-extended "/^[[:digit:]]/{ N; s@(^[[:digit:]]+)\n@| \1 @; }"
