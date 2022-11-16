#!/bin/bash
set -eu
  # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
  # set -e -- option will cause a bash script to exit immediately when a command fails
  # set -o -- exit also on non-existing command, print also BASH settings
  # set -u -- this option causes the bash shell to treat unset variables as an error and exit immediately.
  # set -x -- the -x option causes bash to print each command before executing it. This can be a great help when trying to debug a bash script failure. Note that arguments get expanded before a command gets printed, which will cause our logs to contain the actual argument values that were present at the time of execution!
  # set -E -- traps are pieces of code that fire when a bash script catches certain signals. Aside from the usual signals (e.g. SIGINT, SIGTERM, …), traps can also be used to catch special bash signals like EXIT, DEBUG, RETURN, and ERR. However, reader Kevin Gibbs pointed out that using -e without -E will cause an ERR trap to not fire in certain scenarios.

this_json_file=${!#}
this_sortByKey_default=2.1h # first is index column
    this_sortByKey=$this_sortByKey_default
this_sortByKeyFiledSeparator_default='|'
    this_sortByKeyFiledSeparator=$this_sortByKeyFiledSeparator_default
this_showIndex=1
this_showDebug=0
do_exit=0

if ! command -v jq &> /dev/null
then
    echo -e "\e[31m# Error: Command jq could not be found. Please install it.\e[0m"
    do_exit=1
fi
if ! command -v sed &> /dev/null 
then
    echo -e "# \e[31mError: command sed (stream editor) could not be found. Please install package sed.\e[0m"
    doexit=1
fi

if ! command -v echo "| test | test test |" | column  --table --separator '|' --output-separator '|' &> /dev/null 
then
    echo -e "# \e[31mError: program column seems not right, we need a decent version of it (from util-linux, to have «--output-separator»).\e[0m"
    doexit=1
fi


if [[ $do_exit -gt 0 ]];then
  exit 1;
fi


function usage() { 
  echo    "############ Print Markdown Table from JSON (Fuseki Results) #########"
  echo -e "# Usage example: \e[32m${0##*/}\e[0m count_cspp_title_Paris_20220822.json" 1>&2; 
  echo -e "# (sorting is done as well see «sort … --key=${this_sortByKey_default}» for the field/column: ${this_sortByKey_default%.*})" 1>&2; 
  echo    "#   -h  ........... show this help usage" 1>&2; 
  echo    "#   -k 3.1nr ...... sorting key: by 3rd field, but 2nd column numeric reverse" 1>&2; 
  echo    "#       b - ignore leading blanks (useful for sorting alphabetically)" 1>&2; 
  echo    "#       n - numeric sorting" 1>&2; 
  echo    "#       r - reverse sorting" 1>&2; 
  echo    "#       h - human-numeric-sort" 1>&2; 
  echo    "#       f - ignore case, aso. see «man sort»" 1>&2; 
  echo    "#   -d  ........... show debug sorting of columns" 1>&2; 
  echo    "#   -f  '/' ....... set another field separator for sorting of columns (default: ${this_sortByKeyFiledSeparator_default} )" 1>&2; 
  echo    "#                   (you have to take care of -k then, check it with debug sorting using -d)" 1>&2; 
  echo    "#   -n  ........... show no index column" 1>&2; 
  echo -e "# \e[33mNeeds a decent version of command column (from util-linux, to have «--output-separator»)\e[0m" 1>&2; 
}

while getopts ":k:hndf:" o; do
    case "${o}" in
        k)
            this_sortByKey=${OPTARG};
            if ! [[ $this_sortByKey =~ ^[0-9]+.[0-9]+[a-z]+$ ]];then
            echo -e "\e[31m# $this_sortByKey seems not a sorting key, e.g. «3.1n», sorting by default field key: ${this_sortByKey_default}\e[0m" 1>&2
                this_sortByKey=$this_sortByKey_default;
            fi
            ;;
        f)
            this_sortByKeyFiledSeparator=${OPTARG};
            # if ! [[ $this_sortByKeyFiledSeparator =~ ^some-regexp$ ]];then
            # echo -e "\e[31m# sorting field separator $this_sortByKeyFiledSeparator cannot be used, sorting now by default field separator: ${this_sortByKeyFiledSeparator_default}\e[0m" 1>&2
            #     $this_sortByKeyFiledSeparator=$this_sortByKeyFiledSeparator_default;
            # fi
            ;;
        h)
            usage; exit 0;
            ;;
        d)
            this_showDebug=1;
            ;;
        n)
            this_showIndex=0;
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
if ! [[ $(echo "$this_file_type_summary" | grep --ignore-case "json.\+data" ) ]]; then
    echo -e "# \e[33mWarning:\e[0m \e[33m$this_json_file\e[0m seems not to be a JSON file: «$this_file_type_summary» (continue)"
    # exit 1;
fi

this_sortDebugOption=$( [[ $this_showDebug -gt 0 ]] && echo " --debug " || echo "" )

if [[ $this_showIndex -gt 0 ]];then
cat "$this_json_file"  | jq --raw-output '.head.vars | @tsv' | sed --regexp-extended 's@^@| # | @; s@$@ |@; s@[\t]@ | @g; h; s@[^|]@-@g;x;G;'
cat "$this_json_file" | jq --raw-output '.head.vars as $fields | .results.bindings[] |  [.[($fields[])].value] |@tsv' \
    | sed --regexp-extended 's@^@| @; s@$@ |@; s@[\t]@ | @g;' | column --table --separator '|' --output-separator '|' | sort ${this_sortDebugOption} --field-separator=$this_sortByKeyFiledSeparator --key=${this_sortByKey}  \
    | sed "=" | sed --regexp-extended "/^[[:digit:]]/{ N; s@(^[[:digit:]]+)\n@| \1 @; }"
else
cat "$this_json_file"  | jq --raw-output '.head.vars | @tsv' | sed --regexp-extended 's@^@| @;     s@$@ |@; s@[\t]@ | @g; h; s@[^|]@-@g;x;G;'
cat "$this_json_file" | jq --raw-output '.head.vars as $fields | .results.bindings[] |  [.[($fields[])].value] |@tsv' \
    | sed --regexp-extended 's@^@| @; s@$@ |@; s@[\t]@ | @g;' | column --table --separator '|' --output-separator '|' | sort ${this_sortDebugOption} --field-separator=$this_sortByKeyFiledSeparator --key=${this_sortByKey} 
fi
