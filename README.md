# sequel-nodedb-adapter

> ## ⚠️ ALPHA / STUB — DO NOT USE IN PRODUCTION
>
> Version: **`0.1.0.alpha.1`**.
>
> This adapter is **experimental, incomplete, and unaudited**. It has **never
> been used or tested in any production environment**. The Sequel-native DSL
> for vector / graph / timeseries is not yet wired in — call
> `NodeDB::SQL::*` builders directly for those features. APIs may change
> without notice between alpha releases.
>
> Run it on disposable data only. Do not point it at customer data, billing
> systems, anything regulated, or any system you cannot trivially rebuild from
> scratch.

[Sequel](https://sequel.jeremyevans.net/) adapter for [NodeDB](https://nodedb.dev) —
a distributed multi-model database that exposes vector, graph, document,
columnar, timeseries, spatial, KV, and FTS engines through a single
PostgreSQL-wire binary on port 6432.

Sits on top of [`nodedb-ruby`](../nodedb-ruby) for connection handling,
type mapping, and SQL building.

## Status

| Area              | State |
| ----------------- | ----- |
| Adapter scheme    | Working — registered as `:nodedb` |
| Connection        | Working — delegates to `NodeDB::Connection` |
| Schema parsing    | Working — `DESCRIBE`-based, hides `__` internals |
| Dataset           | Minimal pass-through (`fetch_rows` yields hashes) |
| Engine helpers    | Not yet wired into Sequel DSL — call `NodeDB::SQL::*` directly |
| Test suite        | None — depends on `activerecord-nodedb-adapter` test infrastructure |
| Stability         | **Stub / experimental.** Use the AR adapter for production today. |

## Requirements

- Ruby 3.2+
- `sequel` >= 5.0
- `nodedb-ruby` >= 0.1.0
- A running NodeDB instance on `pgwire` (default `localhost:6432`)

## Installation

```ruby
gem "sequel"
gem "sequel-nodedb-adapter"
```

Or from source while the gem is unreleased:

```ruby
gem "nodedb-ruby",            path: "../nodedb-ruby"
gem "sequel-nodedb-adapter",  path: "../sequel-nodedb-adapter"
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

### Schema introspection

```ruby
DB.schema(:articles)
# => [[:id, { db_type: "TEXT", allow_null: false, ... }],
#     [:title, { db_type: "TEXT", allow_null: true,  ... }], ...]
```

### Engine SQL via the core gem

The adapter does not (yet) extend Sequel's DSL with vector/graph/etc.
helpers. Use `NodeDB::SQL::*` builders and pass strings to `DB.fetch` /
`DB.execute`:

```ruby
DB.fetch(NodeDB::SQL::Vector.search(
  table:     "articles",
  column:    "embedding",
  embedding: [0.1, 0.2, 0.3],
  limit:     10
)).all

DB.fetch(NodeDB::SQL::FTS.search(
  table:  "posts",
  column: "body",
  query:  "'machine learning'",
  limit:  20
)).all
```

## Feature checklist

### Implemented
- [x] Adapter scheme registration (`set_adapter_scheme :nodedb`)
- [x] `Sequel::Database#connect` via `NodeDB::Connection`
- [x] `disconnect_connection`
- [x] `execute(sql)` with `PG::Error` -> `NodeDB::QueryError` translation
- [x] `schema_parse_table` using NodeDB's `DESCRIBE`
- [x] Internal-column filter (drops `__storage` etc.)
- [x] Bare-identifier `literal_identifier` (NodeDB rejects qualified refs)
- [x] Pass-through `Dataset#fetch_rows`

### Pending
- [ ] Native Sequel migration DSL (`create_collection`, `create_vector_index`)
- [ ] Sequel plugin: `Sequel::Plugins::NodedbVector` for `Article.search_vector`
- [ ] Sequel plugin: `Sequel::Plugins::NodedbGraph`
- [ ] Sequel plugin: `Sequel::Plugins::NodedbTimeseries`
- [ ] Type cast result rows through `NodeDB::TypeMap` (currently strings)
- [ ] Prepared-statement disable equivalent (NodeDB lacks extended-query)
- [ ] RSpec / Sequel `spec_model` test suite
- [ ] Connection-string parsing tests
- [ ] CHANGELOG.md
- [ ] gemspec push to RubyGems

## Known issues

These mirror the parser quirks documented in `nodedb-ruby` and the AR adapter.

- **Qualified column refs return nil.** `literal_identifier` returns the bare
  name; do not wrap in `Sequel.identifier` chains that produce `"t"."c"`.
- **`SELECT *` on document collections returns wrapped JSON.** Until the
  adapter unwraps, project explicit columns: `DB[:articles].select(:id, :title)`.
- **No prepared statements.** NodeDB sends `DataRow` without prior
  `RowDescription` for prepared statements. Sequel's default execution mode
  works because `Database#execute` calls `conn.exec` (simple-query) directly.
- **No `schema_migrations`.** Use `Sequel.migration` blocks but skip the
  built-in migrator's version-tracking table for now (or stub it manually).
- **BUG-001 (`ResourcesExhausted` on non-timeseries INSERT).** Fixed
  upstream in NodeDB source. See `../activerecord-nodedb-adapter/docs/bugs/001-*.md`.

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
