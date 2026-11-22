# ``DyerlabCore``

UI-free extensions for statistics, dates and natural language, which build on every platform.

## Overview

`DyerlabCore` has no dependencies and no UI, so any target or app can use it. `PresentationZenCore` and
`PresentationZen` re-export it.

### Statistics

- `Array.sum()`, `mean()`, `median()`, `quantile(_:)` and `sd()` on arrays of `Double`, and `discretize`, which
  counts each value.

### Dates

- `Date.get(_:calendar:)` for calendar components, `startOfDay`/`endOfDay`, `onThisDay(day:)`,
  `daysInMonth(_:_:)`, `startOfMonth(currentDate:)`/`endOfMonth(currentDate:)`, `daysOfMonth(containing:)`,
  `mdy(_:)` to parse month/day/year text, and `randomDates(count:days:)` for examples.

### Text and natural language

- `String.csvQuoted` — a field quoted for CSV when it needs it.
- `String.sentiment`, `sentenceLevelSentiment`, `meanSentenceSentiment` and `Double.sentimentEmoji` — NaturalLanguage
  sentiment scores.
- `String.words`, `sentences`, `paragraphs`, `firstWord` and `ARI` (the automated readability index).
- ``NLPTags`` — a word and the tag `NLTagger` gave it, from `String.languageTags(scheme:)`.
