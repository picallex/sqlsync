# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

require "./spec_helper"

describe Sqlsync do
  it "TEL-927 sync to remote fail allow use of command to get current switchname" do
    out = Sqlsync::Value.eval("{exec:echo 'probando'}")
    out.should eq("probando")
  end

  it "TEL-741 sqlite3 driver must not create database" do
    table = Sqlsync::Table.new do
    end

    expect_raises(Sqlsync::Driver::Error, /sqlite3 not file exists \/tmp\/mala/) do
      Sqlsync::Driver::Sqlite3.new(table, "sqlite3:///tmp/mala")
    end
  end

  it "quote sqlite3" do
    quoter = Sqlsync::Driver::Sqlite3::Quoter.new

    quoter.quote_column_name("\"hola").should eq("\"\\\"hola\"")
    quoter.quote_column_value("'hola").should eq("'\\'hola'")
  end

  it "quote postgres" do
    quoter = Sqlsync::Driver::Postgres::Quoter.new

    quoter.quote_column_name("\"hola").should eq("\"\\\"hola\"")
    quoter.quote_column_value("'hola").should eq("'\\'hola'")
  end

  it "hash table row" do
    row1 = Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bob"}
    row2 = Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bob"}
    row1.should eq(row2)
  end

  it "data row same hash" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bob"}

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bob"}

    destination_data.to_set.should eq(source_data.to_set)
  end

  it "update destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "foo"}

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bar"}

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("UPDATE \"destino\" SET \"id\" = 1, \"name\" = 'bob', \"last\" = 'foo' WHERE \"id\" = 1 AND \"name\" = 'bob'")
  end

  it "update multiple destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "foo"}
    source_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "foo"}

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bar"}
    destination_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "bar"}

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("UPDATE \"destino\" SET \"id\" = 1, \"name\" = 'bob', \"last\" = 'foo' WHERE \"id\" = 1 AND \"name\" = 'bob';UPDATE \"destino\" SET \"id\" = 2, \"name\" = 'bob', \"last\" = 'foo' WHERE \"id\" = 2 AND \"name\" = 'bob'")
  end

  it "insert destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bob"}

    destination_data = Sqlsync::Data.new(dest)

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("INSERT INTO \"destino\" (\"id\",\"name\",\"last\") VALUES (1, 'bob', 'bob')")
  end

  it "insert multiple destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bob"}
    source_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "bar"}

    destination_data = Sqlsync::Data.new(dest)

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("INSERT INTO \"destino\" (\"id\",\"name\",\"last\") VALUES (1, 'bob', 'bob'),(2, 'bob', 'bar')")
  end

  it "update and insert destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bob"}
    source_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "foo"}
    source_data.add_row Sqlsync::Table::Row{"id" => 3, "name" => "coc", "last" => "coc"}

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "bar"}

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("UPDATE \"destino\" SET \"id\" = 2, \"name\" = 'bob', \"last\" = 'foo' WHERE \"id\" = 2 AND \"name\" = 'bob';INSERT INTO \"destino\" (\"id\",\"name\",\"last\") VALUES (1, 'bob', 'bob'),(3, 'coc', 'coc')")
  end

  it "delete destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "bar"}

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("DELETE FROM \"destino\" WHERE \"id\" = 2 AND \"name\" = 'bob'")
  end

  it "delete multiple destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "bar"}
    destination_data.add_row Sqlsync::Table::Row{"id" => 3, "name" => "bob", "last" => "bar"}

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("DELETE FROM \"destino\" WHERE \"id\" IN (2,3)")
  end

  it "insert/delete destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bob"}

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "bar"}

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    diff.tosql(psql).join(";").should eq("INSERT INTO \"destino\" (\"id\",\"name\",\"last\") VALUES (1, 'bob', 'bob');DELETE FROM \"destino\" WHERE \"id\" = 2 AND \"name\" = 'bob'")
  end

  it "doman to sql" do
    table = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    quoter = Sqlsync::Driver::Sqlite3::Quoter.new

    domain = Sqlsync::Domain.from_json(JSON.parse(%{[["column", "=", "bob"], ["columna", "=", 3]]}))
    domain.to_sql(quoter).should eq("\"column\" = 'bob' AND \"columna\" = 3")
  end

  it "use domain when update destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)
    source_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "foo"}

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 1, "name" => "bob", "last" => "bar"}

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    domain = Sqlsync::Domain.from_json(JSON.parse(%{[["last", "=", "bob"]]}))
    diff.tosql(psql, domain).join(";").should eq("UPDATE \"destino\" SET \"id\" = 1, \"name\" = 'bob', \"last\" = 'foo' WHERE \"id\" = 1 AND \"name\" = 'bob' AND \"last\" = 'bob'")
  end

  it "use domain when delete destination postgresql table using primary key" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "fuente"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["id", "name"])
      desc.add_column "id", "int"
      desc.add_column "name", "string"
      desc.add_column "last", "string"
    end

    source_data = Sqlsync::Data.new(source)

    destination_data = Sqlsync::Data.new(dest)
    destination_data.add_row Sqlsync::Table::Row{"id" => 2, "name" => "bob", "last" => "bar"}

    psql = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(source_data, destination_data)
    domain = Sqlsync::Domain.from_json(JSON.parse(%{[["last", "=", "bob"]]}))
    diff.tosql(psql, domain).join(";").should eq("DELETE FROM \"destino\" WHERE \"id\" = 2 AND \"name\" = 'bob' AND \"last\" = 'bob'")
  end
end
