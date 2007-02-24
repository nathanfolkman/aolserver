<%
set stat [ns_adp_argv 1]

set stats [nsstats::getStats]
set links ""

foreach s $stats {
    set description [nsstats::getStatDescription $s]
 
    if {[string match $stat $s]} {
        lappend links "<b>$description</b>"
    } else {
        lappend links "<a href=index.adp?stat=$s>$description</a>"
    }
}
%>

<div id=nav><%=[join $links " | "]%></div>
<div>
    <div id=name style="float:left"><h2><%=[nsstats::getStatDescription $stat]%></h2></div>
    <div style="float:right">
        <div id=pause>
            <a href="javascript:controlStats('pause');">Pause</a>
        </div>
        <div id=resume style="display:none">
            <a href="javascript:controlStats('resume');">Resume</a>
        </div>
    </div>
</div>

<script>
    var UpdateStats = 1;
</script>
