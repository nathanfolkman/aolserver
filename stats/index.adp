<%
set debug [ns_queryget debug "false"]
set stat [ns_queryget stat]

ns_adp_include inc/start.inc $stat $debug

if {![nsstats::statExists $stat]} {
    ns_adp_include inc/nav.inc 
    ns_adp_include inc/menu.inc
} else {
    ns_adp_include inc/nav.inc $stat
    ns_adp_include inc/stats.inc $stat
}
  
ns_adp_include inc/end.inc
%>
