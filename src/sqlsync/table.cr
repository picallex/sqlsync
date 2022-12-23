# @author (2021) Jovany Leandro G.C <jovany@picallex.com>
require "log"

class Sqlsync::Table
  alias ColumnContent = Int64 | String | Nil
  alias ColumnValue = Hash(String, ColumnContent)

  class Row < ColumnValue
    def diff(row)
      each
    end
  end

  getter :descriptor

  def initialize
    @descriptor = Descriptor.new
    yield @descriptor
  end

  def name : String
    if @descriptor.table_name.nil?
      raise "unexpected table name"
    end

    @descriptor.table_name.as(String)
  end

  def columns
    @descriptor.columns
  end

  def has_column?(name : String)
    @descriptor.has_column?(name)
  end

  def identifier_row(row : Row)
    @descriptor.identifier.row(row)
  end
end

class Sqlsync::Table::Descriptor
  class Column
    class Typer
    end

    module Type
      class String < Typer
      end

      class Integer < Typer
      end

      class Integer32 < Typer
      end
    end

    getter :name
    getter :column_type

    def initialize(@name : String, @column_type : Typer.class)
    end

    def ==(other)
      @name == other.name && @column_type == other.column_type
    end
  end

  class ColumnCollection
    @columns = Hash(String, Column).new

    def <<(value : Column)
      @columns[value.name] = value
    end

    def map : Array(String)
      rows = [] of String
      @columns.each do |_name, column|
        rows << yield column
      end
      rows
    end

    def each
      @columns.each do |_, column|
        yield column
      end
    end

    def has_column?(name : String)
      @columns.has_key?(name)
    end
  end

  abstract class Identifier
    abstract def same?(from : Table::Row, to : Table::Row) : Bool
  end

  class IdentifierMultiColumnPrimaryKey < Identifier
    def initialize(@column_names = [] of String)
    end

    def row(from : Table::Row) : Table::Row
      row = Table::Row.new

      @column_names.each do |column_name|
        row[column_name] = from[column_name]
      end

      row
    end

    def same?(from : Table::Row, to : Table::Row) : Bool
      @column_names.map do |column_name|
        from[column_name] == to[column_name]
      end.all? { |v| v == true }
    end
  end

  alias ColumnMapping = Hash(String, String)

  getter :columns
  getter :mapping
  property :identifier

  @table_name : String?
  @columns = ColumnCollection.new
  @mapping = ColumnMapping.new
  @identifier : Identifier = IdentifierMultiColumnPrimaryKey.new(["id"])

  def initialize
    @table_name = nil
  end

  def table_name : String
    if @table_name.nil?
      raise "expected table_name"
    end

    @table_name.as(String)
  end

  def table_name=(value)
    @table_name = value
  end

  def add_mapping(from_column : String, to_column : String)
    @mapping[from_column] = to_column
  end

  def add_column(name : String, column_type : String)
    case column_type
    when "int"
      @columns << Column.new(name, Column::Type::Integer)
    when "int32"
      @columns << Column.new(name, Column::Type::Integer32)
    when "string"
      @columns << Column.new(name, Column::Type::String)
    else
      raise "unknown column type"
    end
  end

  def has_column?(name : String)
    @columns.has_column?(name)
  end
end

class Sqlsync::Data
  class DataError < Exception
  end

  class Row
    getter :row

    def initialize(@row : Table::Row, @identifier : Table::Descriptor::Identifier)
    end

    def hash
      map = Table::ColumnValue.new

      @identifier.row(@row).each do |key, value|
        map[key] = value
      end

      map.hash
    end

    def ==(other)
      other.hash == hash
    end
  end

  getter :rows
  @rows = [] of Row

  def initialize(@table : Table)
  end

  def table_name
    @table.name
  end

  def column_names : Array(String)
    @table.columns.map { |c| c.name }
  end

  def to_set
    Set.new @rows
  end

  def to_set_mapped(other : Sqlsync::Data)
    rows = [] of Row

    @rows.each do |row|
      rows << other.mapping(row)
    end

    Set.new rows
  end

  # TODO(bit4bit) se ve claramente que ya esto
  # no es responsabilidad de esta clase,
  # en conjuto con rows_to....
  def mapping(datarow : Row) : Row
    return datarow if datarow.row.empty?
    return datarow if @table.descriptor.mapping.empty?

    mapping_row = Table::Row.new
    mapping_datarow = Data::Row.new(mapping_row, @table.descriptor.identifier)

    @table.descriptor.mapping.each do |from_column, to_column|
      mapping_row[to_column] = datarow.row[from_column]
    end

    mapping_datarow
  end

  def rows_to_delete(other : Sqlsync::Data)
    rows = [] of Table::Row

    other_set = other.to_set
    current_set = to_set_mapped(other)

    to_delete_set = other_set - current_set
    to_delete_set.each do |data_row|
      rows << data_row.row
    end

    rows
  end

  def rows_to_update(other : Sqlsync::Data)
    rows = [] of Table::Row

    other_set = other.to_set
    current_set = to_set_mapped(other)

    same_set = current_set & other_set

    current_set.each do |data_row|
      if same_set.includes?(data_row)
        rows << data_row.row
      end
    end

    rows
  end

  def rows_to_insert(other : Sqlsync::Data)
    rows = [] of Table::Row

    other_set = other.to_set
    current_set = to_set_mapped(other)

    result_set = current_set.subtract(other_set)
    result_set.each do |data_row|
      rows << data_row.row
    end

    rows
  end

  def identifier_row(row : Table::Row) : Table::Row
    @table.identifier_row(row)
  end

  def add_row(row)
    row.each do |key, value|
      raise DataError.new("not found column #{key} in table #{@table}") unless @table.has_column?(key)
    end

    @rows << Row.new(row, @table.descriptor.identifier)
  end
end

class Sqlsync::Quoter
  def quote_table_name(name : String) : String
    "\"#{name.gsub('"', "\\\"")}\""
  end

  def quote_column_name(name : String) : String
    "\"#{name.gsub('"', "\\\"")}\""
  end

  def quote_column_value(val : Table::ColumnContent) : String
    case val.class
    when Nil.class
      "NULL"
    when String.class
      "'#{val.to_s.gsub("'", "\\'")}'"
    when Int32.class
      "#{val}"
    when Int64.class
      "#{val}"
    else
      raise "unknown how to quote type #{val.class}"
    end
  end
end
