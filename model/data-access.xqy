xquery version "1.0-ml";
module namespace ml = "http://developer.marklogic.com/site/internal";

import module namespace draft = "http://developer.marklogic.com/site/internal/filter-drafts"
       at "filter-drafts.xqy";
import module namespace u = "http://marklogic.com/rundmc/util"
       at "../../lib/util-2.xqy";

declare default element namespace "http://developer.marklogic.com/site/internal";

declare namespace prop="http://marklogic.com/xdmp/property";
declare namespace dir ="http://marklogic.com/xdmp/directory";
declare namespace xdmp="http://marklogic.com/xdmp";
declare namespace api ="http://marklogic.com/rundmc/api";

(: Some code treats the view HTML as a data model.
 : This is ugly, but needs a lot of fixing
 : and probably benefits performance as it is.
 :)
declare namespace x="http://www.w3.org/1999/xhtml";

(: used by get-updated-disqus-threads.xqy :)
declare variable $ml:Comments := fn:collection()/Comments; (: backed-up Disqus conversations :)

declare private variable $ml:doc-element-names := (xs:QName("Announcement"),
                                                   xs:QName("Event"),
                                                   xs:QName("Article"),
                                                   xs:QName("Tutorial"),
                                                   xs:QName("Project"),
                                                   xs:QName("Post"),
                                                   xs:QName("page")
                                                  );

declare variable $ml:Announcements := docs( xs:QName("Announcement"));
declare variable $ml:Events        := docs( xs:QName("Event"));
declare variable $ml:Articles      := docs((xs:QName("Article"), xs:QName("Tutorial")));
declare variable $ml:Projects      := docs( xs:QName("Project"));
declare variable $ml:pages         := docs( xs:QName("page"));
declare variable $ml:Posts         := docs((xs:QName("Post"), xs:QName("Announcement"), xs:QName("Event")));
(: "Posts" now include announcements and events, in addition to vanilla blog posts. :)

