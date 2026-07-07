# ADR-0003: Reader highlight UI and master-detail delete cleanup

Date: 2026-07-07
Status: accepted

## Decision
Keep manual highlighting v1 as a single named tint in ReaderScreen, cover the user highlight flows with widget tests, clear the tablet master-detail selection when its selected library entry is removed, and remove the unused readerSideGutter token from AppTokens.

## Context / why
The recovered highlight implementation already persisted ranges and rendered them inline, but coverage stopped below the ReaderScreen widget flow. ADR-0002 also documented two deferred cleanup items: a selected tablet detail pane could keep showing a deleted entry, and readerSideGutter existed as a token with no consumer. Colored highlights remain a post-1.0 product backlog item in ROADMAP.md, so adding a picker now would expand scope without a release decision.

## Consequences
Long-press highlighting, current-position highlighting, highlight list/delete, and ReaderScreen repaint behavior are now guarded by Flutter widget tests. Wide library deletion returns the detail pane to its empty selection prompt instead of showing stale content. AppTokens only contains structural metrics currently used by the app; future reader gutter work should add a token when it is consumed in the same change.
