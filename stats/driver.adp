<%
set debug [ns_queryget debug "false"]

set title "Driver"
set url "json/driver.json"

ns_adp_include inc/start.inc $title $debug
ns_adp_include inc/header.inc $title
ns_adp_include inc/driver.inc $url
ns_adp_include inc/end.inc
%>
