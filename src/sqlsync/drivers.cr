# @author (2021) Jovany Leandro G.C <jovany@picallex.com>
require "db"
require "log"

require "sqlite3"
require "pg"

class Sqlsync::Driver::Error < Exception
end

class Sqlsync::Driverer
  # obtener data a sincronizar
  def get_data(domain : Sqlsync::Domain? = nil) : Sqlsync::Data
    raise NotImplementedError.new("get_data")
  end

  # ejecutar plan SQL para sincronizar
  def execute(sqls : Array(String))
    raise NotImplementedError.new("execute")
  end

  def close
  end
end

class Sqlsync::Driver::CrystalDB < Sqlsync::Driverer
  def initialize(@table : Table, @db_url : String)
  end

  def execute(sqls : Array(String))
    DB.open(@db_url) do |db|
      sqls.each do |sql|
        db.exec sql
      end
    end
  end

  def quoter
    raise NotImplementedError.new("quoter")
  end

  def get_data(domain : Sqlsync::Domain? = nil) : Sqlsync::Data
    data = Sqlsync::Data.new(@table)

    DB.connect(@db_url) do |db|
      if db.responds_to?(:on_notice)
        db.on_notice { |x| raise "#{x}" }
      end

      columns_to_query = @table.columns.map { |c| quoter.quote_column_name(c.name) }.join(",")
      sql_query = "SELECT #{columns_to_query} FROM #{quoter.quote_table_name(@table.name)}"
      unless domain.nil?
        domain_sql = domain.to_sql(quoter)
        if domain_sql != ""
          sql_query += " WHERE #{domain_sql}"
        end
      end

      Log.debug { "GET DATA QUERY #{sql_query}" }

      db.query sql_query do |rs|
        rs.each do
          row = Sqlsync::Table::Row.new

          @table.columns.each do |column_desc|
            case column_desc.column_type
            when Sqlsync::Table::Descriptor::Column::Type::Integer32.class
              val = rs.read(Int32?)
              if val.nil?
                row[column_desc.name] = nil
              else
                row[column_desc.name] = val.to_i64
              end
            when Sqlsync::Table::Descriptor::Column::Type::Integer.class
              row[column_desc.name] = rs.read(Int64?)
            when Sqlsync::Table::Descriptor::Column::Type::String.class
              row[column_desc.name] = rs.read(String?)
            else
              raise "unknown how to parse result #{column_desc.name} #{column_desc.column_type}"
            end
          end

          data.add_row row
        end
      end
    end

    data
  end
end

class Sqlsync::Driver::Factory < Sqlsync::Data
  def self.build_driver(driver : String, url : String, table : Table)
    case driver
    when "sqlite3"
      Driver::Sqlite3.new(table, url)
    when "postgres"
      Driver::Postgres.new(table, url)
    when "fsocket"
      connector = Driver::FsocketFreeswitchFactory.new
      Driver::Fsocket.new(table, url, connector)
    else
      raise "unknown driver"
    end
  end

  def self.build_quoter(driver : String)
    case driver
    when "sqlite3"
      Driver::Sqlite3::Quoter.new
    when "postgres"
      Driver::Postgres::Quoter.new
    else
      raise "unknown quoter"
    end
  end
end

require "./drivers/sqlite3"
require "./drivers/postgres"
require "./drivers/fsocket"