(: Get a listing of all live, listed DMC documents for the given page type(s) :)
declare private function docs($qnames) as element()* {
  cts:search(fn:collection(),
    cts:or-query((
      for $qname in $qnames return ml:matches-dmc-page($qname)
    ))
  )/*
};

(: Get a complete listing of all live documents on DMC (used by retroactive comment script) :)
declare variable $ml:live-dmc-documents := cts:search(fn:collection(), ml:matches-dmc-page());

(: Used by URL rewriter to control access to DMC pages :)
declare function ml:doc-matches-dmc-page-or-preview($doc as document-node()) {
  cts:contains($doc, ml:matches-any-dmc-page(fn:true()))
};

(: Used to find all live DMC documents, for search results :)
declare private function ml:matches-dmc-page() {
  ml:matches-any-dmc-page(fn:false())
};

(: Used to list all the DMC pages for a specific page type :)
declare private function ml:matches-dmc-page($qname) {
  ml:matches-dmc-page($qname, fn:false())
};


declare private function ml:matches-any-dmc-page($allow-previews-on-draft as xs:boolean) {
  cts:or-query((
    (: Require the document to match one of the known DMC page types :)
    for $qname in $ml:doc-element-names return ml:matches-dmc-page($qname, $allow-previews-on-draft)
  ))
};


(: Preview-only docs are allowed by the URL controller but never allowed in the search results page :)
declare private function ml:matches-dmc-page($qname, $allow-previews-on-draft as xs:boolean) {

  let $hide-previews := $draft:public-docs-only or fn:not($allow-previews-on-draft) return

  cts:and-query((

    (: Require the given element to be present :)
    cts:element-query($qname,cts:and-query(())),

    (: Additionally attempt to constrain the element to exist at the top level :)
    ml:query-for-doc-element($qname),

    (: Exclude admin-specific <ml:page> docs :)
    cts:not-query(
      cts:directory-query("/admin/","infinity")
    ),

    (: Exclude documents in the /private directory :)
    cts:not-query(
      cts:directory-query("/private/","infinity")
    ),

    (: If we're only serving public docs... :)
    if ($draft:public-docs-only) then
      (: ...then hide "Draft" docs by requiring status="Published" :)
      cts:element-attribute-value-query($qname,fn:QName("","status"),"Published")
    else (),

    (: If we're hiding previews... :)
    if ($hide-previews) then
      (: ...then disallow preview-only="yes" :)
      cts:not-query(
        cts:element-attribute-value-query($qname,fn:QName("","preview-only"),"yes")
      )
    else ()
  ))
};

declare private function ml:query-for-doc-element($qname) as cts:query? {
  let $plan := xdmp:value(fn:concat("xdmp:plan(fn:collection()/",$qname,")")),
      $term-query := $plan//*:term-query
  (: only do it if there's one term query returned; otherwise we can't be confident :)
  where fn:count($term-query) eq 1
  return cts:term-query(xs:integer(fn:string($term-query/*:key)))
};


(: Used as the additional query passed to search:search() :)
declare function ml:search-corpus-query($preferred-version as xs:string) {
  cts:and-query((
    cts:or-query((
      ml:live-document-query($preferred-version),
      cts:directory-query((fn:concat('/apidoc/', $preferred-version, '/javadoc/'), (: see apidoc/setup/load-static-docs.xqy :)
                           fn:concat('/apidoc/', $preferred-version, '/dotnet/'),
                           fn:concat('/apidoc/', $preferred-version, '/cpp/'),
                           '/pubs/code/'
                          ),
                          'infinity'
                         )
    )),
    cts:not-query(
      ml:has-attribute("hide-from-search","yes")
    ),
    cts:not-query(
      cts:collection-query("hide-from-search")
    )
  ))
};

declare private function ml:has-attribute($att-name, $value) {
  cts:or-query((
    for $qname in $ml:doc-element-names return
      cts:element-attribute-value-query($qname,fn:QName("",$att-name),$value)
  ))
};

(: Query for all live DMC and AMC documents :)
declare private function ml:live-document-query($preferred-version as xs:string) {
  cts:or-query((
    (: Pages on developer.marklogic.com :)
    ml:matches-dmc-page(),
    (: Pages on docs.marklogic.com, specific to the given docs version :)
    ml:matches-api-page($preferred-version)
  ))
};

(: Search only goes across the preferred server version :)
declare private function ml:matches-api-page($preferred-version as xs:string) {
  cts:and-query((
    cts:directory-query(fn:concat("/apidoc/",$preferred-version,"/"), "infinity"),
    (: Consider re-visiting this; can we avoid having to enumerate the element names here? :)
    cts:or-query((
      cts:element-query(xs:QName("api:function-page"),cts:and-query(())),
      cts:element-query(xs:QName("api:help-page"),cts:and-query(())),
      cts:element-query(fn:QName("","guide")  ,cts:and-query(())),
      cts:element-query(fn:QName("","chapter"),cts:and-query(()))
    ))
  ))
};

declare function ml:get-matching-functions(
  $name as xs:string,
  $version as xs:string)
as document-node()*
{
  let $query := cts:and-query(
    (cts:directory-query(fn:concat("/apidoc/",$version,"/")),
      cts:or-query(
        (cts:element-attribute-value-query(
            xs:QName("api:function"),
            fn:QName("","name"),  (: matches just the local name :)
            $name,
            "exact"),
          cts:element-attribute-value-query(
            xs:QName("api:function"),
            fn:QName("","fullname"), (: matches the full name (with prefix) :)
            $name,
            "exact") )) ))
  let $results := cts:search(fn:collection(), $query)
  let $preferred := ("fn","xdmp")
  return (
    for $f in $results
    for $lib in $f/*/api:function[1]/@lib
    let $index := fn:index-of($preferred, $lib)
    for $name in $f/*/api:function[1]/@name
    order by $index, $lib, $name
    return $f)
};

(: Look for a message guide section with the requested version and id.
 : This does no checking of the version or id.
 :)
declare function ml:get-matching-message(
  $id as xs:string,
  $version as xs:string)
as element(x:div)?
{
  xdmp:directory(
    '/apidoc/'||$version||'/guide/messages/',
    'infinity')
  /chapter/x:div/x:div[x:a/@id = $id]
};

declare variable $server-versions               := u:get-doc("/config/server-versions.xml")/*/*:version/@number;
declare variable $default-version as xs:string  := $ml:server-versions[../@default eq 'yes']/fn:string(.);

declare function topic-docs($tag as xs:string) as document-node()* {
  fn:collection()[.//topic-tag = $tag]

                 (: filter out non-live docs :)
                 [cts:contains(., ml:search-corpus-query($default-version))]
};


declare variable $all-category-tags as xs:string* := cts:collection-match("category/*");

(: For determining category facets :)
declare function reset-category-tags($doc-uri) {
                 reset-category-tags($doc-uri, ())
};

declare function reset-category-tags($doc-uri, $new-doc as document-node()?) {
  (: Start by removing any existing category collection URIs :)
  xdmp:document-remove-collections($doc-uri, $all-category-tags),

  let $category-value := category-for-doc($doc-uri, $new-doc)
  let $category-tag   := fn:concat("category/",$category-value)
  return
    (xdmp:log(fn:concat("Adding tag '", $category-tag, "' to ", $doc-uri)),
     xdmp:document-add-collections($doc-uri, $category-tag))
};

declare function category-for-doc($doc-uri) as xs:string {
                 category-for-doc($doc-uri, ())
};

declare function category-for-doc($doc-uri, $new-doc as document-node()?) as xs:string {
  (: Only look inside the doc if necessary :)
       if (fn:contains($doc-uri, "/dotnet/xcc/"))     then "xccn"
  else if (fn:contains($doc-uri, "/javadoc/xcc/"))    then "xcc"
  else if (fn:contains($doc-uri, "/javadoc/client/")) then "java-api"
  else if (fn:contains($doc-uri, "/javadoc/hadoop/")) then "hadoop"
  else if (fn:contains($doc-uri, "/cpp/"))            then "cpp"
  else let $doc := if ($new-doc) then $new-doc else fn:doc($doc-uri) return
       if ($doc/api:function-page/api:function[1]/@lib eq 'REST')
                                     then "rest-api"
  else if ($doc/api:function-page  ) then "function"
  else if ($doc/api:help-page      ) then "help"
  else if ($doc/(*:guide|*:chapter)) then "guide"
  else if ($doc/ml:Announcement    ) then "news"
  else if ($doc/ml:Event           ) then "event"
  else if ($doc/ml:Tutorial or
           $doc/ml:page/tutorial or
           $doc/ml:Article
                                                      (: these aren't really tutorials :)
                [fn:not(fn:matches(fn:base-uri($doc),'( /learn/[0-9].[0-9]/
                                                      | /learn/tutorials/gh/
                                                      | /learn/dzone/
                                                      | /learn/readme/
                                                      | /learn/w3c-
                                                      | /docs/
                                                      )','x'))]
                                   ) then "tutorial"
  else if ($doc/ml:Post            ) then "blog"
  else if ($doc/ml:Project         ) then "code"
                                     else "other"
};


(: Used to discover Project docs in the Admin UI :)
declare variable $projects-by-name := for $p in $Projects
                                      order by $p/name
                                      return $p;

(: Blog posts :)
declare variable $posts-by-date := for $p in $Posts
                                   order by $p/created descending
                                   return $p;

declare function latest-posts($how-many) { $posts-by-date[fn:position() le $how-many] };

(: Backed-up Disqus conversations :)
declare function comments-for-doc-uri($uri as xs:string)
{
  (: Associated with a page by using the same relative URI path but inside /private/comments :)
  fn:doc(comment-doc-uri($uri))/Comments
};

        declare private function comment-doc-uri($doc-uri as xs:string) {
          fn:concat("/private/comments", $doc-uri)
        };

declare function disqus-identifier($uri as xs:string) {
  let $existing-comments-doc := comments-for-doc-uri($uri)
  return
    (: Use the existing @disqus_indentifier if present (in case the doc URI has since changed).:)
    if ($existing-comments-doc) then $existing-comments-doc/@disqus_identifier/fn:string(.)

    (: Otherwise, just use the given URI, prefixed with "disqus-" :)
    else fn:concat("disqus-",$uri)
};

declare function default-comments-uri-from-disqus-identifier($id as xs:string?) {
  if (fn:starts-with($id,'disqus-')) then
    let $doc-uri := fn:substring-after($id,'disqus-')
    return
      comment-doc-uri($doc-uri)
  else ()
};

(: Insert a container for conversations pertaining to the given document (i.e. comments) :)
declare function insert-comment-doc($doc-uri) {
  let $comment-doc-uri := comment-doc-uri($doc-uri) return

  (: Only insert a comments doc if there isn't one already present :)
  if (fn:not(fn:doc-available($comment-doc-uri)))
  then xdmp:document-insert($comment-doc-uri,
                            document{ <ml:Comments disqus_identifier="{disqus-identifier($doc-uri)}"/> })
  else ()
};


(: Get a range of documents for paginated parts of the site; used for Blog, News, and Events :)
declare function list-segment-of-docs($start as xs:integer, $count as xs:integer, $type as xs:string)
{
    (: TODO: Consider refactoring so we have generic "by-date" and "list-by-type" functions that can sort out the differences :)
    let $docs := if ($type eq "Announcement") then $announcements-by-date
            else if ($type eq "Event"       ) then $events-by-date
            else if ($type eq "Post"        ) then $posts-by-date
            else ()
    return
      $docs[fn:position() ge $start
        and fn:position() lt ($start + $count)]
};


declare function total-doc-count($type as xs:string)
{
  let $docs := if ($type eq "Announcement") then $Announcements
          else if ($type eq "Event"       ) then $Events
          else if ($type eq "Post"        ) then $Posts
          else ()
  return
    fn:count($docs)
};


declare variable $announcements-by-date := for $a in $Announcements
                                           order by $a/date descending
                                           return $a;

        declare function announcements-by-date()
        {
          $announcements-by-date
        };

        (: Apparently no longer used (see change in revision 240) :)
        declare function latest-user-group-announcement()
        {
          $announcements-by-date[fn:normalize-space(@user-group)][1]
        };

        declare function latest-announcement()
        {
          $announcements-by-date[1]
        };


declare variable $events-by-date := for $e in $Events
                                    order by $e/details/date descending
                                    return $e;

        declare function events-by-date()
        {
          $events-by-date
        };

        declare function most-recent-event()
        {
          $events-by-date[1]
        };

        declare function most-recent-two-user-group-events($group as xs:string)
        {
          let $events := if ($group eq '')
                         then $events-by-date[fn:normalize-space(@user-group)]
                         else $events-by-date[@user-group eq $group]
          return
            $events[fn:position() le 2]
        };


(: Filtered documents by type and/or topic. Used in the "Learn" section of the site. :)
declare function lookup-articles($type as xs:string, $server-version as xs:string, $topic as xs:string,
    $allow-unversioned as xs:boolean)
{
  let $filtered-articles := $Articles[(($type  eq @type)        or fn:not($type))
                                and   (($server-version =
                                         server-version)        or fn:not($server-version) or
                                        ($allow-unversioned and fn:empty(server-version)))
                                and   (($topic =  topics/topic) or fn:not($topic))]
  return
    for $a in $filtered-articles
    order by $a/created descending
    return $a
};

        declare function latest-article($type as xs:string)
        {
          ml:lookup-articles($type, '', '', ())[1]
        };


(: Used to implement the <ml:top-threads/> tag :)
declare function get-threads-xml($search as xs:string?, $lists as xs:string*)
{
  try {
    (: This is a workaround for not yet being able to import the XQuery directly. :)
    (: This is a bit nicer anyway, since the other can double as a main module... :)
    xdmp:invoke('top-threads.xqy', (fn:QName('', 'search'), fn:string-join($search,' '),
                                    fn:QName('', 'lists') , fn:string-join($lists ,' ')))
  } catch ($e) {
    (: Don't break the page if top threads doesn't work (e.g., because markmail.org is down) :)
    xdmp:log(fn:concat("ERROR in calling top-threads.xqy: ", xdmp:quote($e)))
  }
};

declare function xquery-widget($module as xs:string)
{
  let $result := xdmp:invoke(fn:concat('../widgets/',$module))
  return
    $result/node()
};

declare function xslt-widget($module as xs:string)
{
  let $result := xdmp:xslt-invoke(fn:concat('../widgets/',$module), document{()})
  return
    $result/ml:widget/node()
};


(: Everything below is concerned with caching our navigation XML :)
declare variable $code-dir       := xdmp:modules-root();
declare variable $config-file    := "navigation.xml";
declare variable $config-dir     := fn:concat($code-dir,'config/');
declare variable $raw-navigation := xdmp:document-get(fn:concat($config-dir,$config-file));
declare variable $public-nav-location := "/private/public-navigation.xml";
declare variable $draft-nav-location  := "/private/draft-navigation.xml";
declare variable $pre-generated-location := if ($draft:public-docs-only)
                                            then $public-nav-location
                                            else $draft-nav-location;

(: This function implements a basic caching mechanism for our $navigation info.
   It checks to see if the code has changed since the last time we pre-generated
   the $navigation, whether the draft version or the public-only version. If
   navigation.xml or any of the other code has been updated since the last
   time we generated the fully populated navigation, then we must re-generate
   it afresh. Otherwise, we serve up the pre-generated navigation, thereby
   avoiding this costly operation on most server requests.

   We no longer try to detect database changes but leave it up to the admin UI
   to call invalidate-navigation-cache. To manually invalidate, just delete
   public-navigation.xml and draft-navigation.xml
:)
declare function get-cached-navigation()
{
let $pre-generated-navigation := fn:doc($pre-generated-location),

    $last-generated := xdmp:document-properties($pre-generated-location)/*/prop:last-modified,

    $last-update :=

      let $config-last-updated := xdmp:filesystem-directory($config-dir)
                                  /dir:entry [dir:filename eq $config-file]
                                  /dir:last-modified,

          (: A happy side effect of using git is that any time we push
             code, the .git directory should show a new last-modified date;
             this should ensure that any and all code updates will invalidate
             the navigation cache :)
          $code-last-updated := xdmp:filesystem-directory($code-dir)
                                /dir:entry
                                /dir:last-modified

          (: Let the admin controller code explicitly invalidate the cache rather than
             checking the document properties all the time, which is expensive. It's also
             insufficient, because this approach doesn't detect new documents, e.g., a new blog post.
          ,$doc-uris := fn:distinct-values($pre-generated-navigation//page/@href/fn:concat(.,'.xml')),

          $docs-last-updated := fn:max(xdmp:document-properties($doc-uris)/*/prop:last-modified)
          :)

      return
         fn:max(($config-last-updated,
                 $code-last-updated
                 (:,
                 $docs-last-updated):)
               ))

return
   if (fn:exists($pre-generated-navigation) and $last-generated gt $last-update)
   then $pre-generated-navigation
   else ()
};

(: When first populating the navigation, cache it in the database :)
declare function save-cached-navigation($doc)
{
  (: Force the insert to occur in a separate transaction to prevent every request
     from being marked as an update :)
  xdmp:invoke("document-insert.xqy", (fn:QName("","uri"),      $pre-generated-location,
                                      fn:QName("","document"), $doc))
};

(: Call this to explicitly invalidate the cached navigation :)
declare function invalidate-cached-navigation()
{
       if (fn:doc-available($public-nav-location))
  then xdmp:document-delete($public-nav-location) else (),
       if (fn:doc-available($draft-nav-location))
  then xdmp:document-delete($draft-nav-location) else ()
};

(: Used to implement the <ml:meetup-events/> tag :)
declare function get-meetup-upcoming($group as xs:string?)
{
    let $doc := fn:doc(fn:concat('/private/meetup/', $group, '.xml'))

    return
        for $m in $doc/*:meetup/*:upcoming-events/*:event
        return
        <ml:meetup>
            <ml:id>{$m/@*:id/fn:string()}</ml:id>
            <ml:title>{$m/@*:name/fn:string()}</ml:title>
            <ml:url>{$m/@*:url/fn:string()}</ml:url>
            <ml:yes-rsvps>{$m/@*:yes_rsvp_count/fn:string()}</ml:yes-rsvps>
            <ml:date>
            {
                xdmp:strftime("%B %d", u:epoch-seconds-to-dateTime(($m/@*:time/fn:number()) idiv 1000))
            }
            </ml:date>
            <ml:rsvps>
            {
                for $r in $m/*:rsvp
                return
                    <ml:member>
                      <ml:id>{$r/*:member/*:member_id/fn:string()}</ml:id>
                      <ml:name>{$r/*:member/*:name/fn:string()}</ml:name>
                      <ml:avatar>{$r/*:member_photo/*:thumb_link/fn:string()}</ml:avatar>
                    </ml:member>
            }
            </ml:rsvps>
        </ml:meetup>
};

declare function get-meetup-recent($group as xs:string?)
{
    let $doc := fn:doc(fn:concat('/private/meetup/', $group, '.xml'))

    return
        for $m in $doc/*:meetup/*:recent-events/*:event
        return
        <ml:meetup>
            <ml:id>{$m/@*:id/fn:string()}</ml:id>
            <ml:title>{$m/@*:name/fn:string()}</ml:title>
            <ml:url>{$m/@*:url/fn:string()}</ml:url>
            <ml:yes-rsvps>{$m/@*:yes_rsvp_count/fn:string()}</ml:yes-rsvps>
            <ml:date>
            {
                xdmp:strftime("%B %d, %Y", u:epoch-seconds-to-dateTime(($m/@*:time/fn:number()) idiv 1000))
            }
            </ml:date>
            <ml:rsvps>
            {
                for $r in $m/*:rsvp[fn:exists(*:member_photo/*:thumb_link)][1 to 6]
                return
                    <ml:member>
                      <ml:id>{$r/*:member/*:member_id/fn:string()}</ml:id>
                      <ml:name>{$r/*:member/*:name/fn:string()}</ml:name>
                      <ml:avatar>{$r/*:member_photo/*:thumb_link/fn:string()}</ml:avatar>
                    </ml:member>
            }
            </ml:rsvps>
        </ml:meetup>
};

declare function get-meetup-name($group as xs:string?)
{
    let $url := fn:concat('/private/meetup/', $group, '.xml')
    return fn:doc($url)/*:meetup/@*:name/fn:string()
};

declare function videos()
{
    <ml:videos>
    {
        for $video in $Articles[@type eq 'Video']
            return $video
    }
    </ml:videos>
};
