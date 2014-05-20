xquery version "1.0-ml";
(: setup functions. :)

module namespace stp="http://marklogic.com/rundmc/api/setup" ;

declare default function namespace "http://www.w3.org/2005/xpath-functions";

import module namespace u="http://marklogic.com/rundmc/util"
  at "/lib/util-2.xqy";

import module namespace api="http://marklogic.com/rundmc/api"
  at "/apidoc/model/data-access.xqy";
import module namespace raw="http://marklogic.com/rundmc/raw-docs-access"
  at "raw-docs-access.xqy";
import module namespace toc="http://marklogic.com/rundmc/api/toc"
  at "toc.xqm";

import module namespace xhtml="http://marklogic.com/cpf/xhtml"
  at "/MarkLogic/conversion/xhtml.xqy";

declare namespace apidoc="http://marklogic.com/xdmp/apidoc";

declare namespace xh="http://www.w3.org/1999/xhtml" ;

declare variable $TITLE-ALIASES := u:get-doc(
  '/apidoc/config/title-aliases.xml')/aliases ;

declare variable $toc-dir     := concat("/media/apiTOC/",$api:version,"/");
declare variable $toc-xml-uri := concat($toc-dir,"toc.xml");
declare variable $toc-uri     := concat($toc-dir,"apiTOC_", current-dateTime(), ".html");

declare variable $toc-default-dir         := concat("/media/apiTOC/default/");
declare variable $toc-uri-default-version := concat($toc-default-dir,"apiTOC_", current-dateTime(), ".html");

declare variable $processing-default-version := $api:version eq $api:default-version;

declare variable $LEGAL-VERSIONS as xs:string+ := u:get-doc(
  "/config/server-versions.xml")/*/version/@number ;

(: TODO must not assume HTTP environment. :)
declare variable $errorCheck := (
  if (not($api:version-specified)) then error(
    (), "ERROR", "You must specify a 'version' param.")
  else ()) ;

(: TODO must not assume HTTP environment. :)
(: used in create-toc.xqy / toc-help.xsl :)
declare variable $helpXsdCheck := (
  if (not(xdmp:get-request-field("help-xsd-dir"))) then error(
    (), "ERROR", "You must specify a 'help-xsd-dir' param.")
  else ()) ;

(: TODO skip for standalone? :)
declare variable $GOOGLE-ANALYTICS as element() :=
(: google analytics script goes just before the closing the </head> tag :)
<script type="text/javascript"><![CDATA[
  var is_prod = document.location.hostname == 'docs.marklogic.com';
  var acct = is_prod ? 'UA-6638631-1' : 'UA-6638631-3';
  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', acct], ['_setDomainName', 'marklogic.com'],
            ['_trackPageview']);

  (function() {
      var ga = document.createElement('script');
      ga.type = 'text/javascript'; ga.async = true;
      ga.src = ('https:' == document.location.protocol ? 'https://ssl'
               : 'http://www') + '.google-analytics.com/ga.js';
      var s = document.getElementsByTagName('script')[0];
      s.parentNode.insertBefore(ga, s);
            })();]]>
</script> ;

(: TODO skip for standalone? :)
declare variable $MARKETO as element() :=
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

declare function stp:log(
  $label as xs:string,
  $list as xs:anyAtomicType*,
  $level as xs:string)
as empty-sequence()
{
  xdmp:log(text { '[apidoc/setup/'||$label||']', $list }, $level)
};

declare function stp:fine(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
{
  stp:log($label, $list, 'fine')
};

declare function stp:debug(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
{
  stp:log($label, $list, 'debug')
};

declare function stp:info(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
{
  stp:log($label, $list, 'info')
};

declare function stp:warning(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
{
  stp:log($label, $list, 'warning')
};

declare function stp:error(
  $code as xs:string,
  $items as item()*)
as empty-sequence()
{
  error((), 'APIDOC-'||$code, $items)
};

declare function stp:assert-timestamp()
as empty-sequence()
{
  if (xdmp:request-timestamp()) then ()
  else stp:error(
    'NOTIMESTAMP',
    text {
      'Request should be read-only but has no timestamp.',
      'Check the code path for update functions.' })
};

declare function stp:element-rewrite(
  $e as element(),
  $new as node()*)
as element()
{
  element { node-name($e) } {
    $e/@*,
    $e/node(),
    $new }
};

(: Prune more? This code seems to expect head//head or body//body. :)
declare function stp:static-add-scripts($n as node())
  as node()*
{
  typeswitch($n)
  case document-node() return document { stp:static-add-scripts($n/node()) }
  case element(head) return stp:element-rewrite($n, $GOOGLE-ANALYTICS)
  case element(HEAD) return stp:element-rewrite($n, $GOOGLE-ANALYTICS)
  case element(body) return stp:element-rewrite($n, $MARKETO)
  case element(BODY) return stp:element-rewrite($n, $MARKETO)
  (: Any other element may have head or body children. :)
  case element() return element {fn:node-name($n)} {
    $n/@*,
    stp:static-add-scripts($n/node()) }
  (: Text, binary, comments, etc. :)
  default return $n
};

declare function stp:static-uri-rewrite($uri as xs:string)
as xs:string
{
  if (starts-with($uri,"/javaclient"))
  then replace($uri,"/javaclient/javadoc/", "/javadoc/client/")
  else if (starts-with($uri,"/hadoop/"))
  then replace($uri,"/hadoop/javadoc/","/javadoc/hadoop/")
  (: Move "/javadoc" to the beginning of the URI :)
  else if (starts-with($uri,"/javadoc/"))
  then replace($uri,"/javadoc/","/javadoc/xcc/")
  else if (starts-with($uri,"/dotnet/"))
  then replace($uri,"/dotnet/",  "/dotnet/xcc/")
  else if (starts-with($uri,"/c++/"))
  then replace($uri,"/c\+\+/", "/cpp/udf/")

  (: ASSUMPTION: the java docs don't include any PDFs :)
  else if (ends-with($uri,".pdf")) then stp:pdf-uri($uri)

  (: By default, don't change the URI (e.g., for C++ docs) :)
  else error((), "UNEXPECTED", ('path', $uri))
};

declare function stp:pdf-uri($uri as xs:string)
as xs:string?
{
  let $pdf-name      := replace($uri, ".*/(.*).pdf", "$1"),
      $guide-configs := u:get-doc("/apidoc/config/document-list.xml")//guide,
      $url-name      := $guide-configs[(@pdf-name,@source-name)[1] eq $pdf-name]
                          /@url-name
  return
  (
    if (not($url-name))
    then error((), "ERROR", concat("The configuration for ",$uri,
          " is missing in /apidoc/config/document-list.xml"))
    else (),
    concat("/guide/",$url-name,".pdf")
  )
};

