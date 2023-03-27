# feeder
A simple RSS/Atom feed reader, just the way I like it (and hope you do to).

Try it here:
* http://yoy.be/home/feeder/

See also
* http://yoy.be/xxm
* https://github.com/stijnsanders/DataLank

----

## developer notes

_feeder_ for the moment, in an attempt to avoid including a full account management sub-system here, uses a link to [_tx_](https://github.com/stijnsanders/tx#tx) for user authentication. To get going on a version for yourself that doesn't require _tx_, in unit `xxmSession.pas` change `UserID:=0;` to `UserID:=1;` and create a record in table `User` for yourself.

## supported feed formats

<table>
<tr>
<th>Name</th>
<th>Description</th>
</tr>

<tr>	
<td>Atom</td>
<td>xmlns:atom="http://www.w3.org/2005/Atom"</td>
</tr>

<tr>
<td>RSS</td>
<td>valid XML that answers to <code>documentElement.selectNodes('channel/item')</code></td>
</tr>

<tr>
<td>JSONFeed</td>
<td>https://jsonfeed.org/version/1</td>
</tr>

<tr>
<td>RSS-in-JSON</td>
<td>as described <a href="https://github.com/scripting/Scripting-News/blob/master/rss-in-json/README.md">here</a></td>
</tr>

<tr>
<td>RDF</td>
<td>xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" and/or xmlns:rss="http://purl.org/rss/1.0/"</td>
</tr>

<tr>
<td>Instagram</td>
<td>Posts are created from <a href="https://graphql.org/">GraphQL</a> query JSON.</td>
</tr>

<tr>
<td>SPARQL</td>
<td><code>PREFIX schema: &lt;http://schema.org/&gt; SELECT * WHERE { ?news a schema:NewsArticle</code> ...</td>
</td>
</tr>

<tr>
<td>Tumblr</td>
<td>Tumblr has RSS feeds, but since GDPR, requires a consent cookie. I have hardcoded one, but as it expires now and then I need to replace it manually (until I find a better solution or Tumblr no longer requires GDPR consent on RSS fetches)</td>
</tr>

<tr>
<td>WordPress API</td>
<td>If HTML declares <code>&lt;link rel="https://api.w.org/"</code>, posts are loaded from <code>/wp/v2/posts</code> JSON.</td>
</tr>

<tr>
<td>SoundCloud API</td>
<td>Use a user's URL to see new tracks as posts.</td>
</tr>

<tr>
<td>Titanium</td>
<td>Posts are loaded from <code>window['titanium-state']=</code> JSON.</td>
</tr>

<tr>
<td>Fusion</td>
<td>Posts are loaded from <code>Fusion.globalContent=</code> JSON.</td>
</tr>

<tr>
<td>NextData</td>
<td>Posts are loaded from <code>&lt;script id="__NEXT_DATA__" type="application/json"&gt;</code> JSON.</td>
</tr>

<tr>
<td>NatGeo</td>
<td>Posts are loaded from <code>window['__natgeo__']=</code> JSON.</td>
</tr>

<tr>
<td>Remix</td>
<td>Posts are loaded from <code>window.__remixContext=</code> JSON.</td>
</tr>

<tr>
<td>Gatsby</td>
<td>Posts are laded from <code>/page-data/index/page-data.json</code>.</td>
</tr>

<tr>
<td>HTML</td>
<td>Headers are searched for an appropriate <code>&lt;link rel="alternative"</code> element to update to a feed URL.<br />
If none is found, the HTML content is search for one of these patterns:
</td>
</tr>

<tr>
<td>HTML:P</td>
<td>Posts are loaded using a specific set of regular expressions on the raw page HTML data.</code>
</td>
</tr>

<tr>
<td><i>more?</i></td>
<td><i>If you find a site with periodical entries, that doesn't offer an RSS feed, feel free to post an issue on this repo with the URL and ny extra information.</i></td>
</tr>

</table>