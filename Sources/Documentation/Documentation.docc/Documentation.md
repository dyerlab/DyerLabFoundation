# ``Documentation``

An app's help, browsed like DocC documentation: an outline with search beside each page.

## Overview

An app ships a JSON index and the HTML pages it names, and adds three things:

```swift
@State private var help = DocumentationLibrary(bundled: "help", title: "MyApp Help")

var body: some Scene {
    DocumentGroup(…) { ContentView().environment(help) }
        .commands { DocumentationCommands(library: help) }
    DocumentationScene(library: help)
}
```

``DocumentationLink`` then puts a (?) button anywhere in the app that opens the help window at a topic.

### The index

```json
{
  "title": "MyApp Help",
  "home": "welcome",
  "entries": [
    { "id": "welcome", "title": "Welcome", "file": "welcome.html" },
    { "id": "background", "title": "Background", "children": [
      { "id": "inbreeding", "title": "Nonrandom Mating", "file": "inbreeding.html",
        "url": "https://example.org/inbreeding.html",
        "children": [ { "id": "inbreeding.selfing", "title": "Selfing", "anchor": "sec-selfing" } ] }
    ] }
  ]
}
```

Only `id` and `title` are required. `file` is relative to the index, and a bundled file is shown in preference to
`url`, which is then offered as the online version. An entry with only a `url` is read from the web. A section names
an `anchor` and inherits its page from the entry above it. An entry with `children` and no page shows an overview of
them, and one with nothing is listed as not yet written. `summary`, `keywords` and `symbol` (an SF Symbol) are
optional.

Ids are what ``DocumentationLink`` names, so the generator that writes the index must keep them stable.

### Pages

Each page should be one self-contained HTML file (images, styles and math inline) so the help works offline, and
should follow `prefers-color-scheme` for dark mode. Links to other pages in the help folder stay in the browser;
links anywhere else open in the user's browser.

## Topics

### Help

- ``DocumentationLibrary``
- ``DocumentationIndex``
- ``DocumentationEntry``
- ``DocumentationSearchResult``
- ``DocumentationText``
- ``DocumentationError``

### Interface

- ``DocumentationBrowser``
- ``DocumentationScene``
- ``DocumentationCommands``
- ``DocumentationLink``
