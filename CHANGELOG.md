# Changelog

All notable changes to `sequel-nodedb-adapter` are recorded here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Pre-`1.0` alpha line: APIs may change between alpha releases without
deprecation. Bump `N` in `0.1.0.alpha.N` for any user-visible change.

This gem is a **stub**. New NodeDB features land first in
`activerecord-nodedb-adapter` and mirror here.

## [0.1.0.alpha.5] — 2026-07-04

Tracks NodeDB upstream `main` at `f8a4df44` (post-v0.3.0).

### Fixed

- `Database#search_vector` consumes the projected
  `id`/`_surrogate`/`distance` SEARCH columns (upstream removed the
  single `result` JSON-blob cell); result hashes now expose `"id"`
  (#13). Note: `id` is the document id only on vector-engine
  collections (a result ordinal on document collections with a vector
  index).

### Documentation

- README refreshed for the retest: BUG-018 pruned (native transport at
  result-shape parity), BUG-030 GROUP BY alias-drop caveat, stale
  status rows corrected (#13).

## [0.1.0.alpha.4] — 2026-07-03

### Added
- Database-level NodeDB DDL helpers: `create_collection` (engines,
  `engine_options:`, `bitemporal:`), `drop_collection(if_exists:)`,
  `collections`, `create_vector_index` / `drop_vector_index`.
- Database-level engine helpers: `search_vector` (surrogate + distance
  rows), `graph_stats` (scoped + tenant-wide).
- First automated test suite: 8 rspec integration examples against
  live NodeDB (URL connect, bare-identifier SQL, Dataset CRUD, schema
  dedupe, DDL round-trips, vector search, scoped graph stats).

### Notes
- Writing the suite isolated upstream BUG-029: `count(*)` materializes
  a row counter that DELETE never decrements. Assert cardinality via
  scans around deletes.

## [0.1.0.alpha.3] — 2026-07-03

### Fixed
- **The adapter works now.** The Dataset subclass was never registered
  (`dataset_class_default` missing), so every query on Sequel 5 crashed
  with `NoMethodError: fetch_rows`; `Database#execute` also ignored
  blocks, so results never reached `fetch_rows`.
- Sequel's SQL-standard `:upcase` identifier folding disabled
  (`Dataset#input_identifier`) and identifiers emitted bare — NodeDB
  stores identifiers as written and silently matches zero rows for
  table-qualified refs.
- `schema_parse_table` dedupes the duplicate built-in `id` row that
  `DESCRIBE` emits on `document_strict` collections.

### Changed
- README refreshed for the 2026-07-02 retest against upstream
  `3a06321e`: latest-upstream-only Known issues, Sequel-side
  conventions, working Dataset CRUD usage section.

Manually verified against live NodeDB `3a06321e` (pgwire):
insert / select / where / count / update / delete / schema round-trip.

## [0.1.0.alpha.2] — 2026-05-15

### Changed
- README and Known issues refreshed against the NodeDB v0.2.1 retest
  from the AR adapter. Mirrors the master bug log:
  - **Resolved upstream:** BUG-001, BUG-004, BUG-008, BUG-009, BUG-017.
  - **CHANGED:** BUG-011 — spatial `ST_GeomFromText` now hard-errors
    instead of silently storing literal text; spatial engine still
    unusable for real coordinates.
  - **PARTIAL:** BUG-014 — `pg_try_advisory_lock` parsed but returns
    empty rows; no boolean semantics yet.
  - Known issues now split into three buckets: Resolved upstream,
    Sequel-side workarounds, NodeDB-side open. ([#5])
- `CLAUDE.md` slimmed to defer to the workspace root for shared
  branch/PR/commit conventions. ([#4])

### Docs
- Installation snippets switched to Bundler `github:` shorthand. ([#3])
- Companion packages cross-link table added.

### Internal
- Relative path references corrected after the move into `./gems/`. ([#2])

### Dependencies
- Bump `nodedb-ruby` floor to `>= 0.1.0.alpha.2` so v0.2.1 doc/known-issues
  language stays consistent across the stack.

## [0.1.0.alpha.1] — 2026-05-09

Initial alpha. Sequel adapter for NodeDB; stub-level surface — the
Sequel-native DSL for vector / graph / timeseries is not wired in yet,
call `NodeDB::SQL::*` builders directly for those features.

### Added
- Adapter scheme registration (`set_adapter_scheme :nodedb`).
- `Sequel::Database#connect` delegating to `NodeDB::Connection`.
- `disconnect_connection` hook.
- `execute(sql)` with `PG::Error` → `NodeDB::QueryError` translation.
- `schema_parse_table` using NodeDB's `DESCRIBE`.
- Internal-column filter (drops `__storage` etc.).
- Bare-identifier `literal_identifier` (NodeDB rejects qualified refs).
- Pass-through `Dataset#fetch_rows`.

[0.1.0.alpha.2]: https://github.com/mkhairi/sequel-nodedb-adapter/compare/v0.1.0.alpha.1...v0.1.0.alpha.2
[0.1.0.alpha.1]: https://github.com/mkhairi/sequel-nodedb-adapter/releases/tag/v0.1.0.alpha.1

[#2]: https://github.com/mkhairi/sequel-nodedb-adapter/pull/2
[#3]: https://github.com/mkhairi/sequel-nodedb-adapter/pull/3
[#4]: https://github.com/mkhairi/sequel-nodedb-adapter/pull/4
[#5]: https://github.com/mkhairi/sequel-nodedb-adapter/pull/5
