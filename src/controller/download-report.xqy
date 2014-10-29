xquery version "1.0-ml";
declare namespace html = "http://www.w3.org/1999/xhtml";
declare option xdmp:output "method=html";
    
if (xdmp:get-request-field("csv")) then

let $_ := xdmp:set-response-content-type('text/csv')

let $csv := 
string-join(

for $download in /person/download
let $person := $download/..
order  by $download/date/string() descending
return
string-join(
(
 concat('"', $person/name/string(), '"'), 
 concat('"', $person/email/string(), '"'), 
 concat('"', fn:format-dateTime($download/date, "[Y01]/[M01]/[D01] [H01]:[m01]:[s01]:[f01]"), '"'),
 concat('"', $download/path/string(), '"'),
 concat('"', $person/country/string(), '"'), 
 concat('"', $person/organization/string(), '"'), 
 concat('"', $download/fwded-for/string(), '"'), 
 ""
),
","
)

,
"
"
)
return $csv

    
else

let $total := fn:count(/person/download)
let $_ := xdmp:set-response-content-type('text/html')
return

(xdmp:set-response-content-type("text/html"),
'<!DOCTYPE html>',
<html lang="en">
<head>
  <style type="text/css">
      body {{ font: 14px/129% Arial, Helvetica, Sans-serif;}}
      table {{ border-collapse: collapse; }}
      td, th {{ border: 1px solid #666; padding: 3px;}}
  </style>
  <link href="/flexigrid-1.1/css/flexigrid-pack.css" rel="stylesheet" type="text/css" media="screen" />
  <script type="text/javascript" src="/js/modernizr.js"></script>
  <script type="text/javascript" src="/js/jquery-1.6.4.min.js"></script>
  <script type="text/javascript" src="/flexigrid-1.1/js/flexigrid-pack.js"></script>
</head>
<body>
<section>
Total downloads to date: {$total} 
&#160;&#160;<button id="button" value="Export to CSV">Export to CSV</button>
</section>

<div>&#160;</div>

<table class="datatable">
<thead>
<tr>
<th><b>Name</b></th>
<th><b>Email</b></th>
<th><b>Date</b></th>
<th><b>Download</b></th>
<th><b>Country</b></th>
<th><b>Organization</b></th>
<th><b>Client</b></th>
</tr>
</thead>
{
for $i in /person/download
order  by $i/date/string() descending
return
<tr>
<td>{$i/../name/string()}</td>
<td>{$i/../email/string()}</td>
<td>{fn:format-dateTime($i/date,"[Y01]/[M01]/[D01] [H01]:[m01]:[s01]:[f01]")}</td>
<td>{$i/path/string()}</td>
<td>{$i/../country/string()}</td>
<td>{$i/../organization/string()}</td>
<td>{$i/fwded-for/string()}</td>
</tr>
}
</table>
</body>
<script type="text/javascript">
    $(document).ready(function() {{
        $('#button').click(function() {{
            window.location = '/download-report?csv=1';
        }});
    }});
</script>
</html>
)