(: look at document-list.xml to change url names based on that list :)
declare function stp:fix-guide-names(
  $s as xs:string,
  $num as xs:integer)
{
  let $x := xdmp:document-get(
    concat(xdmp:modules-root(), "/apidoc/config/document-list.xml"))
  let $source := $x//guide[@url-name ne @source-name]/@source-name/string()
  let $url := $x//guide[@url-name ne @source-name]/@url-name/string()
  let $count := count($source)
  return (
    if ($num eq $count + 1) then (xdmp:set($num, 9999), $s)
    else if ($num eq 9999) then $s
    else stp:fix-guide-names(replace($s, $source[$num], $url[$num]),
      $num + 1))
};

declare function stp:function-extract(
  $function as element(apidoc:function))
as element()*
{
  if ($function/@hidden/xs:boolean(.)) then () else
  let $mode := (
    if (xs:boolean($function/@is-javascript)) then 'javascript'
    else if ($function/@lib = $api:REST-LIBS) then 'REST'
    else 'xpath')
  let $external-uri := api:external-uri($function, $mode)
  let $internal-uri := api:internal-uri($external-uri)
  let $lib as xs:string := $function/@lib
  let $name as xs:string := $function/@name
  let $_ := stp:debug(
    'stp:function-extract',
    ('external', $external-uri,
      'internal', $internal-uri,
      'mode', $mode))
  (: This wrapper is necessary because the *:polygon() functions
   : are each (dubiously) documented as two separate functions so
   : that raises the possibility of needing to include two different
   : api:function elements in the same page.
   :)
  return element api:function-page {
    attribute xml:base { $internal-uri },
    (: For word search purposes. :)
    element api:function-name {
      api:fixup-fullname($function, $mode) },
    (: TODO why not just $function?
     : Seems to grab any functions from the same lib that share the same name.
     :)
    stp:fixup(
      $function/../apidoc:function[@name eq $name][@lib eq $lib],
      $mode) }
};

declare function stp:function-docs(
  $version as xs:string,
  $doc as document-node())
as element()*
{
  (: create XQuery/XSLT function pages :)
  stp:function-extract(
    api:module-extractable-functions($doc/apidoc:module, ())),
  (: create JavaScript function pages :)
  if (number($api:version) lt 8) then ()
  else stp:function-extract(
    api:module-extractable-functions($doc/apidoc:module, 'javascript'))
};

declare function stp:function-docs(
  $version as xs:string)
as empty-sequence()
{
  stp:info('stp:function-docs', ('starting', $version)),
  for $doc in raw:api-docs($version)
  let $_ := stp:debug(
    "stp:function-docs", ('starting', xdmp:describe($doc)))
  let $extracted as node()+ := stp:function-docs($version, $doc)
  for $func in $extracted
  let $uri := base-uri($func)
  let $_ := stp:debug(
    "stp:function-docs",
    ("inserting", xdmp:describe($doc), 'at', $uri))
  return xdmp:document-insert($uri, $func)
  ,
  stp:info("stp:function-docs", xdmp:elapsed-time())
};

declare function stp:search-results-page-insert()
as empty-sequence()
{
  stp:info('stp:search-results-page-insert', 'starting'),
  xdmp:document-insert(
    "/apidoc/do-search.xml",
    <ml:page xmlns:ml="http://developer.marklogic.com/site/internal"
    disable-comments="yes" status="Published"
    xmlns="http://www.w3.org/1999/xhtml" hide-from-search="yes">
      <h1>Search Results</h1>
      <ml:search-results/>
    </ml:page>),
  stp:info('stp:search-results-page-insert', ('ok', xdmp:elapsed-time()))
};

(: Load a static file.
 :)
declare function stp:zip-static-file-get(
  $zip as binary(),
  $path as xs:string,
  $is-html as xs:boolean,
  $is-jdoc as xs:boolean)
