<%
set stat [ns_adp_argv 1]
%>

<script type="text/javascript">
    dojo.require("dojo.io.*");
    dojo.addOnLoad(getData);
  
    function getData() {
        dojo.io.bind ({
            url: 'json/<%=$stat%>.json',
            load: function(type, data, evt) {
                updateTimestamp(data.timestamp);
                setText('error', '');
                
                var statsData = [];
              
                for (row in data.rows) {
                    var socks = data.rows[row]['socks'];
                    var sockStr = "";
 
                    for (sock in socks) {
                        sockStr = sockStr + socks[sock]['id'] + ' (' + socks[sock]['state'] + ') <br>';
                    }
                    
                    var o = new Object();
                    
                    o.Id = row
                    
                    for (field in data.headers) {
                		var type = data.headers[field]['type']
                		var value = data.rows[row][field]
                		
                		if (type == 'number') {
                                    if (value == '') {
                                        o[field] = null
                                    } else {
                		    o[field] = parseInt(value)
                                    }
                		} else if (type == 'date') {
                		    var date = new Date()
                		    date.setTime(value * 1000)
                		    
                		    o[field] = date
                		} else {
                		    o[field] = value
                		}
                	}
                
                    statsData.push(o);
                }
                
                var w = dojo.widget.byId("statsTable");
                
                w.store.clearData();
    		    w.store.setData(statsData);
                
                updateStats();
            },
            error: function(type, error) {
                updateError(type, error);
                updateStats();
            },
            mimetype: "text/json"
        });
    }
</script>

<div id='error'></div>
<div id='timestamp'></div>
<div id='stats'>
    <table dojoType="filteringTable" id="statsTable" 
        multiple="false" alternateRows="true"
        cellpadding="0" cellspacing="0" border="0" style="margin-bottom:24px;">
        <thead>
        <tr id=tableHeaderRow>

<%
foreach colName [nsstats::getColumns $stat] {
    set colFields [nsstats::getColumn $stat $colName]
    set title [lindex $colFields 1]
    set type [lindex $colFields 2]
    set format ""

    switch $type {
        "date" {
            set format "format=\"%r (%D)\""
            set align "left"
        }
        "number" {
            set align "right"
        }
        default { 
            set align "left"
        }
    }

    ns_adp_puts "<th field=\"$colName\" dataType=\"$type\" align=\"$align\" $format>$title</th>"
}
%>

        </tr>
    	</thead>
    </table>
</div>
