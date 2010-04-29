<xsl:stylesheet version="2.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:xdmp="http://marklogic.com/xdmp"
  xmlns      ="http://www.w3.org/1999/xhtml"
  xmlns:xhtml="http://www.w3.org/1999/xhtml"
  xmlns:search="http://marklogic.com/appservices/search"
  xmlns:cts   ="http://marklogic.com/cts"
  xmlns:u    ="http://marklogic.com/rundmc/util"
  xmlns:qp   ="http://www.marklogic.com/ps/lib/queryparams"
  xmlns:ml               ="http://developer.marklogic.com/site/internal"
  xpath-default-namespace="http://developer.marklogic.com/site/internal"
  exclude-result-prefixes="xs ml xdmp qp search cts">

  <xsl:variable name="page-number" select="if ($params/qp:p) then $params/qp:p else 1" as="xs:integer"/>
  <xsl:variable name="current-version" select="4.1"/>

  <xsl:template match="tabbed-features">
    <div id="special_intro">
      <ul class="nav">
        <xsl:apply-templates mode="feature-tab" select="feature"/>
      </ul>
      <xsl:apply-templates mode="feature-tab-content" select="feature"/>
    </div>
  </xsl:template>

          <xsl:template mode="feature-tab" match="feature">
            <li>
              <a href="#section{position()}">
                <xsl:value-of select="u:get-doc(@href)/feature/title"/>
              </a>
            </li>
          </xsl:template>

          <xsl:template mode="feature-tab-content" match="feature">
            <xsl:variable name="feature" select="u:get-doc(@href)/feature"/>

            <div class="section" id="section{position()}">
              <div class="align_right">
                <xsl:apply-templates mode="feature-content" select="$feature/image"/>
              </div>
              <xsl:apply-templates mode="feature-content" select="$feature/(* except (title,image))"/>
            </div>
          </xsl:template>

                  <xsl:template mode="feature-content" match="image">
                    <img src="{@src}" alt="{@alt}"/>
                    <xsl:apply-templates mode="feature-content" select="caption"/>
                  </xsl:template>

                          <xsl:template mode="feature-content" match="caption">
                            <div class="caption">
                              <xsl:apply-templates/>
                            </div>
                          </xsl:template>

                  <xsl:template mode="feature-content" match="main-points">
                    <ul>
                      <xsl:apply-templates mode="feature-content" select="point"/>
                    </ul>
                  </xsl:template>

                          <xsl:template mode="feature-content" match="point">
                            <li>
                              <xsl:apply-templates/>
                            </li>
                          </xsl:template>

                  <xsl:template mode="feature-content" match="read-more">
                    <ul class="more">
                      <xsl:apply-templates mode="feature-content" select="link"/>
                    </ul>
                  </xsl:template>

                          <xsl:template mode="feature-content" match="link">
                            <li>
                              <a href="{@href}">
                                <xsl:apply-templates/>
                                <xsl:text>&#160;></xsl:text>
                              </a>
                            </li>
                          </xsl:template>

                  <xsl:template mode="feature-content" match="download-button">
                    <xsl:param name="is-widget" tunnel="yes"/>
                    <xsl:variable name="button-class" select="if ($is-widget) then 'download' else 'button'"/>
                    <a class="{$button-class}" href="{@href}">
                      <img src="/images/b_download_now.png" alt="Download Now"/>
                    </a>
                  </xsl:template>


  <xsl:template match="product-info">
    <h2>
      <xsl:value-of select="@name"/>
    </h2>

    <div class="download-confirmation" id="confirm-dialog" style="display: none">
        <h1>MarkLogic Server Download Confirmation</h1>

        <p>
        Before downloading this MarkLogic Server 
        Community Edition binary you must agree to the following terms.
        During installation you will be presented the full
        license and must agree to those terms of use to activate the software.
        </p>
        
        <blockquote class="download-quote">
        I agree that I will not use this download or other intellectual property or 
        confidential information of MarkLogic for competitive analysis or reverse engineering in 
        connection with development of products that are the same or similar to 
        MarkLogic's products licensed herein. I also agree that I will not use this 
        download in combination with a Community License, Trial License, or Academic License for 
        commercial use.
        </blockquote>
        
        <br/>
        <span class="download-warn">You must confirm your acceptance of the above terms.</span> <br/>
        <input type="checkbox" id="iaccept" name="iaccept" value="true"/><label for="iaccept">I agree to the above terms of use.</label>
    </div>

    <a class="more hide-if-href-empty" href="{@license-page}">License Options &gt;</a>
    <h4><a class="requirements hide-if-href-empty" href="{@requirements-page}">System Requirements &gt;</a></h4>
    <p/>

    <xsl:apply-templates mode="product-platform" select="platform"/>
  </xsl:template>

          <xsl:template mode="product-platform" match="platform">
            <table class="table1">
              <thead>
                <tr>
                  <th scope="col">
                    <xsl:value-of select="@name"/>
                  </th>
                  <th class="size" scope="col">File Size</th>
                <!--
                  <th class="last" scope="col">Date Posted</th>
                -->
                </tr>
              </thead>
              <tbody>
                <xsl:apply-templates mode="product-download" select="download"/>
              </tbody>
            </table>
          </xsl:template>

                  <xsl:template mode="product-download" match="download">
                    <tr>
                      <td>
                        <a href="{@href}" class="confirm-download">
                          <img src="/images/icon_download.png" alt="Download"/>
                          <xsl:apply-templates/>
                        </a>
                      </td>
                      <td>
                        <a href="{@href}" class="confirm-download">
                            <xsl:value-of select="@size"/>
                        </a>
                      </td>
                     <!--
                      <td>
                        <xsl:value-of select="@date"/>
                      </td>
                    -->
                    </tr>
                  </xsl:template>


  <xsl:template match="product-documentation">
    <table class="table2">
      <h2>Documentation</h2>
      <tbody>
        <xsl:apply-templates mode="product-doc-entry" select="doc | old-doc"/>
      </tbody>
    </table>
  </xsl:template>

          <xsl:template mode="product-doc-entry" match="*">
            <xsl:variable name="title">
              <xsl:apply-templates mode="product-doc-title" select="."/>
            </xsl:variable>
            <xsl:variable name="url">
              <xsl:apply-templates mode="product-doc-url" select="."/>
            </xsl:variable>
            <tr>
              <td>
                <a href="{$url}">
                    <xsl:value-of select="$title"/>
                </a>
              </td>
              <td> 
                <a href="{$url}">
                  <xsl:choose>
                    <xsl:when test="ends-with(lower-case($url), 'pdf')">
                      <img src="/images/icon_pdf.png" alt="View PDF for {$title}"/>
                    </xsl:when>
                    <xsl:when test="ends-with(lower-case($url), 'zip')">
                      <img src="/images/icon_zip.png" alt="Download zip file for {$title}"/>
                    </xsl:when>
                    <xsl:otherwise>
                      <img src="/images/icon_browser.png" alt="View HTML for {$title}"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </a>
              </td>
            </tr>
          </xsl:template>

                  <xsl:template mode="product-doc-title" match="old-doc">
                    <xsl:value-of select="@desc"/>
                  </xsl:template>

                  <xsl:template mode="product-doc-title" match="doc">
                    <xsl:value-of select="document(@source)/Article/title"/>
                  </xsl:template>


                  <xsl:template mode="product-doc-url" match="old-doc">
                    <xsl:value-of select="@path"/>
                  </xsl:template>

                  <xsl:template mode="product-doc-url" match="doc">
                    <xsl:variable name="source" select="document(@source)"/>
                    <xsl:value-of select="if ($source/Article/external-link)
                                          then $source/Article/external-link/@href
                                          else ml:external-uri($source)"/>
                  </xsl:template>


  <xsl:template match="top-threads">
    <xsl:variable name="threads" select="ml:get-threads-xml(@search,list/string(.))"/>
    <xsl:if test="count($threads/thread) gt 0">
    <div class="single">
      <h2>Recent Messages</h2>
      <a class="more" href="{$threads/@all-threads-href}">All messages&#160;></a>
      <table class="table3">
        <thead>
          <tr>
            <th scope="col">
              <span>Subject</span>
              <br/>
              List
            </th>
            <th scope="col"><span>Date</span>
              <br/>
              Author
            </th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates mode="display-thread" select="$threads/thread"/>
        </tbody>
      </table>
      <!--
      <div class="action">
        <a href="{$threads/@start-thread-href}">Start a new thread</a>
      </div>
        -->
    </div>
    </xsl:if>
  </xsl:template>

          <xsl:template mode="display-thread" match="thread">            
            <tr>
              <xsl:if test="position() mod 2 eq 0">
                <xsl:attribute name="class">alt</xsl:attribute>
              </xsl:if>
              <td>
                <a class="thread stip" href="{@href}" title="{blurb}">
                  <xsl:value-of select="@title"/>
                </a>
                <br/>
                <a href="{list/@href}">
                  <xsl:value-of select="list"/>
                </a>
              </td>
              <td>
                <span class="date">
                  <xsl:value-of select="@date"/>
                </span>
                <a class="author" href="{author/@href}">
                  <xsl:value-of select="author"/>
                </a>
              </td>
              <!--
              <td>
                <xsl:value-of select="@replies"/>
              </td>
              <td>
                <xsl:value-of select="@views"/>
              </td>
              -->
            </tr>
          </xsl:template>


  <xsl:template match="upcoming-user-group-events">
    <xsl:variable name="events" select="ml:most-recent-two-user-group-events(string(@group))"/>
    <div class="double">
      <h2>Upcoming Events</h2>
      <a class="more" href="/events">All events&#160;></a>
      <xsl:for-each select="$events">
        <div>
          <xsl:apply-templates mode="event-excerpt" select=".">
            <xsl:with-param name="suppress-more-link" select="true()" tunnel="yes"/>
            <xsl:with-param name="suppress-description" select="true()" tunnel="yes"/>
          </xsl:apply-templates>
        </div>
      </xsl:for-each>
    </div>
  </xsl:template>


  <xsl:template match="recent-news-and-events">
    <xsl:variable name="announcement" select="ml:latest-announcement()"/>
    <xsl:variable name="event"        select="ml:most-recent-event()"/>
    <div class="double">
      <div>
        <h2>Recent News</h2>
        <xsl:apply-templates mode="news-excerpt" select="$announcement">
          <xsl:with-param name="suppress-more-link" select="string(@suppress-more-links) eq 'yes'" tunnel="yes"/>
        </xsl:apply-templates>
      </div>
      <div>
        <h2>Upcoming Events</h2>
        <xsl:apply-templates mode="event-excerpt" select="$event">
          <xsl:with-param name="suppress-more-link" select="string(@suppress-more-links) eq 'yes'" tunnel="yes"/>
        </xsl:apply-templates>
      </div>
    </div>
  </xsl:template>

          <xsl:template mode="news-excerpt" match="Announcement">
            <xsl:param name="read-more-inline" tunnel="yes"/>
            <h3>
              <xsl:apply-templates select="title/node()"/>
            </h3>
            <p>
              <xsl:apply-templates select="body//teaser/node()"/>
              <xsl:if test="$read-more-inline">
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="read-more" select="."/>
              </xsl:if>
            </p>
            <xsl:if test="not($read-more-inline)">
              <xsl:apply-templates mode="read-more" select="."/>
            </xsl:if>
            <xsl:apply-templates mode="more-link" select="."/>
          </xsl:template>

                  <xsl:template mode="read-more" match="Announcement | Event">
                    <a class="more" href="{ml:external-uri(.)}">Read more&#160;></a>
                  </xsl:template>


          <xsl:template mode="event-excerpt" match="Event">
            <xsl:param name="suppress-description" tunnel="yes"/>
            <h3>
              <xsl:apply-templates select="title/node()"/>
            </h3>
            <xsl:if test="not($suppress-description)">
              <xsl:apply-templates select="description//teaser/node()"/>
            </xsl:if>
            <dl>
              <xsl:apply-templates mode="event-details" select="details/*"/>
            </dl>
            <a class="more" href="{ml:external-uri(.)}">More information&#160;></a>
            <xsl:apply-templates mode="more-link" select="."/>
          </xsl:template>

                  <xsl:template mode="more-link" match="*">
                    <xsl:param name="suppress-more-link" tunnel="yes" as="xs:boolean" select="false()"/>
                    <xsl:if test="not($suppress-more-link)">
                      <xsl:variable name="href">
                        <xsl:apply-templates mode="more-link-href" select="."/>
                      </xsl:variable>
                      <xsl:variable name="link-text">
                        <xsl:apply-templates mode="more-link-text" select="."/>
                      </xsl:variable>

                      <div class="more">
                        <a href="{$href}">
                          <xsl:value-of select="$link-text"/>
                          <xsl:text>&#160;></xsl:text>
                        </a>
                      </div>

                    </xsl:if>
                  </xsl:template>

                          <xsl:template mode="more-link-href" match="Event"       >/events</xsl:template>
                          <xsl:template mode="more-link-href" match="Announcement">/news</xsl:template>

                          <xsl:template mode="more-link-text" match="Event"       >More Events</xsl:template>
                          <xsl:template mode="more-link-text" match="Announcement">More News</xsl:template>


                  <!-- TODO: For dates and times, consider use ISO 8601 format (in the source data) instead -->
                  <xsl:template mode="event-details" match="*">
                    <dt>
                      <xsl:apply-templates mode="event-detail-name" select="."/>
                      <xsl:text>:</xsl:text>
                    </dt>
                    <dd>
                      <xsl:apply-templates/>
                    </dd>
                  </xsl:template>

                          <xsl:template mode="event-detail-name" match="date"     >Date</xsl:template>
                          <xsl:template mode="event-detail-name" match="time"     >Time</xsl:template>
                          <xsl:template mode="event-detail-name" match="location" >Location</xsl:template>
                          <xsl:template mode="event-detail-name" match="topic"    >Topic</xsl:template>
                          <xsl:template mode="event-detail-name" match="presenter">Presenter</xsl:template>


  <xsl:template match="article-abstract">
    <xsl:apply-templates mode="article-abstract" select="document(@href)/Article">
      <xsl:with-param name="heading" select="@heading"/>
      <xsl:with-param name="suppress-byline" select="true()"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="recent-article">
    <xsl:apply-templates mode="article-abstract" select="ml:latest-article(string(@type))">
      <xsl:with-param name="heading" select="@heading"/>
    </xsl:apply-templates>
  </xsl:template>

          <xsl:template mode="article-abstract" match="Article">
            <xsl:param name="heading" as="xs:string"/>
            <xsl:param name="suppress-byline"/>
            <div class="single">
              <h2>
                <xsl:value-of select="$heading"/>
              </h2>
              <h3>
                <xsl:apply-templates select="title/node()"/>
              </h3>
              <xsl:if test="not($suppress-byline)">
                <div class="author">
                  <xsl:text>By </xsl:text>
                  <xsl:value-of select="author"/>
                </div>
              </xsl:if>
              <p>
                <xsl:apply-templates select="if (normalize-space(abstract)) then abstract/node()
                                                                            else body/xhtml:p[1]/node()"/>
                <xsl:text> </xsl:text>
                <a class="more" href="{ml:external-uri(.)}">Read&#160;more&#160;></a>
              </p>
            </div>
          </xsl:template>


  <xsl:template match="read-more">
    <a class="more" href="{@href}">Read&#160;more&#160;></a>
  </xsl:template>

  <xsl:template match="license-options">
    <div class="action">
      <ul>
        <li>
          <a href="{@href}">License options</a>
        </li>
      </ul>
    </div>
  </xsl:template>


  <xsl:template match="document-list">
    <xsl:variable name="docs" select="ml:lookup-articles(string(@type), string(@server-version), string(@topic))"/>
    <div class="doclist">
      <h2>&#160;</h2>
      <!-- 2.0 feature TODO: add pagination -->
      <span class="amount">
        <!--
        <xsl:value-of select="count($docs)"/>
        <xsl:text> of </xsl:text>
        -->
        <xsl:value-of select="count($docs)"/>
        <xsl:choose>
            <xsl:when test="count($docs) eq 1">
                <xsl:text> document</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> documents</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
      </span>
      <!--
      <form action="" method="get">
        <div>
          <label for="kw_inp">Search documents by keyword</label>
          <input id="kw_inp" type="text"/>
          <input type="submit"/>
        </div>
      </form>
      -->
      <table class="sortable documentsList">
        <colgroup>
          <col class="col1"/>
          <col class="col2"/>
          <col class="col3"/>
          <!--
          <col class="col4"/>
          -->
        </colgroup>
        <thead>
          <tr>
            <th scope="col">Title</th>
            <th scope="col">Document&#160;Type&#160;&#160;&#160;&#160;</th> <!-- nbsp's to prevent overlap with sort arrow -->
            <!--
            <th scope="col">Server&#160;Version&#160;&#160;&#160;&#160;</th>
            <th scope="col">Topic(s)</th>
            -->
            <th scope="col" class="sort">Last updated</th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates mode="doc-listing" select="$docs"/>
        </tbody>
      </table>
    </div>
  </xsl:template>

  <xsl:template match="document-table">
    <xsl:variable name="docs" select="doc"/>
    <div class="doclist">
      <h2>&#160;</h2>
      <span class="amount">
        <xsl:value-of select="count($docs)"/>
        <xsl:choose>
            <xsl:when test="count($docs) eq 1">
                <xsl:text> document</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text> documents</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
      </span>
      <table class="documentsTable">
        <colgroup>
          <col class="col1"/>
          <!-- Display last updated only on latest version -->
          <xsl:if test="not(exists(@version))">
            <col class="col2"/>
          </xsl:if>
        </colgroup>
        <thead>
          <tr>
            <th scope="col">Title</th>
            <!-- Display last updated only on latest version -->
            <xsl:if test="not(exists(@version))">
                <th scope="col">Last updated</th>
            </xsl:if>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates mode="doc-table-listing" select="doc"/>
        </tbody>
      </table>
    </div>
  </xsl:template>

          <xsl:template mode="doc-table-listing" match="doc">
              <xsl:variable name="version" select="string(../@version)" />
              <xsl:apply-templates mode="doc-table-entry" select="document(@path)/Article">
                <xsl:with-param name="version" select="$version" />
              </xsl:apply-templates>
          </xsl:template>

          <xsl:template mode="doc-table-entry" match="Article">
            <xsl:param name="version" />
            <tr>
              <xsl:if test="position() mod 2 eq 0">
                <xsl:attribute name="class">alt</xsl:attribute>
              </xsl:if>
              <td>
                <a href="{replace(
                            if (external-link/@href)
                                then external-link/@href
                                else ml:external-uri(.), 
                            '4.1', 
                            if (string($version)) then string($version) else '4.1' )
                        }">
                  <xsl:value-of select="title"/>
                </a>
                <br/><div class="doc-desc"><xsl:value-of select="description"/></div>
              </td>
        
              <!-- Display last updated only on latest version -->
              <xsl:if test="$version eq ''">
                <td>
                    <xsl:value-of select="replace(last-updated,' ','&#160;')"/>
                </td>
              </xsl:if>
            </tr>
          </xsl:template>

          <xsl:template mode="doc-listing" match="Article">
            <tr>
              <xsl:if test="position() mod 2 eq 0">
                <xsl:attribute name="class">alt</xsl:attribute>
              </xsl:if>
              <td>
                <a href="{if (external-link/@href)
                         then external-link/@href
                         else ml:external-uri(.)}">
                  <xsl:value-of select="title"/>
                </a>
                <br/><div class="doc-desc"><p><xsl:value-of select="description"/></p></div>
              </td>
              <td>
                <xsl:value-of select="replace(@type,' ','&#160;')"/>
              </td>
              <td>
                <xsl:value-of select="replace(last-updated,' ','&#160;')"/>
              </td>
            </tr>
          </xsl:template>


  <!-- Paginated list for blog posts, events, and news announcements -->
  <xsl:template match="paginated-list">
    <xsl:variable name="results-per-page" select="xs:integer(@results-per-page)"/>
    <xsl:variable name="start" select="ml:start-index($results-per-page)"/>

    <xsl:apply-templates mode="paginated-list-item" select="ml:list-segment-of-docs($start, $results-per-page, @type)"/>

    <xsl:variable name="page-url">
      <xsl:apply-templates mode="paginated-page-url" select="."/>
    </xsl:variable>

    <xsl:if test="ml:total-doc-count(@type) gt ($start + $results-per-page - 1)">
      <div class="olderPosts more">
        <a href="{$page-url}?p={$page-number + 1}">&lt; Older Entries</a>
      </div>
    </xsl:if>
    <xsl:if test="$page-number gt 1">
      <div class="newerPosts more">
        <a href="{$page-url}?p={$page-number - 1}">Newer Entries &gt;</a>
      </div>
    </xsl:if>
  </xsl:template>

          <xsl:template mode="paginated-page-url" match="Announcement">/news</xsl:template>
          <xsl:template mode="paginated-page-url" match="Event"       >/events</xsl:template>
          <xsl:template mode="paginated-page-url" match="Post"        >/blog</xsl:template>

          <xsl:function name="ml:start-index" as="xs:integer">
            <xsl:param name="results-per-page" as="xs:integer"/>
            <xsl:sequence select="($results-per-page * $page-number) - ($results-per-page - 1)"/>
          </xsl:function>

          <xsl:template mode="paginated-list-item" match="Event">
            <div class="newsitem">
              <h3>
                <xsl:apply-templates select="title/node()"/>
              </h3>
              <dl>
                <xsl:apply-templates mode="event-details" select="details/*"/>
              </dl>
              <p>
                <xsl:apply-templates select="description//teaser/node()"/>
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="read-more" select="."/>
              </p>
            </div>
          </xsl:template>

          <xsl:template mode="paginated-list-item" match="Announcement">
            <div class="newsitem">
              <div class="date">
                <xsl:value-of select="ml:display-date(date)"/>
              </div>
              <h3>
                <xsl:apply-templates select="title/node()"/>
              </h3>
              <p>
                <xsl:apply-templates select="body//teaser/node()"/>
                <xsl:text> </xsl:text>
                <xsl:apply-templates mode="read-more" select="."/>
              </p>
            </div>
          </xsl:template>


  <xsl:template match="search-results">
    <xsl:variable name="results-per-page" select="10"/>
    <xsl:variable name="start" select="ml:start-index($results-per-page)"/>
    <xsl:variable name="options" as="element()">
      <options xmlns="http://marklogic.com/appservices/search">
        <additional-query>
          <!-- TODO: evaluate the performance of this approach; it could be bad -->
          <xsl:copy-of select="cts:document-query(($ml:live-documents/base-uri(.),
                                                   collection()[starts-with(base-uri(.),'/pubs/4.1/apidocs')
                                                             or starts-with(base-uri(.),'/pubs/4.1/dotnet')
                                                             or starts-with(base-uri(.),'/pubs/4.1/javadoc')]/base-uri(.)
                                                 ))"/>
        </additional-query>
      </options>
    </xsl:variable>
    <xsl:variable name="search-results" select="search:search($params/qp:q,
                                                              $options,
                                                              (:
                                                              search:get-default-options(),
                                                              :)
                                                              $start,
                                                              $results-per-page
                                                             )"/>

    <xsl:if test="$DEBUG">
      <xsl:copy-of select="$search-results"/>
    </xsl:if>
    <xsl:apply-templates mode="search-results" select="$search-results"/>
  </xsl:template>

          <xsl:template mode="search-results" match="search:response">
            <xsl:variable name="last-in-full-page" select="@start + @page-length - 1"/>
            <xsl:variable name="end-result-index"  select="if (@total lt @page-length or $last-in-full-page gt @total) then @total
                                                      else $last-in-full-page"/>
            <div class="searchSummary">
              <xsl:text>Results </xsl:text>
              <strong>
                <xsl:value-of select="@start"/>&#8211;<xsl:value-of select="$end-result-index"/>
              </strong>
              <xsl:text> of </xsl:text>
              <strong>
                <xsl:value-of select="@total"/>
              </strong>
              <xsl:text> for </xsl:text>
              <strong>
                <xsl:value-of select="search:qtext"/>
              </strong>
              <xsl:text>.</xsl:text>
            </div>
            <xsl:apply-templates mode="#current" select="search:result"/>
            <xsl:apply-templates mode="prev-and-next" select="."/>
          </xsl:template>

          <xsl:template mode="search-results" match="search:result">
            <xsl:variable name="is-flat-file" select="starts-with(@uri, '/pubs/')"/>
            <xsl:variable name="doc" select="doc(@uri)"/>
            <div class="searchResult">
              <a href="{if ($is-flat-file) then @uri
                                             else ml:external-uri($doc)}">
                <div class="searchTitle">
                  <xsl:variable name="page-specific-title">
                    <xsl:apply-templates mode="page-specific-title" select="$doc/*"/>
                  </xsl:variable>
                  <xsl:value-of select="if (string($page-specific-title)) then $page-specific-title else @uri"/>
                </div>
                <div class="snippets">
                  <xsl:apply-templates mode="search-snippet" select="search:snippet/search:match"/>
                </div>
              </a>
            </div>
          </xsl:template>

                  <!-- Titles for flat HTML files (API docs usually) -->
                  <xsl:template mode="page-specific-title" match="*:html">
                    <xsl:variable name="common-suffix" select="' - MarkLogic Server Online Documentation'"/>
                    <xsl:variable name="title" select="(//*:title)[1]" as="xs:string"/>
                    <xsl:value-of select="if (ends-with($title, $common-suffix)) then substring-before($title, $common-suffix)
                                                                                 else $title"/>
                  </xsl:template>


                  <xsl:template mode="search-snippet" match="search:match">
                    <span class="snippet">
                      <xsl:apply-templates mode="#current"/>
                    </span>
                    <xsl:if test="position() ne last()">...</xsl:if>
                  </xsl:template>

                  <xsl:template mode="search-snippet" match="search:highlight">
                    <span class="highlight">
                      <xsl:apply-templates mode="#current"/>
                    </span>
                  </xsl:template>


                  <xsl:template mode="prev-and-next" match="search:response">              
                    <xsl:if test="@total gt (@start + @page-length - 1)">
                      <div class="nextPage">
                        <a href="/search?q={encode-for-uri($params/qp:q)}&amp;p={$page-number + 1}">Next</a>
                      </div>
                    </xsl:if>
                    <xsl:if test="$page-number gt 1">
                      <div class="prevPage">
                        <a href="/search?q={encode-for-uri($params/qp:q)}&amp;p={$page-number - 1}">Prev</a>
                      </div>
                    </xsl:if>
                    <p/>
                  </xsl:template>

  <xsl:template match="elapsed-time">
    <div style="display: none"><xsl:value-of select="xdmp:query-meters()/*:elapsed-time"/></div>
  </xsl:template>

  <xsl:template match="short-description"/>

</xsl:stylesheet>
