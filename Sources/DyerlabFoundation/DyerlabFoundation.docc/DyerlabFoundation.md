# ``DyerlabFoundation``

The umbrella product — re-exports `Matrix`, `Graph`, `PresentationZen`, and `PopulationGenetics` from a single import.

## Overview

Depend on `DyerlabFoundation` when you want the whole stack — GeneticStudio, a new app being built directly
against this foundation, does exactly that. Consumers that only want the horizontal, domain-agnostic layer
without pulling in `PopulationGenetics` should depend on `Matrix`/`Graph`/`PresentationZen` directly instead;
`Linguistics` does exactly that.

See each product's own documentation for what it provides:

- `Matrix` — linear algebra and general-purpose numeric foundations.
- `Graph` — generic graph theory and force-directed layout.
- `PresentationZen` — the SwiftUI presentation layer for everything above.
- `PopulationGenetics` — diploid genetic-marker storage, import, and analysis.
