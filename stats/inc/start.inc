<%
set stat [ns_adp_argv 1]
set debug [ns_adp_argv 2]

set user [ns_conn authuser]
set password [ns_conn authpassword]

if {[nsstats::authenticate $user $password] == 0} {
    ns_returnunauthorized
}

if {![string length $debug]} {
    set debug "false"
}

set title [nsstats::getStatDescription $stat]
%>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
<head>
    <title><%=$title%></title>
    <link rel="stylesheet" type="text/css" href="css/stats.css">
    <script type="text/javascript">
        djConfig = {
            isDebug: <%=$debug%>
        };
    </script>
    <script src="dojo/dojo.js"></script>
    <script type="text/javascript">
        dojo.require("dojo.widget.FilteringTable");
        dojo.hostenv.writeIncludes();
    </script>
    <script src="js/stats.js"></script>
</head>
<body>
