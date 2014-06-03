xquery version "1.0-ml";

import module namespace api = "http://marklogic.com/rundmc/api"
       at "../model/data-access.xqy";

import module namespace setup = "http://marklogic.com/rundmc/api/setup"
       at "common.xqy";

import module namespace u="http://marklogic.com/rundmc/util"
       at "../../lib/util-2.xqy";

import module namespace raw = "http://marklogic.com/rundmc/raw-docs-access"
       at "raw-docs-access.xqy";

import module namespace xhtml="http://marklogic.com/cpf/xhtml"
   at "/MarkLogic/conversion/xhtml.xqy";

declare variable $config := u:get-doc("/apidoc/config/static-docs.xml")
                                  /static-docs;
declare variable $subdirs-to-load := $config/include/string(.);

declare variable $src-dir  := xdmp:get-request-field("srcdir");
declare variable $pubs-dir := concat($src-dir,'/pubs');

declare variable $ga as element() := 
(: google analytics script goes just before the closing the </head> tag :)
<script type="text/javascript"><![CDATA[
  var is_prod = document.location.hostname == 'docs.marklogic.com';
  var acct = is_prod ? 'UA-6638631-1' : 'UA-6638631-3';
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', acct], ['_setDomainName', 'marklogic.com'], ['_trackPageview']);
            
  (function() {
      var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
      ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
      var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
            })();]]>
</script> ;

declare variable $gtm :=
<!-- Google Tag Manager --> ,
<noscript><iframe src="//www.googletagmanager.com/ns.html?id=GTM-MBC6N2"
height="0" width="0" style="display:none;visibility:hidden"></iframe>
</noscript> ,
<script><![CDATA[if ( document.location.hostname == 'docs.marklogic.com') {
(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
'//www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
})(window,document,'script','dataLayer','GTM-MBC6N2'); } ]]> </script> ,
<!-- End Google Tag Manager --> ;

declare variable $marketo as element() := 
(: marketo script goes just before the closing the </body> tag :)
<script type="text/javascript"><![CDATA[
 (function() {
      function initMunchkin() {
      Munchkin.init('371-XVQ-609');
    }
    var s = document.createElement('script');
    s.type = 'text/javascript';
    s.async = true;
    s.src = document.location.protocol + '//munchkin.marketo.net/munchkin.js';
    s.onreadystatechange = function() {
        if (this.readyState == 'complete' || this.readyState == 'loaded') {
            initMunchkin();
          }
        };
    s.onload = initMunchkin;
    document.getElementsByTagName('body')[0].appendChild(s);
    })();]]>
</script> ;

declare function local:passthru($x as node()) as node()*
{
for $z in $x/node() return local:add-scripts($z)
};

declare function local:add-scripts($x as node()) as node()* {
typeswitch ($x)
  case document-node() return document {local:passthru($x)}
  case binary() return $x
  case comment() return $x
  case processing-instruction() return $x
  case text() return $x
  case element (body) return <body>{$gtm, local:passthru($x)}</body>
  case element (BODY) return <body>{$gtm, local:passthru($x)}</body>
  
  default return element {fn:node-name($x)} {$x/@*, local:passthru($x)}
};

