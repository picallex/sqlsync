# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

require "./spec_helper"

describe "mapping" do
  it "insert destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["di", "eman"])
      desc.add_column "di", "int"
      desc.add_column "eman", "string"
      desc.add_column "tsal", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_mapping "di", "id"
      desc.add_mapping "eman", "name"
      desc.add_mapping "tsal", "last"

      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"di" => 1, "eman" => "bob", "tsal" => "bob"}

    destination_data = Sqlsync::Data.new(dest)

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("INSERT INTO \"destino\" (\"id\",\"name\",\"last\") VALUES (1, 'bob', 'bob')")
  end
end
