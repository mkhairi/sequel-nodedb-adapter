# sequel-nodedb-adapter

> ## ⚠️ ALPHA — DO NOT USE IN PRODUCTION
>
> Version: **`0.1.0.alpha.4`**. Tracks NodeDB upstream `main` at
> `67c4572d` (post-v0.3.0, retested 2026-07-04).
>
> This adapter is **experimental, incomplete, and unaudited**. It has
> **never been used or tested in any production environment**. Core
> Dataset CRUD works as of alpha.3; the Sequel-native DSL for
> vector / graph / timeseries is not yet wired in — call
> `NodeDB::SQL::*` builders directly for those features. APIs may
> change without notice between alpha releases.
>
> Run it on disposable data only. Do not point it at customer data,
> billing systems, anything regulated, or any system you cannot
> trivially rebuild from scratch.

[Sequel](https://sequel.jeremyevans.net/) adapter for [NodeDB](https://nodedb.dev) —
a distributed multi-model database that exposes vector, graph, document,
columnar, timeseries, spatial, KV, and FTS engines through a single
PostgreSQL-wire binary on port 6432.

Sits on top of [`nodedb-ruby`](../nodedb-ruby) for connection handling,
type mapping, and SQL building.

## Companion packages

| Repo | Role |
| ---- | ---- |
| [`mkhairi/nodedb-ruby`](https://github.com/mkhairi/nodedb-ruby) | core — pgwire connection, type map, SQL builders |
| [`mkhairi/activerecord-nodedb-adapter`](https://github.com/mkhairi/activerecord-nodedb-adapter) | Rails ActiveRecord adapter (production-ready API surface) |
| [`mkhairi/sequel-nodedb-adapter`](https://github.com/mkhairi/sequel-nodedb-adapter) | **this gem** — Sequel adapter (stub) |
| [`mkhairi/nodedb-on-rails`](https://github.com/mkhairi/nodedb-on-rails) | Rails 8 sample app exercising every NodeDB engine |

## Status

| Area              | State |
| ----------------- | ----- |
| Adapter scheme    | Working — registered as `:nodedb` |
| Connection        | Working — delegates to `NodeDB::Connection` |
| Schema parsing    | Working — `DESCRIBE`-based, hides `__` internals, dedupes the duplicate `id` row |
| Dataset           | Working — insert / select / where / count / update / delete round-trip; bare unqualified identifiers emitted (NodeDB requirement) |
| Engine helpers    | `Database#search_vector` / `#graph_stats`; other engines via `NodeDB::SQL::*` builders |
| Test suite        | `bundle exec rspec` — 8 examples against a live daemon |
| NodeDB versions   | 0.1.x through post-v0.3.0 `main` (latest retest 2026-07-04 against `67c4572d`) |
| Stability         | **Experimental.** Use the AR adapter for production-shaped work today. |

## Requirements

- Ruby 3.2+
- `sequel` >= 5.0
- `nodedb-ruby` >= 0.1.0.alpha.5 (transitively requires the v0.3.0 SQL builders for `SHOW GRAPH STATS`, `BITEMPORAL` flags, and `PERSONALIZATION`)
- A running NodeDB instance on `pgwire` (default `localhost:6432`) —
  **latest upstream `main` recommended** (verified against `67c4572d`).
  Post-June builds changed the on-disk format; start daemons on a
  fresh data directory.

## Installation

Both this gem and `nodedb-ruby` are alpha and not yet on rubygems. Pull
from GitHub via Bundler's `github:` shorthand:

```ruby
gem "sequel"
gem "nodedb-ruby",           github: "mkhairi/nodedb-ruby",           branch: "main"
gem "sequel-nodedb-adapter", github: "mkhairi/sequel-nodedb-adapter", branch: "main"
```

For SSH-only setups: `bundle config github.https false` (one-time).

For monorepo development against local checkouts:

```ruby
gem "nodedb-ruby",           path: "../nodedb-ruby"
gem "sequel-nodedb-adapter", path: "../sequel-nodedb-adapter"
```

Once the gems ship to rubygems, the standard form will work:

```ruby
gem "sequel"
gem "sequel-nodedb-adapter"
```

## Usage

### Connect

```ruby
require "sequel-nodedb-adapter"

DB = Sequel.connect(
  adapter:  :nodedb,
  host:     "localhost",
  port:     6432,
  database: "myapp",
  user:     "nodedb",
  password: ENV["NODEDB_PASSWORD"]
)

DB["SELECT 1+1 AS r"].first  # => { r: "2" }
```

URL-style works too:

```ruby
DB = Sequel.connect("nodedb://nodedb:#{ENV['NODEDB_PASSWORD']}@localhost:6432/myapp")
```

### Dataset CRUD

```ruby
DB.run(<<~SQL)
  CREATE COLLECTION items (id TEXT PRIMARY KEY, name TEXT, score FLOAT)
  WITH (engine='document_strict')
SQL

DB[:items].insert(id: "a", name: "alpha", score: 7.0)
DB[:items].where(name: "alpha").select(:id).all   # => [{id: "a"}]
DB[:items].count                                  # => 1
DB[:items].where(id: "a").update(score: 9.0)
DB[:items].where(id: "a").delete                  # autocommit — clean path
```

Row values arrive as strings (TypeMap casting is roadmap). Keep
identifiers unqualified — the adapter emits bare names by design.

### Schema introspection

```ruby
DB.schema(:articles)
# => [[:id, { db_type: "TEXT", allow_null: false, ... }],
#     [:title, { db_type: "TEXT", allow_null: true,  ... }], ...]
```

### NodeDB DDL helpers

```ruby
DB.create_collection(:articles)                       # schemaless document
DB.create_collection(:metrics, engine: :timeseries,
  engine_options: { retention: "7d" })
DB.create_collection(:audit, engine: :document_strict,
  columns: ["id TEXT PRIMARY KEY", "actor TEXT"],
  bitemporal: true)                                   # emits ENGINE = suffix

DB.create_vector_index(:idx_articles_emb,
  on: :articles, column: :embedding, metric: :cosine, dim: 384)

DB.collections                       # => ["articles", "metrics", ...]
DB.drop_collection(:articles, if_exists: true)
```

These work inside `Sequel.migration` blocks (skip the built-in
migrator's version tracking — see Known issues).

### Engine helpers

```ruby
DB.search_vector(:articles, :embedding, [0.1, 0.2, 0.3], limit: 10)
# => [{ "surrogate" => 12, "distance" => 0.043 }, ...]

DB.graph_stats(collection: "social_nodes")   # scoped counters
DB.graph_stats                               # tenant-wide

# Anything else via the nodedb-ruby builders + raw fetch:
DB.fetch(NodeDB::SQL::FTS.search(
  table: "posts", column: "body", query: "'machine learning'", limit: 20
)).all
```

## Feature checklist

### Implemented
- [x] Adapter scheme registration (`set_adapter_scheme :nodedb`)
- [x] `Sequel::Database#connect` via `NodeDB::Connection`
- [x] `disconnect_connection`
- [x] `execute(sql)` with `PG::Error` -> `NodeDB::QueryError` translation, yields results to blocks
- [x] Dataset class wiring (`dataset_class_default`) — CRUD round-trips
- [x] `schema_parse_table` using NodeDB's `DESCRIBE` (dedupes the duplicate `id` row)
- [x] Internal-column filter (drops `__storage` etc.)
- [x] Bare unqualified identifiers (`input_identifier` / `quoted_identifier_append`) — NodeDB stores identifiers as written and silently matches zero rows for qualified refs
- [x] `Dataset#fetch_rows` with symbol keys + `columns` population

- [x] NodeDB DDL helpers on `Database`: `create_collection` (engines,
      `engine_options:`, `bitemporal:`), `drop_collection(if_exists:)`,
      `collections`, `create_vector_index` / `drop_vector_index` —
      usable inside `Sequel.migration` blocks
- [x] Engine helpers on `Database`: `search_vector` (surrogate +
      distance rows), `graph_stats` (scoped + tenant-wide)
- [x] Simple-query-only execution (NodeDB lacks extended-query
      `RowDescription`; `Database#execute` uses `conn.exec` directly)
- [x] RSpec integration suite (`spec/`, 8 examples against live NodeDB,
      includes `nodedb://` URL connection-string coverage)
- [x] CHANGELOG.md

### Pending
- [ ] Sequel model plugins (`Sequel::Plugins::NodedbVector` /
      `NodedbGraph` / `NodedbTimeseries`) — Database-level helpers
      cover the surface today
- [ ] Type cast result rows through `NodeDB::TypeMap` (currently strings)
- [ ] Built-in migrator version tracking (`schema_migrations` equivalent)
- [ ] gemspec push to RubyGems

## Known issues

Tracks the **latest upstream only** (resolved issues pruned; git
history keeps the record). Canonical per-bug records (reproductions,
workaround history, retests) live in the
[AR adapter issue tracker][ar-bugs] — titles prefixed
`[upstream:NodeDB] BUG-NNN`; the user-facing summary is
[KNOWN_ISSUES.md][ar-known]. Last retested:
**2026-07-04** against upstream `main` at `f8a4df44`.

[ar-bugs]: https://github.com/mkhairi/activerecord-nodedb-adapter/issues?q=%22%5Bupstream%3ANodeDB%5D%22
[ar-known]: https://github.com/mkhairi/activerecord-nodedb-adapter/blob/main/docs/KNOWN_ISSUES.md

### Sequel-side conventions

- **Identifiers are emitted bare and unqualified.** NodeDB stores
  identifiers as written (the adapter disables Sequel's SQL-standard
  upcase folding) and silently matches zero rows for table-qualified
  refs (BUG-025) — avoid `Sequel[:t][:c]` qualification and joins.
- **`SELECT *` on schemaless document collections returns wrapped
  JSON.** Project explicit columns: `DB[:articles].select(:id, :title)`
  — or use `engine: :document_strict`.
- **No prepared statements.** Sequel's default path is fine here —
  `Database#execute` uses simple-query `conn.exec` directly.
- **No `schema_migrations` integration.** Use `Sequel.migration`
  blocks but skip the built-in migrator's version tracking (or stub it
  manually).
- **Engine surfaces via raw SQL.** `DB.fetch("SHOW GRAPH STATS 'social_nodes'").all`
  (scoped form works on current upstream),
  `DB.fetch("SHOW MEMORY").all`, and `NodeDB::SQL::*` builders for
  vector/graph/FTS/DDL. Sequel-native plugins are roadmap work.
- **Row values arrive as strings** (no TypeMap casting yet — roadmap).

### NodeDB-side (open upstream, affects Sequel callers)

- **BUG-008** — DELETE committed inside `DB.transaction { }` leaves a
  stale PK point-lookup phantom (`WHERE id = ...` returns the deleted
  row until the key is re-inserted). Sequel's default autocommit
  deletes (`DB[:t].where(...).delete`) take the clean path — prefer
  them.
- **Bitemporal caveats** — INSERT/DELETE committed inside explicit
  transactions are lost on `BITEMPORAL` collections (BUG-024): write
  autocommit (Sequel's default). Never DROP + CREATE a bitemporal
  collection under the same name (BUG-028) and never name a column
  `bitemporal_id` (BUG-026). Reads — plain SELECT and
  `AS OF SYSTEM TIME` history — work on current upstream.
- **BUG-029** — `count(*)` materializes a per-collection row counter
  on first read that DELETE never decrements; counts drift upward
  permanently once rows are deleted. Assert cardinality via scans
  (`ds.select(:id).all.length`) around delete operations.
- **BUG-003** — libpq's `PQserverVersion()` raises; query
  `current_setting('server_version_num')` instead.
- **BUG-014** — advisory locks return empty rows (upstream won't-fix
  on pgwire).
- **BUG-019** — pg_catalog gaps: `db.tables` may fail or narrow;
  `DB.fetch("SHOW COLLECTIONS").all` is the safe fallback.
- **BUG-023** — `MATCH ... IN <collection>` ignores collection scope;
  avoid MATCH until upstream fixes it.
- **BUG-030** — GROUP BY output drops group-key column aliases (and
  returns empty cells for unaliased aggregates) on current upstream.
  Alias your aggregates and read group keys by base column name.

## Roadmap

The adapter exists today to keep the Sequel community in sync with the AR
adapter's surface area. The Sequel-native DSL (plugins for vector, graph,
timeseries, …) lands next, followed by a dedicated test suite. Until then,
new NodeDB features are validated through `activerecord-nodedb-adapter` and
mirrored here.

## License

Released under the **BSD 2-Clause License**. Full text: [LICENSE.md](LICENSE.md).

Independent third-party adapter. Not affiliated with, endorsed by, or
maintained by the NodeDB project. "NodeDB" is referenced solely to identify
the database this gem connects to.
