# ``DyerlabFoundation``

The umbrella product — re-exports `Matrix`, `Graph`, `PresentationZen` (with `PresentationZenCore` and `DyerlabCore`),
`PopulationGenetics` and `Documentation` from a single import.

## Overview

Depend on `DyerlabFoundation` when you want the whole stack — GeneticStudio, a new app being built directly
against this foundation, does exactly that. Consumers that only want the horizontal, domain-agnostic layer
without pulling in `PopulationGenetics` should depend on `Matrix`/`Graph`/`PresentationZen` directly instead;
`Linguistics` does exactly that. An app that only shows its data, without the C++ `Matrix` library, can depend on
`PresentationZenCore` alone, as MyDeck's charts do.

See each product's own documentation for what it provides:

- `DyerlabCore` — UI-free statistics, date and natural-language extensions.
- `Matrix` — linear algebra and general-purpose numeric foundations.
- `Graph` — generic graph theory and force-directed layout.
- `PresentationZenCore` — charts, data tables, figures and exports on Swift Charts and TabularData alone.
- `PresentationZen` — the SwiftUI presentation layer for `Matrix` and `Graph`, re-exporting `PresentationZenCore`.
- `PopulationGenetics` — diploid genetic-marker storage, import, and analysis.
- `Documentation` — an app's help browser, window, menu item and help button.
