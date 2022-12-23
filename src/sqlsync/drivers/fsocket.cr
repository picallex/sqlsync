# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

require "uri"
require "freeswitch-esl"
require "log"
require "json"

# NOTE(bit4bit)
# obtiene informacion del freeswitch usando event socket.
# esto es requerido ya que multiples
# lectores sobre el archivo sqlite genera SQLITE_BUSY en el freeswitch
# afectado el rendimiento de la telefonia.
class Sqlsync::Driver::Fsocket < Sqlsync::Driverer
  class FsocketConnection
    def json(table : String) : String
      raise NotImplementedError.new("json")
    end

    def close
    end
  end

  class FsocketFactory
    def create(host : String, port : Int32, password : String) : FsocketConnection?
      raise NotImplementedError.new("create")
    end
  end

  class CallResult
    include JSON::Serializable
    alias Call = Hash(String, String | Int64)
    alias Calls = Array(Call)

    @[JSON::Field(key: "rows")]
    property rows : Calls?

    @[JSON::Field(key: "row_count")]
    property count : Int64
  end

  @fsconn : FsocketConnection

  def initialize(@table : Table, @db_url : String, @connector : FsocketFactory)
    url = URI.parse(@db_url)

    host = url.host || raise ArgumentError.new("requires host")
    port = url.port || raise ArgumentError.new("requires port")
    password = url.password || raise ArgumentError.new("requires password")

    check_table(@table)

    conn = @connector.create(host, port, password)
    if conn.nil?
      STDERR.puts("failed to connect to freeswitch #{host}:#{port} #{password}")
      exit(1)
    end
    @fsconn = conn
  end

  def execute(sqls : Array(String))
    raise NotImplementedError.new("fsocket execute driver")
  end

  def get_data(domain : Sqlsync::Domain? = nil)
    ::Sqlsync::Data
    data = Sqlsync::Data.new(@table)

    result_json = @fsconn.json(@table.name)
    call_result = CallResult.from_json(result_json)

    call_rows = call_result.rows || [] of CallResult::Call

    call_rows.each do |call|
      row = Sqlsync::Table::Row.new
      Log.debug { "fsocket: GET ROW #{call}" }
      @table.columns.each do |column_desc|
        next if !call.has_key?(column_desc.name)

        case column_desc.column_type
        when Sqlsync::Table::Descriptor::Column::Type::Integer32.class
          row[column_desc.name] = call[column_desc.name].to_i64
        when Sqlsync::Table::Descriptor::Column::Type::String.class
          row[column_desc.name] = call[column_desc.name].as(String)
        else
          raise "unknown how to parse result #{column_desc.name} #{column_desc.column_type}"
        end
      end

      data.add_row row
    end

    data
  end

  def close
    @fsconn.close
  end

  private def check_table(table)
    unless ["calls", "channels", "registrations"].includes?(table.name)
      raise ArgumentError.new("not known how to handle table #{table.name}")
    end
  end
end

class Sqlsync::Driver::FsocketFreeswitch < Sqlsync::Driver::Fsocket::FsocketConnection
  def initialize(host : String, port : Int32, password : String)
    socket = TCPSocket.new(host, port, 3.seconds)
    conn = Freeswitch::ESL::Connection.new(socket, spawn_receiver: false)
    @fsconn = Freeswitch::ESL::Inbound.new(conn, pass: password)

    spawn name: "fsocket event handler" do
      conn.run
    rescue ex
      STDERR.puts(ex.inspect_with_backtrace)
      exit 1
    end
  end

  def connected
    ret = @fsconn.connect(3.seconds)
    if ret
      @fsconn.nolog
      @fsconn.noevents
    end
    ret
  end

  def json(table : String) : String
    @fsconn.api("show", "#{table} as json")
  end

  def close
    @fsconn.exit
  end
end

class Sqlsync::Driver::FsocketFreeswitchFactory < Sqlsync::Driver::Fsocket::FsocketFactory
  def create(host : String, port : Int32, password : String) : Sqlsync::Driver::Fsocket::FsocketConnection?
    conn = Sqlsync::Driver::FsocketFreeswitch.new(host, port, password)
    if conn.connected
      Log.info { "fsocket: connect to freewitch #{host}:#{port} OK" }
      conn
    else
      conn.close
      return nil
    end
  end
end
