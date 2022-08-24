#!/bin/bash
set -eu
  # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
  # set -e -- option will cause a bash script to exit immediately when a command fails
  # set -o -- exit also on non-existing command, print also BASH settings
  # set -u -- this option causes the bash shell to treat unset variables as an error and exit immediately.
  # set -x -- the -x option causes bash to print each command before executing it. This can be a great help when trying to debug a bash script failure. Note that arguments get expanded before a command gets printed, which will cause our logs to contain the actual argument values that were present at the time of execution!
  # set -E -- traps are pieces of code that fire when a bash script catches certain signals. Aside from the usual signals (e.g. SIGINT, SIGTERM, …), traps can also be used to catch special bash signals like EXIT, DEBUG, RETURN, and ERR. However, reader Kevin Gibbs pointed out that using -e without -E will cause an ERR trap to not fire in certain scenarios.

# Use this script locally after RDF harvesting to get error statistics as markdown table
# only .log.gz should be finished
  echo "" > this_temporary_list.txt
  for this_logfile in Thread-XX_*_202208[0-9][0-9]-[0-9][0-9][0-9][0-9].log.gz;do 
    echo "# check $this_logfile …"
    echo -n "# $this_logfile …" >> this_temporary_list.txt;
    echo -n "$this_logfile" | sed -r 's@Thread.+([[:digit:]]{8}-[[:digit:]]{4}).+@ # \1 @' >> this_temporary_list.txt
    # dateutils.ddiff "$datetime_start" "$datetime_end" -f "# Done. $TOTAL_JOBS jobs took %dd %0Hh:%0Mm:%0Ss using $N_JOBS parallel connections"
    this_time_started=$( zgrep -i "Started:" "$this_logfile" | sed -r 's@.+Started: +@@') ;
    this_time_ended=$( zgrep -i "Ended:" "$this_logfile" | sed -r 's@.+Ended: +@@') ;
    this_done_log_message=$( zgrep -i "Done" "$this_logfile" | sed -r 's@0d %Hh:%Mm:%Ss@%dd %0Hh:%0Mm:%0Ss@') ; # fix date time format strings
    # echo $this_done_log_message
    echo -n $(dateutils.ddiff "$this_time_started" "$this_time_ended" -f "$this_done_log_message") >> this_temporary_list.txt
    if [[ -e "${this_logfile/.log.gz/_error.log}" ]]; then
      echo -n ", having URI-Errors: $(cat "${this_logfile/.log.gz/_error.log}" | wc -l)" >> this_temporary_list.txt; 
    fi
    echo -ne " #\n" >> this_temporary_list.txt;
  done
  cat this_temporary_list.txt | column -t | tr '#' '|' | sed -r '/jobs/{ :label.space; s@(jobs.*)\s{2}@\1 @; tlabel.space; }'