as document-node()
{
  let $is-mangled-html := ends-with($path, '-members.html')

  return (
    (: If the document is JavaDoc HTML, then read it as text;
     : if it's other HTML, repair it as XML (.NET docs)
     : Also, add the ga and marketo scripts to the javadoc.
     : Don't tidy index.html because tidy throws away the frameset.
     : TODO should this be ends-with rather than contains?
     :)
    if ($is-jdoc and not(contains($path, '/index.html'))) then xdmp:tidy(
      xdmp:zip-get(
        $zip,
        $path,
        <options xmlns="xdmp:document-get">
          <format>text</format>
          <encoding>auto</encoding>
        </options>
      ),
      <options xmlns="xdmp:tidy">
        <input-encoding>utf8</input-encoding>
        <output-encoding>utf8</output-encoding>
        <output-xhtml>no</output-xhtml>
        <output-xml>no</output-xml>
        <output-html>yes</output-html>
        </options>
      )[2]

    else if ($is-mangled-html) then try {
      stp:fine('stp:zip-static-file-get', ('trying unquote for', $path)),
      let $unparsed as xs:string := xdmp:zip-get(
        $zip,
        $path,
        <options xmlns="xdmp:document-get"
        ><format>text</format></options>)
      let $replaced := replace($unparsed, '"class="', '" class="')
      return xdmp:unquote($replaced, "", "repair-full") }
    catch($e) {
      stp:info(
        'stp:zip-static-file-get',
        ("loading", $path, "with encoding=auto because", $e/error:message)),
      xdmp:zip-get(
        $zip,
        $path,
        <options xmlns="xdmp:document-get"
        ><encoding>auto</encoding></options>) }
    else if ($is-html) then try {
      stp:fine(
        'stp:zip-static-file-get',
        ("trying html as XML UTF8")),
      xdmp:zip-get(
        $zip,
        $path,
        <options xmlns="xdmp:document-get">
          <format>xml</format>
          <repair>full</repair>
          <encoding>UTF-8</encoding>
        </options>
        ) }
    catch($e) {
      if ($e/error:code ne 'XDMP-DOCUTF8SEQ') then xdmp:rethrow()
      else xdmp:zip-get(
        $zip,
        $path,
        <options xmlns="xdmp:document-get">
          <format>xml</format>
          <repair>full</repair>
          <encoding>ISO-8859-1</encoding>
        </options>
      ) }
    (: Otherwise, just load the document normally :)
    else xdmp:zip-get(
      $zip,
      $path,
      <options xmlns="xdmp:document-get"><encoding>auto</encoding></options>))
};

declare function stp:zip-static-file-insert(
  $doc as document-node(),
  $uri as xs:string,
  $is-hidden as xs:boolean,
  $is-jdoc as xs:boolean)
as document-node()
{
  xdmp:document-insert(
    $uri,
    stp:static-add-scripts($doc),
    xdmp:default-permissions(),
    (: Exclude these HTML and javascript documents from the search corpus
     : Instead search the XHTML after tidy - see below.
     :)
    "hide-from-search"[$is-hidden]),
  stp:debug("static-file-insert", $uri),

  (: If the document is HTML, then store an additional copy,
   : converted to XHTML using Tidy.
   : This is using the same mechanism as the CPF "convert-html" action,
   : except that this is done synchronously. This XHTML copy is
   : used for search, snippeting, etc.
   :)
  if (not($is-jdoc)) then () else (
    stp:fine(
      'static-file-insert',
      ($uri, "trying xdmp:tidy with xhtml:clean")),
    let $tidy-options := (
      <options xmlns="xdmp:tidy">
        <input-encoding>utf8</input-encoding>
        <output-encoding>utf8</output-encoding>
        <clean>true</clean>
      </options>
    )
    let $xhtml := try {
      xhtml:clean(xdmp:tidy($doc, $tidy-options)[2]) }
    catch($e) {
      stp:info(
        'stp:zip-static-file-insert',
        ("failed tidy conversion with", $e/error:code)),
      $doc }
    let $xhtml-uri := replace($uri, "\.html$", "_html.xhtml")
    let $_ := stp:fine(
      'stp:zip-static-file-insert', ('Tidying', $uri, 'to', $xhtml-uri))
    return xdmp:document-insert($xhtml-uri, stp:static-add-scripts($xhtml)))
};

declare function stp:zip-static-docs-insert(
  $version as xs:string,
  $zip-path as xs:string,
  $zip as binary())
