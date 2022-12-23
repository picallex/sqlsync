# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

require "uri"

class Sqlsync::Driver::Sqlite3 < Sqlsync::Driver::CrystalDB
  class Quoter < Sqlsync::Quoter
  end

  def initialize(@table : Table, @db_url : String)
    super(@table, @db_url)

    url = URI.parse(@db_url)
    filepath = url.path || nil
    if filepath.nil?
      raise Sqlsync::Driver::Error.new("sqlite3 invalid host")
    end

    if !File.exists?(filepath) && filepath != ":memory:"
      raise Sqlsync::Driver::Error.new("sqlite3 not file exists #{filepath}")
    end
  end

  def quoter
    Sqlsync::Driver::Sqlite3::Quoter.new
  end
end
