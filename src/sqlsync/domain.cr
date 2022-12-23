# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

require "json"

# A minimal implementation of https://docs.tryton.org/projects/server/en/latest/topics/domain.html
class Sqlsync::Domain
  class Error < Exception
  end

  class Condition
    getter :column
    getter :operator
    getter :value

    def initialize(@column : String, @operator : String, @value : Sqlsync::Table::ColumnContent)
    end

    def to_sql(quoter : Sqlsync::Quoter) : String
      "#{quoter.quote_column_name(column)} #{operator} #{quoter.quote_column_value(@value)}"
    end
  end

  def initialize
    @conditions = [] of Condition
  end

  def self.from_json(json : JSON::Any)
    main_arr = json.as_a
    raise Error.new("expected main array") if main_arr.nil?

    domain = self.new

    main_arr.each do |expr_json|
      expr = expr_json.as_a
      raise Error.new("expression must be [column, operator, value]") if expr.size != 3

      field_any, op_any, value_any = expr

      field = field_any.as_s?
      op = op_any.as_s?
      raise Error.new("column #{field} not a string") if field.nil?
      raise Error.new("operator #{op} not a string") if op.nil?

      raise Error.new("unknown operator #{op}") unless {"=": true}.has_key?(op)

      value : String | Int64 | Nil = nil
      if !value_any.as_i?.nil?
        value = value_any.as_i.to_i64
      elsif !value_any.as_i64?.nil?
        value = value_any.as_i64
      elsif !value_any.as_s?.nil?
        # se permite obtener informacion del sistema en el campo
        value = Sqlsync::Value.eval(value_any.as_s)
      else
        raise Error.new("failed to cast value of column #{field}")
      end

      domain.add_condition(Condition.new(field, op, value))
    end

    domain
  end

  protected def add_condition(condition : Condition)
    @conditions << condition
  end

  def to_sql(quoter : Sqlsync::Quoter)
    @conditions.map { |cond| cond.to_sql(quoter) }.join(" AND ")
  end
end