as empty-sequence()
{
  let $config := u:get-doc("/apidoc/config/static-docs.xml")/static-docs
  let $subdirs-to-load := $config/include/string()
  let $pubs-dir := '/pubs'
  for $e in xdmp:zip-manifest($zip)/*[
    contains(., '_pubs/pubs/') ][
    not(ends-with(., '/')) ][
    some $path in $subdirs-to-load
    satisfies starts-with(., $path) ]
  let $is-html := ends-with($e, '.html')
  let $is-jdoc := $is-html and contains($e, '/javadoc/')
  let $is-js := ends-with($e,'.js')
  let $is-css := ends-with($e,'.css')
  let $uri := concat(
    "/apidoc/", $version,
    '/', stp:static-uri-rewrite(substring-after($e, '_pubs/pubs/')))
  let $is-hidden := $is-jdoc or $is-js or $is-css
  let $doc := stp:zip-static-file-get($zip, $e, $is-html, $is-jdoc)
  return stp:zip-static-file-insert($doc, $uri, $is-hidden, $is-jdoc)
  ,

  (: Load the zip, to support downloads. :)
  let $zip-uri := concat(
    "/apidoc/", tokenize($zip-path, '/')[last()])
  let $_ := stp:info(
    "stp:zip-static-docs-insert",
    ("zip", $zip-path, "as", $zip-uri))
  return xdmp:document-insert($zip-uri, $zip)
  ,

  stp:info(
    'stp:zip-static-docs-insert',
    ("Loaded static docs in", xdmp:elapsed-time()))
};

declare function stp:zip-static-docs-insert(
  $version as xs:string,
  $zip-path as xs:string)
as empty-sequence()
{
  stp:zip-static-docs-insert(
    $version,
    $zip-path,
    xdmp:document-get($zip-path)/node())
};

declare function stp:zip-static-docs-insert(
  $zip-path as xs:string)
as empty-sequence()
{
  stp:zip-static-docs-insert(
    $api:version,
    $zip-path)
};

(: Delete all docs for a version. :)
declare function stp:docs-delete($version as xs:string)
as empty-sequence()
{
  stp:info('stp:docs-delete', $version),
  let $dir := concat('/media/apidoc/', $version, '/')
  let $_ := xdmp:directory-delete($dir)
  let $_ := stp:info(
    'stp:docs-delete', ($version, $dir, 'ok', xdmp:elapsed-time()))
  return ()
};

(: Delete all raw docs for a version. :)
declare function stp:raw-delete($version as xs:string)
as empty-sequence()
{
  stp:info('stp:raw-delete', $version),
  raw:invoke-function(
    function() {
      xdmp:directory-delete(concat("/", $version, "/")),
      xdmp:commit() },
    true())
};

declare function stp:toc-delete()
as empty-sequence()
{
  stp:info('stp:toc-delete', $api:version),
  let $dir := $toc-dir
  let $prefix := string(doc($api:toc-uri-location))
  for $toc-parts-dir in cts:uri-match(concat($dir,"*.html/"))
  let $main-toc := substring($toc-parts-dir,1,string-length($toc-parts-dir)-1)
  where not(starts-with($toc-parts-dir,$prefix))
  return (
    xdmp:document-delete($main-toc),
    xdmp:directory-delete($toc-parts-dir))
};

declare function stp:guide-convert(
  $version as xs:string,
  $guide as document-node()*)
as node()
{
  xdmp:xslt-invoke(
    "convert-guide.xsl", $guide,
    map:new(
      (map:entry('OUTPUT-URI', raw:target-guide-doc-uri($guide)),
        map:entry("VERSION", $version))))
};

declare function stp:guides-convert(
  $version as xs:string,
  $guides as document-node()*)
as empty-sequence()
{
  (: The slowest conversion is messages/XDMP-en.xml,
   : which always finishes last.
   :)
  for $g in $guides
  (:order by ends-with(xdmp:node-uri($g), '/XDMP-en.xml') descending:)
  let $start := xdmp:elapsed-time()
  let $converted := stp:guide-convert($version, $g)
  let $uri := base-uri($converted)
  let $_ := xdmp:document-insert($uri, $converted)
  let $_ := stp:debug(
    "stp:convert-guides", (base-uri($g), '=>', $uri,
      'in', xdmp:elapsed-time() - $start))
  return $uri
};

declare function stp:node-rewrite-namespace(
  $n as node(),
  $ns as xs:string)
as node()
{
  typeswitch($n)
  case document-node() return document {
    stp:node-rewrite-namespace($n/node(), $ns) }
  case element() return element { QName($ns, local-name($n)) } {
    $n/@*,
    stp:node-rewrite-namespace($n/node(), $ns) }
  default return $n
};

declare function stp:node-to-xhtml(
  $n as node())
as node()
{
  stp:node-rewrite-namespace(
    $n, "http://www.w3.org/1999/xhtml")
};

(: The container ID comes from the nearest ancestor (or self)
 : that is marked as asynchronously loaded,
 : unless nothing above this level is marked as such,
 : in which case we use the nearest ID.
 :)
declare function stp:container-toc-section-id(
  $e as element(toc:node))
as xs:string
{
  $e/(
    ancestor-or-self::toc:node[@async][1],
    ancestor-or-self::toc:node[@id]   [1] )[1]/@id
};

(: Input parent may be api:function-page or api:javascript-function-page. :)
declare function stp:list-entry(
  $function as element(api:function),
  $toc-node as element(toc:node))
as element(api:list-entry)
{
  element api:list-entry {
    $toc-node/@href,
    element api:name {
      (: Special-case the cts accessor functions; they should be indented.
       : This handles XQuery and JavaScript naming conventions.
       :)
      if (not($function/@lib eq 'cts'
          and $toc-node/@display ! (
            contains(., '-query-')
            or substring-after(., 'Query')))) then ()
      else attribute indent { true() },

      (: Function name; prefer @list-page-display, if present :)
      ($toc-node/@list-page-display,
        $toc-node/@display)[1]/string() treat as xs:string },
    element api:description {
      (: Extracting the first line from the summary :)
      concat(
        substring-before($function/api:summary, '.'),
        '.') } }
};

declare function stp:list-page-functions(
  $uri as xs:string,
  $toc-node as element(toc:node))
as element(api:list-page)
{
  element api:list-page {
    attribute xml:base { $uri },
    attribute disable-comments { true() },
    attribute container-toc-section-id {
      stp:container-toc-section-id($toc-node) },
    $toc-node/@*,

    $toc-node/toc:title ! element api:title {
      @*,
      stp:node-to-xhtml(node()) },
    $toc-node/toc:intro ! element api:intro {
      @*,
      stp:node-to-xhtml(node()) },

    (: Make an entry for document pointed to by
     : each descendant leaf node with a type.
     : This ignores internal guide links, which have no type.
     :)
    for $leaf in $toc-node//toc:node[not(toc:node)][@type]
    (: For multiple *:polygon() functions, only list the first. :)
    let $href as xs:string := $leaf/@href
    let $_ := stp:fine(
      'stp:list-page-functions',
      ($uri, 'leaf', xdmp:describe($leaf),
        'type', $leaf/@type, 'href', $href))
    let $uri-leaf as xs:string := api:internal-uri($href)
    let $root as document-node() := doc($uri-leaf)
    let $function as element() := $root/(
      api:function-page
      |api:javascript-function-page)/api:function[1]
    return stp:list-entry($function, $leaf) }
};

declare function stp:list-page-help-items(
  $toc-node as element(toc:node))
as element(xh:li)*
{
  (: TODO removed some weird-looking dedup code here. Did it matter? :)
  for $n in $toc-node//toc:node[@href]
  let $href as xs:string := $n/@href
  let $title as xs:string := $n/toc:title
  order by $title
  return <li xmlns="http://www.w3.org/1999/xhtml">
  {
    element a {
      attribute href { $href },
      $title }
  }
  </li>
};

declare function stp:list-page-help(
  $uri as xs:string,
  $toc-node as element(toc:node))
as element(api:help-page)
{
  element api:help-page {
    attribute xml:base { $uri },
    attribute disable-comments { true() },
    attribute container-toc-section-id {
      stp:container-toc-section-id($toc-node) },
    $toc-node/@*,
    stp:node-to-xhtml($toc-node/toc:title),
    (: Help index page is at the top :)
    if (not($toc-node/toc:content/@auto-help-list)) then stp:node-to-xhtml(
      $toc-node/toc:content)
    else element api:content {
      <div xmlns="http://www.w3.org/1999/xhtml">
        <p>
      The following is an alphabetical list of Admin Interface help pages:
        </p>
        <ul>
      {
        stp:list-page-help-items($toc-node)
      }
        </ul>
      </div>
    }
  }
};

(: Set up the docs page for this version. :)
declare function stp:list-page-root(
  $toc as element(toc:root))
as element()+
{
  element api:docs-page {
    attribute xml:base { api:internal-uri('/') },
    attribute disable-comments { true() },
    comment {
      'This page was automatically generated using',
      xdmp:node-uri($toc),
      'and /apidoc/config/document-list.xml' },

    let $guide-nodes as element()+ := $toc/toc:node[
      @id eq 'guides']/toc:node/toc:node[@guide]
    for $guide in $guide-nodes
    let $display as xs:string := lower-case(
      normalize-space($guide/@display))
    let $_ := stp:fine('stp:list-pages', (xdmp:describe($guide), $display))
    return element api:user-guide {
      $guide/@*,
      (: Facilitate automatic link creation at render time.
       : TODO why ../alias ?
       :)
      $stp:TITLE-ALIASES/guide/alias[
        ../alias/normalize-space(lower-case(.)) = $display] }
    ,

    comment { 'copied from /apidoc/config/title-aliases.xml:' },
    $stp:TITLE-ALIASES/auto-link }
};

(: Generate and insert a list page for each TOC container.
 : Because of the XSLT switch,
 : this may return document-node()+ or element()+.
 :)
declare function stp:list-pages-render(
  $toc-document as document-node())
as node()+
{
  stp:info(
    'stp:list-pages-render', ("starting", xdmp:describe($toc-document))),
  stp:list-page-root($toc-document/toc:root),
  (: Find each function list and help page URL. :)
  let $seq as xs:string+ := distinct-values(
    $toc-document//toc:node[@function-list-page or @admin-help-page]/@href)
  for $href in $seq
  let $uri := api:internal-uri($href)
  (: Any element with into or help content will have a title.
   : Process the first match.
   :)
  let $toc-node as element(toc:node) := (
    $toc-document//toc:node[@href eq $href][toc:title])[1]
  return $toc-node ! (
    if (@admin-help-page) then stp:list-page-help($uri, .)
    else if (@function-list-page) then stp:list-page-functions($uri, .)
    else stp:error('UNEXPECTED', xdmp:quote(.)))
  ,
  stp:info('stp:list-pages-render', ("ok", xdmp:elapsed-time()))
};

(: Generate and insert a list page for each TOC container :)
declare function stp:list-pages-render()
as empty-sequence()
{
  for $n in stp:list-pages-render(
    doc($toc-xml-uri) treat as node())
  let $uri as xs:string := base-uri($n)
  let $_ := if ($n/*
    or $n/self::*) then () else stp:error('EMPTY', ($uri, xdmp:quote($n)))
  let $_ := stp:debug(
    'stp:list-pages-render', ($uri))
  return xdmp:document-insert($uri, $n)
};

(: Recursively load all files, retaining the subdir structure :)
declare function stp:zip-load-raw-docs(
  $version as xs:string,
  $zip as binary())
as empty-sequence()
{
  raw:invoke-function(
    function() {
      for $e in xdmp:zip-manifest($zip)/*[
        contains(., '_pubs/pubs/raw/') ][
        not(ends-with(., '/')) ]
      let $uri as xs:string := concat(
        '/', $version,
        '/', substring-after($e, '_pubs/pubs/raw/'))
      let $_ := stp:debug('stp:zip-load-raw-docs', ($e, '=>', $uri))
      return xdmp:document-insert(
        $uri,
        xdmp:zip-get(
          $zip,
          $e,
          <options xmlns="xdmp:zip-get"
          ><encoding>auto</encoding></options>),
        xdmp:default-permissions(),
        $version)
      ,
      xdmp:commit() },
    true())
};

(: Recursively load all files, retaining the subdir structure :)
declare function stp:zip-load-raw-docs(
  $zip as binary())
as empty-sequence()
{
  stp:zip-load-raw-docs($api:version, $zip)
};

(: This should run in the raw database. :)
declare function stp:guides-consolidate-insert(
  $doc as node(),
  $title as xs:string?,
  $guide-title as xs:string?,
  $target-url as xs:string,
  $orig-dir as xs:string,
  $guide-uri as xs:string,
  $previous as xs:string?,
  $next as xs:string?,
  $number as xs:integer?,
  $chapter-list as element()?)
  as empty-sequence()
{
  stp:info(
    'stp:guides-consolidate-insert',
    (xdmp:describe($doc), xdmp:describe($title),
      xdmp:describe($guide-title), $target-url)),
  xdmp:document-insert(
    $target-url,
    element { if ($chapter-list) then "guide" else "chapter" } {
      attribute original-dir { $orig-dir },
      attribute guide-uri { $guide-uri },

      $previous ! attribute previous { . },
      $next ! attribute next { . },
      $number ! attribute number { . },

      element guide-title { $guide-title },
      element title { $title },

      element XML {
        attribute original-file { concat('file:',base-uri($doc)) },
        $doc/XML/node() },

      $chapter-list })
};

(: This should run in the raw database. :)
declare function stp:guide-consolidate-chapter(
  $dir as xs:string,
  $guide-title as xs:string,
  $final-guide-uri as xs:string,
  $chapter as element(chapter))
as element(chapter)
{
  let $chapter-doc   := doc($chapter/@source-uri)
  let $chapter-num   := 1 + count($chapter/preceding-sibling::chapter)
  let $chapter-title := normalize-space($chapter-doc/XML/Heading-1)
  let $next as xs:string? := $chapter/following-sibling::chapter[1]/@final-uri
  let $previous := (
    $chapter/preceding-sibling::chapter[1]/@final-uri,
    $final-guide-uri)[1]
  let $_ := stp:guides-consolidate-insert(
    $chapter-doc, $chapter-title, $guide-title,
    $chapter/@target-uri, $dir, $final-guide-uri,
    $previous, $next, $chapter-num, ())
  return element chapter {
    attribute href { $chapter/@final-uri },
    element chapter-title { $chapter-title } }
};

(: This should run in the raw database. :)
declare function stp:guide-consolidate(
  $version as xs:string,
  $dir as xs:string,
  $dir-name as xs:string,
  $guide-config as element(guide)?)
as empty-sequence()
{
  let $title-doc := doc(concat($dir,'title.xml'))
  let $guide-title := $title-doc/XML/Title/normalize-space(.)
  let $url-name := (
    if ($guide-config) then $guide-config/@url-name
    else $dir-name)
  let $target-url   := concat("/",$version,"/guide/",$url-name,".xml")
  let $final-guide-uri := raw:target-guide-doc-uri-for-string($target-url)
  let $chapters := xdmp:directory($dir)[XML] except $title-doc
  (: In two stages,
   : so we can get the next and previous chapter links in the next stage.
   :)
  (: Get each chapter doc in order :)
  let $chapter-manifest := element chapters {
    for $doc in $chapters
    let $uri := base-uri($doc)
    let $chapter-file-name  := substring-after($uri, $dir)
    let $chapter-target-uri := concat(
      "/",$version,"/guide/",$url-name,"/",$chapter-file-name)
    order by number(normalize-space($doc/XML/pagenum))
    return element chapter {
      attribute source-uri {$uri},
      attribute target-uri {$chapter-target-uri},
      attribute final-uri {
        raw:target-guide-doc-uri-for-string($chapter-target-uri)} } }
  (: This inserts chapter documents and creates a manifest. :)
  let $chapter-list := element chapter-list {
    stp:guide-consolidate-chapter(
      $dir, $guide-title, $final-guide-uri,
      (: Function mapping. :)
      $chapter-manifest/chapter) }
  let $first-chapter-uri := $chapter-manifest/chapter[1]/@final-uri
  let $_ := stp:info(
    'stp:guides-consolidate', (xdmp:describe($chapter-manifest)))
  return stp:guides-consolidate-insert(
    $title-doc, $guide-title, $guide-title,
    $target-url, $dir, $final-guide-uri,
    (), $first-chapter-uri, (),
    $chapter-list)
};

declare function stp:guides-consolidate($version as xs:string)
  as empty-sequence()
{
  raw:invoke-function(
    function() {
      (: Directory in which to find guide XML for the server version :)
      let $guides-dir := concat("/", $version, "/xml/")
      (: The list of guide configs :)
      let $guide-list as element()+ := u:get-doc(
        "/apidoc/config/document-list.xml")/docs/*/guide
      (: Assume every guide has a title.xml document.
       : This might seem inefficient,
       : but consider that we will want to look at most of these documents.
       : Anyway we probably just loaded them, so they should be cached.
       :)
      let $directory-uris as xs:string+ := (
        xdmp:directory(
          $guides-dir, 'infinity')/xdmp:node-uri(.)[
          ends-with(., '/title.xml')]
        ! substring-before(., '/title.xml')
        ! concat(., '/'))
      for $dir in $directory-uris
      (: Basename of each dir, not including the full path to it :)
      let $dir-name := substring-before(
        substring-after($dir, $guides-dir), "/")
      let $guide-config as element(guide)? := $guide-list[
        @source-name eq $dir-name]
      where not($guide-config/@exclude)
      return stp:guide-consolidate(
        $version, $dir, $dir-name, $guide-config)
      ,
      xdmp:commit(),
      stp:info('stp:guides-consolidate', 'ok') },
    (: This is an update. :)
    true())
};

