require_relative "lib/sequel/adapters/nodedb/version"

Gem::Specification.new do |spec|
  spec.name = "sequel-nodedb-adapter"
  spec.version = Sequel::Adapters::NodeDB::VERSION
  spec.authors = ["Khairi"]
  spec.email = ["khairi@labs.my"]

  spec.summary = "Sequel adapter for NodeDB — the distributed multi-model database"
  spec.description = "Connects Sequel to NodeDB via PostgreSQL wire protocol (pgwire). " \
                     "Depends on nodedb-ruby for connection handling, type mapping, and " \
                     "NodeDB-specific SQL builders."
  spec.homepage = "https://github.com/mkhairi/sequel-nodedb-adapter"
  spec.license = "BSD-2-Clause"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "LICENSE.md", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "sequel", ">= 5.0"
  spec.add_dependency "nodedb-ruby", ">= 0.1.0.alpha.9"
end