declare function local:rewrite-uri($uri) {
  if (starts-with($uri,"/javaclient")) 
  then replace($uri,"/javaclient/javadoc/", "/javadoc/client/")
  else if (starts-with($uri,"/hadoop/"))    
    then replace($uri,"/hadoop/javadoc/","/javadoc/hadoop/") 
    (: Move "/javadoc" to the beginning of the URL :)
    else if (starts-with($uri,"/javadoc/"))   
      then replace($uri,"/javadoc/","/javadoc/xcc/")
      else if (starts-with($uri,"/dotnet/"))    
      then replace($uri,"/dotnet/",  "/dotnet/xcc/")
        else if (starts-with($uri,"/c++/"))       
        then replace($uri,"/c\+\+/", "/cpp/udf/")

        (: ASSUMPTION: the java docs don't include any PDFs :)
        else if (ends-with($uri,".pdf"))          
        then local:pdf-uri($uri)

         (: By default, don't change the URI (e.g., for C++ docs) :)
         else error(xs:QName("ERROR"), 
             concat("No case was found for rewriting this path: ", $uri))
};

declare function local:pdf-uri($uri) {
  let $pdf-name      := replace($uri, ".*/(.*).pdf", "$1"),
      $guide-configs := u:get-doc("/apidoc/config/document-list.xml")//guide,
      $url-name      := $guide-configs[(@pdf-name,@source-name)[1] eq $pdf-name]
                          /@url-name
  return
  (
    if (not($url-name)) 
    then error(xs:QName("ERROR"), concat("The configuration for ",$uri,
          " is missing in /apidoc/config/document-list.xml")) 
    else (),
    concat("/guide/",$url-name,".pdf")
  )
};

(: Recursively load all files :)
declare function local:load-pubs-docs($dir) {
  let $entries := xdmp:filesystem-directory($dir)/dir:entry return
  (
    (: Load files in this directory :)
    for $file in $entries[dir:type eq 'file']
    let $path    := $file/dir:pathname,
        $uri     := concat("/apidoc/", $api:version, 
                      local:rewrite-uri(translate(substring-after($path,
                                                     $pubs-dir),"\","/"))),
        $is-mangled-html := ends-with($uri,'-members.html'),
        $is-html := ends-with($uri,'.html'),
        $is-jdoc := contains($uri,'/javadoc/') and $is-html,
        $is-js   := ends-with($uri,'.js'),
        $is-css  := ends-with($uri,'.css'),
        $tidy-options := <options xmlns="xdmp:tidy">
                               <input-encoding>utf8</input-encoding>
                               <output-encoding>utf8</output-encoding>
                               <clean>true</clean>
                             </options>,

        (: If the document is JavaDoc HTML, then read it as text; 
           if it's other HTML, repair it as XML (.NET docs) 
           Also, add the ga and marketo scripts to the javadoc  :)
        (: don't tidy index.html because tidy throws away the frameset :)
        $doc := if ( $is-jdoc and not(contains($uri, '/index.html')) ) 
        then 
        xdmp:tidy(xdmp:document-get($path, 
        <options xmlns="xdmp:document-get">
          <format>text</format>
          <encoding>auto</encoding>
        </options>), <options xmlns="xdmp:tidy">
                               <input-encoding>utf8</input-encoding>
                               <output-encoding>utf8</output-encoding>
                               <output-xhtml>no</output-xhtml>
                               <output-xml>no</output-xml>
                               <output-html>yes</output-html>
                             </options>)[2]
        else if ($is-mangled-html) 
             then
             try{ xdmp:log("TRYING FULL TIDY CONVERSION"),
               let $unparsed := xdmp:document-get($path, 
               <options xmlns="xdmp:document-get">
                 <format>text</format>
               </options>)/string(),
                   $replaced := replace($unparsed, '"class="', '" class="')
               return 
               xdmp:unquote($replaced, "", "repair-full") }
             catch($e) { xdmp:log(fn:concat("Tidy FAILED for ", $path, 
                                            " so loading as text")),
               xdmp:document-get($path, <options xmlns="xdmp:document-get">
                                           <encoding>auto</encoding>
                                         </options>)} 
             else if ($is-html) then
            try{ xdmp:log("TRYING FULL CONVERSION"),
             xdmp:document-get($path, <options xmlns="xdmp:document-get">
                                        <format>xml</format>
                                        <repair>full</repair>
                                        <encoding>UTF-8</encoding>
                                      </options>) }
            catch($e){ if ($e/*:code eq 'XDMP-DOCUTF8SEQ') then
             xdmp:document-get($path, <options xmlns="xdmp:document-get">
                                        <format>xml</format>
                                        <repair>full</repair>
                                        <encoding>ISO-8859-1</encoding>
                                       </options>)
                        else error((),"Load error", xdmp:quote($e)) } 
             else 
               xdmp:document-get($path, <options xmlns="xdmp:document-get">
                                           <encoding>auto</encoding>
                                         </options>), 
            (: Otherwise, just load the document normally :)

        (: Exclude these HTML and javascript documents from the search corpus 
           (search the Tidy'd XHTML instead; see below) :)
        $collection := if ($is-jdoc or $is-js or $is-css) 
                       then "hide-from-search"
                       else ()
    return
    (
      xdmp:document-insert($uri, local:add-scripts($doc), 
         xdmp:default-permissions(), $collection),
      xdmp:log(concat("Loading ",$path," to ",$uri)),

      (: If the document is HTML, then store an additional copy, converted to
         XHTML using Tidy;
         this is using the same mechanism as the CPF "convert-html" action, 
         except that this is done synchronously. This XHTML copy is what's 
         used for search, snippeting, etc. :)
      if ($is-jdoc)
      then
        let  $xhtml :=
        try{ xdmp:log("TRYING FULL TIDY CONVERSION with xhtml:clean"),
        xhtml:clean(xdmp:tidy($doc, $tidy-options)[2]) }
        catch($e){ xdmp:log(fn:concat($path, " failed tidy conversion with ",
                   $e/*:code/string())),
        $doc }
        ,
            $xhtml-uri := replace($uri, "\.html$", "_html.xhtml")
        return
        (
          xdmp:document-insert($xhtml-uri, local:add-scripts($xhtml)),
          xdmp:log(concat("Tidying ",$path," to ",$xhtml-uri))
        )
      else ()
    ),

    (: Process sub-directories :)
    for $subdir in $entries[dir:type eq 'directory'] return
      local:load-pubs-docs($subdir/dir:pathname)
  )
};

$setup:errorCheck,

(: TODO: Load only the included directories :)
for $included-dir in xdmp:filesystem-directory($pubs-dir)
    /dir:entry[dir:type eq 'directory'][dir:filename = $subdirs-to-load]
    /dir:pathname/string(.)
return
(
  xdmp:log(concat("Loading static docs from: ", $included-dir)),
  local:load-pubs-docs($included-dir)
),

let $zip-file-name := concat(tokenize($src-dir,"/")[last()],".zip"),
    $zip-file-path := concat($src-dir, ".zip"),
    $zip-file      := xdmp:document-get($zip-file-path),
    $zip-file-uri  := concat("/apidoc/",$zip-file-name)
return
(
  xdmp:log(concat("Loading ",$zip-file-name," to ",$zip-file-uri)),
  xdmp:document-insert($zip-file-uri, $zip-file)
),

xdmp:log("Done loading static docs.")
