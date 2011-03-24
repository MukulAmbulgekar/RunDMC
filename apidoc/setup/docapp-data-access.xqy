xquery version "1.0-ml";

(: This module provides access to the docapp database,
   which the setup scripts use to import content :)

module namespace docapp = "http://marklogic.com/rundmc/docapp-data-access";

declare variable $docapp:docs :=
  let $query := 'declare namespace apidoc="http://marklogic.com/xdmp/apidoc";
                 fn:collection()[apidoc:module]'
  return
    xdmp:eval($query, (), <options xmlns="xdmp:eval">
                            <database>{xdmp:database("docapp")}</database>
                          </options>);
