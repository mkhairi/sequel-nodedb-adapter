require "spec_helper"

RSpec.describe "Sequel NodeDB connect options (no daemon)" do
  let(:captured) { {} }

  before do
    allow(NodeDB::Connection).to receive(:connect) do |**kw|
      captured.replace(kw)
      double("pg conn", close: nil)
    end
  end

  def connect_with(target, **opts)
    db = Sequel.connect(target, test: false, **opts)
    db.synchronize { nil }
    db
  end

  it "forwards sslmode and connect_timeout from the URL" do
    connect_with("nodedb://u:p@db.example:6432/default?sslmode=verify-full&connect_timeout=5")

    expect(captured).to include(sslmode: "verify-full", connect_timeout: "5",
      host: "db.example", port: 6432, dbname: "default", user: "u")
  end

  it "forwards ssl file options from an options hash and drops unknown keys" do
    connect_with({adapter: :nodedb, host: "h", database: "default",
                  sslmode: "require", sslrootcert: "/etc/ca.pem", foo: "bar"})

    expect(captured).to include(sslmode: "require", sslrootcert: "/etc/ca.pem")
    expect(captured).not_to have_key(:foo)
  end

  it "adds no TLS keys when none are configured" do
    connect_with("nodedb://u:p@h:6432/default")

    expect(captured.keys).to contain_exactly(:host, :port, :dbname, :user, :password)
  end
end
