require "sequel-nodedb-adapter"
require "securerandom"

module NodedbSequelHelper
  SUPERUSER_PASSWORD = begin
    File.read(File.expand_path("~/.local/share/nodedb/.superuser_password")).strip
  rescue
    nil
  end
  # The bootstrapped database is named `default`. pgwire binds it whatever
  # name is requested, but the native transport resolves the name against
  # the catalog and rejects an unknown one, so use the real name.
  NODEDB_URL = ENV.fetch("NODEDB_URL", "nodedb://nodedb:#{SUPERUSER_PASSWORD}@localhost:6432/default")

  def self.db
    @db ||= Sequel.connect(NODEDB_URL)
  end

  def self.available?
    db["SELECT 1 AS ok"].first
    true
  rescue => e
    warn "NodeDB not available (#{e.message}). Set NODEDB_URL or start the daemon."
    false
  end
end

NODEDB_AVAILABLE = NodedbSequelHelper.available?

RSpec.configure do |config|
  config.before(:each, :integration) do
    skip "NodeDB not available" unless NODEDB_AVAILABLE
  end
end
