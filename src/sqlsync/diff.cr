# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

class Sqlsync::Diff
  def initialize(@src : Data, @dest : Data)
  end

  # genera plan SQL a ejecutar
  def tosql(quoter : Sqlsync::Quoter, domain : Sqlsync::Domain? = nil) : Array(String)
    rs = [] of String

    sqls = [
      update_sql(quoter, domain),
      insert_sql(quoter),
      delete_sql(quoter, domain),
    ].flatten

    sqls.each do |sql|
      next if sql.nil?
      rs << sql
    end

    rs
  end

  private def delete_sql(quoter : Sqlsync::Quoter, domain : Sqlsync::Domain? = nil)
    rows = @src.rows_to_delete(@dest)
    return nil if rows.empty?

    String::Builder.build do |str|
      str << "DELETE FROM #{quoter.quote_table_name(@dest.table_name)}"
      str << " WHERE "

      values = [] of String
      values_by_field = Hash(String, Array(Sqlsync::Table::ColumnContent)).new
      rows.each do |row|
        @dest.identifier_row(row).each do |column_name, column_value|
          if !values_by_field.has_key?(column_name)
            values_by_field[column_name] = [] of Sqlsync::Table::ColumnContent
          end
          values_by_field[column_name] << column_value
        end
      end
      values_by_field.each do |column_name, column_values|
        if column_values.size > 1
          column_values_sql = column_values.map { |v| quoter.quote_column_value(v) }.join(",")
          values << "#{quoter.quote_column_name(column_name)} IN (#{column_values_sql})"
        else
          values << "#{quoter.quote_column_name(column_name)} = #{quoter.quote_column_value(column_values.first)}"
        end
      end
      str << values.join(" AND ")

      # add domain
      unless domain.nil?
        domain_sql = domain.to_sql(quoter)
        if domain_sql != ""
          str << " AND "
          str << domain_sql
        end
      end
    end
  end

  private def insert_sql(quoter : Sqlsync::Quoter)
    rows = @src.rows_to_insert(@dest)
    return nil if rows.empty?

    String::Builder.build do |str|
      str << "INSERT INTO #{quoter.quote_table_name(@dest.table_name)}"
      column_names = @dest.column_names.map { |name| quoter.quote_column_name(name) }
      str << " ("
      str << column_names.join(",")
      str << ")"
      str << " VALUES "

      values_sql = [] of String
      rows.each do |row|
        values_sql << String::Builder.build do |str|
          str << "("
          values = [] of String
          @dest.column_names.each do |column_name|
            values << quoter.quote_column_value(row[column_name])
          end
          str << values.join(", ")
          str << ")"
        end
      end
      str << values_sql.join(",")
    end
  end

  private def update_sql(quoter : Sqlsync::Quoter, domain : Sqlsync::Domain? = nil)
    rows = @src.rows_to_update(@dest)
    return nil if rows.empty?

    rows.map do |row|
      String::Builder.build do |str|
        str << "UPDATE"
        str << " #{quoter.quote_table_name(@dest.table_name)}"
        str << " SET "

        values = [] of String
        # actualizar solo las columnas indicadas por el destino
        @dest.column_names.each do |column_name|
          column_value = row[column_name]
          values << "#{quoter.quote_column_name(column_name)} = #{quoter.quote_column_value(column_value)}"
        end
        str << values.join(", ")

        str << " WHERE "
        values = [] of String

        @dest.identifier_row(row).each do |column_name, column_value|
          values << "#{quoter.quote_column_name(column_name)} = #{quoter.quote_column_value(column_value)}"
        end

        str << values.join(" AND ")

        # add domain
        unless domain.nil?
          domain_sql = domain.to_sql(quoter)
          if domain_sql != ""
            str << " AND "
            str << domain_sql
          end
        end
      end
    end
  end
end