declare function stp:guide-images(
  $version as xs:string)
as empty-sequence()
{
  stp:info('stp:guide-images', $version),
  let $guide-docs as node()+ := raw:guide-docs($version)
  for $doc in $guide-docs
  let $base-dir := string($doc/(guide|chapter)/@original-dir)
  let $img-dir := api:guide-image-dir(raw:target-guide-doc-uri($doc))
  (: Copy every distinct image referenced by this guide.
   : Images are not shared across guides.
   :)
  for $img-path in distinct-values($doc//IMAGE/@href)
  let $source-uri := resolve-uri($img-path, $base-dir)
  let $dest-uri := concat($img-dir, $img-path)
  let $_ := stp:info('stp:guide-images', ($source-uri, "to", $dest-uri))
  return xdmp:document-insert($dest-uri, raw:get-doc($source-uri))
};

declare function stp:fixup-attribute-href(
  $a as attribute(href))
as attribute()?
{
  if (not($a/parent::a or $a/parent::xh:a)) then $a
  else attribute href {
    (: Fixup Linkerator links
     : Change "#display.xqy&fname=http://pubs/5.1doc/xml/admin/foo.xml"
     : to "/guide/admin/foo"
     :)
    if (starts-with(
        $a/../@href, '#display.xqy?fname=')) then (
      let $anchor := replace(
        substring-after($a, '.xml'), '%23', '#id_')
      return stp:fix-guide-names(
        concat('/guide',
          substring-before(
            substring-after($a, 'doc/xml'), '.xml'),
          $anchor), 1))

    (: If a fragment id contains a colon, it is a link to a function page.
     : TODO JavaScript handle fn.abs etc.
     : Change, e.g., #xdmp:tidy to /xdmp:tidy
     :)
    else if (starts-with($a, '#') and contains($a, ':')) then translate(
      $a, '#', '/')

    (: A relative fragment link points somewhere in the same apidoc:module. :)
    else if (starts-with($a, '#')) then (
      let $fid := substring-after($a, '#')
      let $relevant-function := $a/root()/apidoc:module/apidoc:function[
        .//*/@id eq $fid]
      let $result as xs:string := (
        (: Link within same page. :)
        if ($a/ancestor::apidoc:function is $relevant-function) then '.'
        (: If we are on a different page, insert a link to the target page. :)
        else (
          (: REST URLs are written differently than function URLs :)
          (: path to resource page :)
          if ($relevant-function/@lib
            = $api:REST-LIBS) then api:REST-fullname-to-external-uri(
            api:fixup-fullname($relevant-function, 'REST'))
          (: regular function page :)
          (: path to function page TODO add mode when javascript :)
          else '/'||api:fixup-fullname($relevant-function, ())))
      return $result)

    (: For an absolute path like http://w3.org leave the value alone. :)
    else if (contains($a, '://')) then $a

    (: Handle some odd corner-cases. TODO maybe dead code? :)
    else if ($a
      eq 'apidocs.xqy?fname=UpdateBuiltins#xdmp:document-delete') then '/xdmp:document-delete'
    (: as we configured in config/category-mappings.xml :)
    else if ($a =
      ('apidocs.xqy?fname=cts:query Constructors',
        'SearchBuiltins&amp;sub=cts:query Constructors')) then '/cts/constructors'

    (: Otherwise, assume a function page with an optional fragment id,
     : so we need only prepend a slash.
     :)
    else concat('/', $a) }
};

declare function stp:fixup-attribute-lib(
  $a as attribute(lib))
as attribute()?
{
  if (not($a/parent::apidoc:function)) then $a
  else attribute lib {

    (: Change the "spell" library to "spell-lib"
     : to disambiguate from the built-in "spell" module.
     :)
    if ($a eq 'spell' and not($a/../@type eq 'builtin')) then 'spell-lib'
    (: Similarly, change the "json" library to "json-lib"
     : to disambiguate from the built-in "json" module.
     :)
    else if ($a eq 'json' and not($a/../@type eq 'builtin')) then 'json-lib'
    (: Change the "rest" library to "rest-lib"
     : because we reserve the "/REST/" prefix for the REST API docs.
     : We do not want case to be the only difference.
     :)
    else if ($a eq 'rest') then 'rest-lib'
    (: Change designated values to "REST",
     : so the TOC code treats it like a library with that name.
     :)
    else if ($a = $api:REST-LIBS) then 'REST'
    else $a}
};

declare function stp:fixup-attribute-name(
  $a as attribute(name))
as attribute()?
{
  if (not($a/parent::apidoc:function)) then $a
  else attribute name {
    (: fixup apidoc:function/@name for javascript :)
    if (xs:boolean($a/../@is-javascript)) then api:javascript-name($a)
    else $a }
};

(: Ported from fixup.xsl,
 : where it was only used by extract-functions.
 :)
declare function stp:fixup-attribute(
  $a as attribute())
as attribute()?
{
  typeswitch($a)
  case attribute(href) return stp:fixup-attribute-href($a)
  case attribute(lib) return stp:fixup-attribute-lib($a)
  case attribute(name) return stp:fixup-attribute-name($a)
  (: By default, return the input. :)
  default return $a
};

declare function stp:fixup-attributes-new($e as element())
as attribute()*
{
  typeswitch($e)
  case element(apidoc:function) return (
    (: Add the prefix and namespace URI of the function. :)
    attribute prefix { $e/@lib },
    attribute namespace { api:uri-for-lib($e/@lib) },
    (: Add the @fullname attribute, which we depend on later.
     : This depends on the @is-javascript attribute,
     : which is faked in api:function-fake-javascript.
     :)
    attribute fullname {
      api:fixup-fullname(
        $e,
        if (starts-with($e/@name, '/')) then 'REST'
        else if (xs:boolean($e/@is-javascript)) then 'javascript'
        else ()) })
  default return ()
};

declare function stp:fixup-element-name($e as element())
as xs:anyAtomicType
{
  (: Move "apidoc" elements to the "api" namespace,
   : to avoid confusion.
   :)
  if ($e/self::apidoc:*) then QName($api:NAMESPACE, local-name($e))
  else node-name($e)
};

declare function stp:schema-info(
  $xse as element(xs:element))
as element(api:element)
{
  (: ASSUMPTION: all the element declarations are global.
   : ASSUMPTION: the schema default namespace is the same as
   : the target namespace (@ref uses no prefix).
   :)
  let $current-ref := $xse/@ref/string()
  let $root := $xse/root()
  let $element-decl := $root/xs:schema/xs:element[
    @name eq $current-ref]
  (: This is natively a QName,
   : but we assume we can ignore namespace prefixes.
   :)
  let $element-decl-type := $element-decl/@type/string()
  let $complexType := $root/xs:schema/xs:complexType[
    @name eq $element-decl-type]
  return element api:element {
    element api:element-name { $current-ref },
    element api:element-description {
      $element-decl/xs:annotation/xs:documentation },
    (: Recursion continues via function mapping.
     : TODO Could this get into a loop?
     :)
    stp:schema-info($complexType//xs:element)
  }
};

declare function stp:fixup-children-apidoc-usage(
  $e as element(apidoc:usage),
  $context as xs:string*)
as node()*
{
  if (not($e/@schema)) then stp:fixup($e/node(), $context) else (
    let $current-dir := string-join(
      tokenize(base-uri($e), '/')[position() ne last()], '/')
    let $schema-uri := concat(
      $current-dir, '/',
      substring-before($e/@schema,'.xsd'), '.xml')
    (: This logic and attendant assumptions come from the docapp code. :)
    let $function-name := string($e/../@name)
    let $is-REST-resource := starts-with($function-name,'/')
    let $given-name := ($e/@element-name, $e/../@name)[1]/string()
    let $complexType-name := (
      if ($is-REST-resource and not($e/@element-name))
      then api:lookup-REST-complexType($function-name)
      else $given-name)
    let $print-intro-value := (string($e/@print-intro), true())[1]
    where $complexType-name
    return (
      stp:fixup($e/node(), $context),
      element api:schema-info {
        if (not($is-REST-resource)) then () else (
          attribute REST-doc { true() },
          attribute print-intro { $print-intro-value }),
        let $schema := raw:get-doc($schema-uri)/xs:schema
        let $complexType := $schema/xs:complexType[@name eq $complexType-name]
        (: This presumes that all the element declarations are global,
         : and complex type contains only element references.
         :)
        return stp:schema-info($complexType//xs:element) }))
};

declare function stp:fixup-children(
  $e as element(),
  $context as xs:string*)
as node()*
{
  typeswitch($e)
  case element(apidoc:usage) return stp:fixup-children-apidoc-usage(
    $e, $context)
  default return stp:fixup($e/node(), $context)
};

declare function stp:fixup-element(
  $e as element(),
  $context as xs:string*)
as element()?
{
  (: Hide javascript-specific content
   : unless this is a javascript function page.
   :)
  if ($e/@class eq 'javascript' and not($context = 'javascript')) then ()
  else element { stp:fixup-element-name($e) } {
    stp:fixup-attribute($e/@*),
    stp:fixup-attributes-new($e),
    stp:fixup-children($e, $context) }
};

(: Ported from fixup.xsl
 : This takes care of fixing internal links and references,
 : and any other transform work.
 :)
declare function stp:fixup(
  $n as node(),
  $context as xs:string*)
as node()*
{
  typeswitch($n)
  case document-node() return document { stp:fixup($n/node(), $context) }
  case element() return stp:fixup-element($n, $context)
  case attribute() return stp:fixup-attribute($n)
  (: By default, return the input. :)
  default return $n
};

(: apidoc/setup/setup.xqm :)