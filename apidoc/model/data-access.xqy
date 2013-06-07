xquery version "1.0-ml";

            module namespace api = "http://marklogic.com/rundmc/api";
declare default function namespace "http://marklogic.com/rundmc/api";

declare namespace apidoc = "http://marklogic.com/xdmp/apidoc";

import module namespace u = "http://marklogic.com/rundmc/util"
       at "../../lib/util-2.xqy";
import module namespace ml = "http://developer.marklogic.com/site/internal"
       at "../../model/data-access.xqy";

declare variable $api:default-version   as xs:string  := $ml:default-version;
declare variable $api:version-specified as xs:string? := xdmp:get-request-field("version"); (: uniformly accessed in both the setup and view code
                                                                                               rather than using $params which only the view code uses :)
declare variable $api:version           as xs:string  := if ($api:version-specified) then $api:version-specified
                                                                                     else $api:default-version;

(: This variable is only used by the setup script, because it's only in the setup scripts that we ever care about more than one TOC URL at a time :)
(: Its value must be the same as $api:toc-url-location when $api:version-specified is empty, so the view code will get the right default TOC. :)
declare variable $api:toc-url-default-version-location := fn:concat("/apidoc/private/",                       "toc-url.xml");
declare variable $api:toc-url-location                 := fn:concat("/apidoc/private/",$api:version-specified,"toc-url.xml");

(: The URL of the current TOC (based on whatever version the user has requested) :)
(:
declare variable $api:toc-url := fn:string(fn:doc($toc-url-location)/*);
:)
(: Using the alternative TOC location for now - i.e. if current version is the default,
   regardless of whether it was explicit, don't include the version number in links; see also $version-prefix in page.xsl; see also delete-old-toc.xqy :)
declare variable $api:toc-url := fn:string(fn:doc($toc-url-location-alternative)/*);

declare variable $api:toc-url-location-alternative := if ($api:version eq $api:default-version) then $api:toc-url-default-version-location
                                                                                                else $api:toc-url-location;

declare variable $api:version-dir := fn:concat("/apidoc/",$api:version,"/");

declare variable $api:query-for-all-functions :=
  cts:and-query((
    cts:directory-query($api:version-dir,"infinity"), (: REST "function" docs are in sub-directories :)
  (:cts:directory-query($api:version-dir,"1"),:)
    cts:element-query(xs:QName("api:function"),cts:and-query(()))
  ));

declare variable $api:query-for-builtin-functions :=
  cts:and-query((
    $api:query-for-all-functions,
    cts:element-attribute-value-query(xs:QName("api:function"),
                                      xs:QName("type"),
                                      "builtin")
  ));

(: Every function that's not a built-in function is a library function :)
declare variable $api:query-for-library-functions :=
  cts:and-not-query(
    $api:query-for-all-functions,
    $api:query-for-builtin-functions
  );

(: Used only by TOC-generating code :)
declare variable $api:all-function-docs := cts:search(fn:collection(),$api:query-for-all-functions,"unfiltered");

declare variable $api:all-functions-count     := xdmp:estimate(cts:search(fn:collection(),$api:query-for-all-functions));
declare variable $api:built-in-function-count := xdmp:estimate(cts:search(fn:collection(),$api:query-for-builtin-functions));
declare variable $api:library-function-count  := xdmp:estimate(cts:search(fn:collection(),$api:query-for-library-functions));

declare variable $api:built-in-libs := get-libs($api:query-for-builtin-functions, fn:true() );
declare variable $api:library-libs  := get-libs($api:query-for-library-functions, fn:false());

declare function get-libs($query, $builtin) {
  for $lib in cts:element-attribute-values(xs:QName("api:function"),
                                           xs:QName("lib"), (), "ascending",
                                           $query)
  return
      <api:lib category-bucket="{get-bucket-for-lib($lib)}">{
         if ($builtin) then attribute built-in { "yes" } else (),
         $lib
      }</api:lib>
};

declare function function-count-for-lib($lib) {
  xdmp:estimate(xdmp:directory($api:version-dir,"1")/api:function-page/
     api:function[@lib eq $lib])
};

declare function query-for-lib-functions($lib) {
  cts:and-query((
    $api:query-for-all-functions,
    cts:element-attribute-value-query(xs:QName("api:function"),
                                      xs:QName("lib"),
                                      $lib)))
};

(: Used to associate library containers under the "API" tab with their corresponding "Categories" tab TOC container :)
declare function get-bucket-for-lib($lib) {
  cts:search(fn:collection(), query-for-lib-functions($lib))[1]/api:function-page/api:function[1]/@bucket
};


declare variable $namespace-mappings := u:get-doc("/apidoc/config/namespace-mappings.xml")/namespaces/namespace;

(: Returns the namespace URI associated with the given lib name :)
declare function uri-for-lib($lib) {
  fn:string($namespace-mappings[@lib eq $lib]/@uri)
};

(: Normally, just use the lib name as the prefix, unless specially configured to do otherwise :)
declare function prefix-for-lib($lib) {
  fn:string($namespace-mappings[@lib eq $lib]/(if (@prefix) then @prefix else $lib))
};

(: E.g., store the images for /apidoc/4.2/guides/performance.xml in /media/apidoc/4.2/guides/performance/ :)
declare function guide-image-dir($page-uri) {
  let $path := fn:substring-before($page-uri, ".xml") return
  fn:concat("/media",$path,"/")
};


(: Replace "?" in the names of REST resources with a character that will work in doc URIs :)
declare variable $api:REST-uri-questionmark-substitute := "@";
