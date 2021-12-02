---
title: 'Adding client-side search for a statically generated Hugo website'
date: '2021-12-02'
categories: 
  - Sysadmin
  - Programming
description: Adding search functionality to a statically-generated Hugo website using some Javascript.
slug: hugo-search-functionality
toc: true
---

Statically generated sites, like this blog and other sites built with tools like [Hugo](), are great for simple deployment and fast serving pages, but they lack some features like live editing and other dynamically generated content.
Fortunately, most of these shortcomings have been sorted out by the community.
Here, I'll focus on search functionality.

Typically, when searching some website, the query will be sent to a server, which will perform some internal scan of its database, and build a page containing results that match the query.
This dynamically generated page will then be sent to the client to be shown on the browser.
In a statically generated site, this is simply not an option.
There is no database to query, no framework on the server to search anything, and no concept of generating pages on the fly.

To get around this, the logic of searching a manifest and generating a page of results can be offloaded to the client's browser using Javascript.
[Fuse.js](https://fusejs.io/) is a lightweight searching algorithm that can do the heavy lifting.
What remains is threefold:

1. Automatically generate an manifest of the pages in the site that Fuse.js can use as part of a standard Hugo build.
2. Create a search page in the site that accepts search terms as a `GET` parameter, loads Fuse.js, searches the manifest, and displays results.
3. Add a search bar to some part of the website, which will perform a `GET` request on the search page.

I found [another blog post](https://makewithhugo.com/add-search-to-a-hugo-site/) that gets us most of the way there, but there were a few changes I made for a better search experience, which I will discuss in the following sections.

## Generating a search manifest for Fuse.io

To generate a search manifest for Fuse.js, it is best to leverage Hugo's page generation with a custom layout, such that the logic has easy access to the entire manifest of pages in the site, and it runs automatically each time the site is generated.
The common trick to do achieve this is to create a `layout/_default/index.json` layout that generates an array of page metadata in the Fuse.io input format:
```plaintext
{{- $.Scratch.Add "index" slice -}}
{{- range where site.RegularPages "Type" "in" site.Params.mainSections -}}
    {{- $.Scratch.Add "index" (dict "title" .Title "categories" .Params.categories "contents" .Plain "permalink" .Permalink) -}}
{{- end -}}
{{- $.Scratch.Get "index" | jsonify -}}
```
My improvement here is to use `site.RegularPages "Type" "in" site.Params.mainSections` such that the list of metadata generated is limited to the `mainSections` configurable in the site's `config.toml`.
I found that this removed a tendency for Fuse.io to return duplicate results --- something that perhaps merits further investigation, but was solved by this change.

To have Hugo generate an `index.json` for the home page at the site root, make the following change to the site's `config.toml` to add the `"JSON"` output type.
```toml
[outputs]
    home = ["HTML", "RSS", "JSON"]
```

Hugo will now generate a `/index.json` containing search metadata for the entire site.

## Adding a Javascript-powered search page 

The actual search page could technically be a static HTML file, but to use my `header.html` and `footer.html` partials for integration with the rest of the site, it is better to create a new layout to generate the search page in `layout/_default/search.html`:
```html
{{ partial "header.html" . }}

<div class="content-wrapper">
<main>
  <div id="search-results"></div>
  <div class="search-loading">Searching...</div>

  <script id="search-result-template" type="text/x-js-template">
  <div id="summary-${key}">
      <h3><a href="${link}">${title}</a></h3>
      <p>${snippet}</p>
      <p>
          <small>
              ${ isset categories }Categories: ${categories}<br>${ end }
          </small>
      </p>
  </div>
  </script>

  <script src="https://cdnjs.cloudflare.com/ajax/libs/fuse.js/3.2.0/fuse.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/mark.js/8.11.1/mark.min.js"></script>
  <script src="/search.js"></script>

</main>
</div>

{{ partial "footer.html" . -}}
```

This loads Fuse.js and includes a `<div>` for `search-results` along with a template script `search-result-template` that our `search.js` javascript will use to populate the page with Fuse.js results.

To have Hugo generate a `/search.html` page, add a stub markdown file as `content/search.md` that specifies the `search` layout:
```plaintext
---
title: "Search"
sitemap:
  priority : 0.1
layout: "search"
---
```
None of the content in this file will have any effect, since the `search` layout does not use it.
The low `priority` informs search engines that this page is not important.

The actual `search.js` script goes in the `static/` directory, and will do the heavy lifting: retrieving the site search manifest, running Fuse.io, and populating the search results page.
Compared to the original source, I've: modified this to ignore tags entirely, to focus on categories; increased the default summary length; and fixed the Javascript so it runs out-of-the-box (the order of functions wasn't executing in a current Firefox).
```javascript
var summaryInclude = 120;
var fuseOptions = {
    shouldSort: true,
    includeMatches: true,
    threshold: 0.0,
    tokenize: true,
    location: 0,
    distance: 100,
    maxPatternLength: 32,
    minMatchCharLength: 1,
    keys: [
        {name: "title", weight: 0.8},
        {name: "contents", weight: 0.5},
        {name: "categories", weight: 0.3}
    ]
};

var show = function (elem) {
    elem.style.display = 'block';
};
var hide = function (elem) {
    elem.style.display = 'none';
};

var inputBox = document.getElementById('search-query');
if (inputBox !== null) {
    var searchQuery = param("q");
    if (searchQuery) {
        inputBox.value = searchQuery || "";
        executeSearch(searchQuery, false);
    } else {
        document.getElementById('search-results').innerHTML = '<p class="search-results-empty">Please enter a word or phrase in the search bar, or see <a href="/categories/">all categories</a>.</p>';
    }
}

function executeSearch(searchQuery) {

    show(document.querySelector('.search-loading'));

    fetch('/index.json').then(function (response) {
        if (response.status !== 200) {
            console.log('Looks like there was a problem. Status Code: ' + response.status);
            return;
        }
        // Examine the text in the response
        response.json().then(function (pages) {
            var fuse = new Fuse(pages, fuseOptions);
            var result = fuse.search(searchQuery);
            if (result.length > 0) {
                populateResults(result);
            } else {
                document.getElementById('search-results').innerHTML = '<p class=\"search-results-empty\">No matches found</p>';
            }
            hide(document.querySelector('.search-loading'));
        })
        .catch(function (err) {
            console.log('Fetch Error :-S', err);
        });
    });
}

function populateResults(results) {

    var searchQuery = document.getElementById("search-query").value;
    var searchResults = document.getElementById("search-results");

    // pull template from hugo template definition
    var templateDefinition = document.getElementById("search-result-template").innerHTML;

    results.forEach(function (value, key) {

        var contents = value.item.contents;
        var snippet = "";
        var snippetHighlights = [];

        snippetHighlights.push(searchQuery);
        snippet = contents.substring(0, summaryInclude * 2) + '&hellip;';

        //replace values
        var categories = ""
        if (value.item.categories) {
            value.item.categories.forEach(function (element) {
                categories = categories + "<a href='/categories/" + element + "'>" + element + "</a>, "
            });
        }
        if (categories.length > 2) {
            categories = categories.substring(0,categories.length-2);
        }

        var output = render(templateDefinition, {
            key: key,
            title: value.item.title,
            link: value.item.permalink,
            categories: categories,
            snippet: snippet
        });
        searchResults.innerHTML += output;

        snippetHighlights.forEach(function (snipvalue, snipkey) {
            var instance = new Mark(document.getElementById('summary-' + key));
            instance.mark(snipvalue);
        });

    });
}

function param(name) {
    return decodeURIComponent((location.search.split(name + '=')[1] || '').split('&')[0]).replace(/\+/g, ' ');
}

function render(templateString, data) {
    var conditionalMatches, conditionalPattern, copy;
    conditionalPattern = /\$\{\s*isset ([a-zA-Z]*) \s*\}(.*)\$\{\s*end\s*}/g;
    //since loop below depends on re.lastInxdex, we use a copy to capture any manipulations whilst inside the loop
    copy = templateString;
    while ((conditionalMatches = conditionalPattern.exec(templateString)) !== null) {
        if (data[conditionalMatches[1]]) {
            //valid key, remove conditionals, leave contents.
            copy = copy.replace(conditionalMatches[0], conditionalMatches[2]);
        } else {
            //not valid, remove entire section
            copy = copy.replace(conditionalMatches[0], '');
        }
    }
    templateString = copy;
    //now any conditionals removed we can do simple substitution
    var key, find, re;
    for (key in data) {
        find = '\\$\\{\\s*' + key + '\\s*\\}';
        re = new RegExp(find, 'g');
        templateString = templateString.replace(re, data[key]);
    }
    return templateString;
}

```

## Adding a search field to the navigation bar

Finally, add a search bar to the site.
I chose to add this to my navigation bar at the top, so that it automatically appears on every page, but it can be inserted anywhere:
```html
<form action="/search" method="GET">
  <input class="searchbar" type="search" name="q" id="search-query" placeholder="Search....">
</form>
```
