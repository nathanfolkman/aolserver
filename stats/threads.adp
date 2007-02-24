<%
set debug [ns_queryget debug "false"]

set title "Threads"
set url "json/threads.json"
  
ns_adp_include inc/start.inc $title $debug
ns_adp_include inc/header.inc $title
ns_adp_include inc/threads.inc $url
ns_adp_include inc/end.inc
%>
