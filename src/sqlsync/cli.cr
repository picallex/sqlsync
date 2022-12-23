# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

require "log"
require "json"
require "option_parser"

require "../sqlsync"

Log.setup_from_env

log = ::Log.for("sqlsync")

%{begin}
VERSION = {{env("VERSION") || "latest"}}
%{end}

json_config_path = "/etc/sqlsync.json"

option_parser = OptionParser.parse do |parser|
  parser.banner = "best sqlsync made in Colombia"

  parser.on "-v", "--version", "version" do
    puts VERSION
    exit 1
  end

  parser.on "-?", "--help", "help" do
    puts parser
    exit 1
  end

  parser.on "-c CONFIG", "--config=CONFIG", "JSON CONFIG FILE" do |path|
    json_config_path = path
  end
end

class Config
  include JSON::Serializable

  class Table
    alias Domain = Array(String | Int64 | Nil | Domain)

    include JSON::Serializable

    property db_driver : String
    property db_url : String
    property table_name : String
    property domain : JSON::Any
    property identifier_columns : Array(String)
    property mapping : Hash(String, String)?
    property columns : Hash(String, String)
  end

  class ConfigSqlsync
    include JSON::Serializable

    property active : Bool = true
    property debug : Bool = true

    property source : Table
    property destination : Table
  end

  property tick : Int64 = 1
  property draft : Bool = false
  property sqlsync : Hash(String, ConfigSqlsync)
  property env_from_aws_secretsmanager_id : String? = nil

  def self.value_or_environment(val : String)
    Sqlsync::Value.eval(val)
  end

  def load_env
    # pobla ENV desde aws secretsmanager
    return if @env_from_aws_secretsmanager_id.nil?
    return if @env_from_aws_secretsmanager_id == ""

    aws_cmd = Process.find_executable("aws")
    if aws_cmd.nil?
      raise "failed to find aws executable"
    end

    outcmd = %x|#{aws_cmd} secretsmanager get-secret-value --secret-id #{@env_from_aws_secretsmanager_id}|
    raise "fail aws" unless $?.success?

    Log.debug { "loading environment from secretsmanager id #{@env_from_aws_secretsmanager_id}" }
    resp = JSON.parse(outcmd).as_h
    secret_string_str = resp["SecretString"].as_s
    secret_string = JSON.parse(secret_string_str).as_h

    secret_string.each do |key, value|
      Log.debug { "loading environment #{key}" }
      ENV[key] = value.as_s
    end
  end
end

json_config_content = File.read(json_config_path)
config = Config.from_json(json_config_content)
config.load_env

syncs = [] of String
sources_table = Hash(String, Sqlsync::Table).new
destinations_table = Hash(String, Sqlsync::Table).new
sources_driver = Hash(String, Sqlsync::Driverer).new
destinations_driver = Hash(String, Sqlsync::Driverer).new
destinations_quoter = Hash(String, Sqlsync::Quoter).new
configs = Hash(String, Config::ConfigSqlsync).new
sources_domain = Hash(String, Sqlsync::Domain).new
destinations_domain = Hash(String, Sqlsync::Domain).new

config.sqlsync.each do |sync_name, config|
  # omitir desactivados
  next if !config.active

  # almacenar clave de sincronizacion
  syncs << sync_name

  configs[sync_name] = config

  sources_table[sync_name] = Sqlsync::Table.new do |desc|
    desc.table_name = config.source.table_name
    desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(config.source.identifier_columns)
    config.source.columns.each do |name, kind|
      desc.add_column name, kind
    end
  end

  destinations_table[sync_name] = Sqlsync::Table.new do |desc|
    desc.table_name = config.destination.table_name
    desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(config.destination.identifier_columns)
    config.destination.columns.each do |name, kind|
      desc.add_column name, kind
    end

    destination_mapping = config.destination.mapping || Hash(String, String).new
    destination_mapping.each do |from_column, to_column|
      Log.info { "#{sync_name}: detected mapping table #{desc.table_name} from #{from_column} to #{to_column}" }
      desc.add_mapping from_column, to_column
    end
  end

  sources_domain[sync_name] = Sqlsync::Domain.from_json(config.source.domain)
  destinations_domain[sync_name] = Sqlsync::Domain.from_json(config.destination.domain)
  sources_driver[sync_name] = Sqlsync::Driver::Factory.build_driver(config.source.db_driver, Config.value_or_environment(config.source.db_url), sources_table[sync_name])
  destinations_driver[sync_name] = Sqlsync::Driver::Factory.build_driver(config.destination.db_driver, Config.value_or_environment(config.destination.db_url), destinations_table[sync_name])
  destinations_quoter[sync_name] = Sqlsync::Driver::Factory.build_quoter(config.destination.db_driver)
end

done = Channel(Nil).new

syncs.each do |sync_name|
  log.info { "STARTED SYNC FOR #{sync_name}" }

  # thread by table
  spawn do
    loop do
      source_driver = sources_driver[sync_name]
      destination_driver = destinations_driver[sync_name]
      destination_quoter = destinations_quoter[sync_name]

      log.debug { "#{sync_name}: TICK #{config.tick} SECONDS" }

      diff = Sqlsync.diff(source_driver.get_data(sources_domain[sync_name]), destination_driver.get_data(destinations_domain[sync_name]))

      plan_sql = diff.tosql(destination_quoter, destinations_domain[sync_name])

      if configs[sync_name].debug
        log.debug { "#{sync_name}: PLAN SQL ->" }
        plan_sql.each do |sql|
          log.debug { "#{sync_name}: #{sql}" }
        end
        log.debug { "#{sync_name}: END" }
      end

      if !config.draft
        destination_driver.execute(plan_sql)
      end

      sleep config.tick.second
    end
  rescue e
    puts(e.inspect_with_backtrace)
    exit 1
  end
end

Signal::INT.trap do
  sources_driver.each do |driver_name, driver|
    driver.close
    STDERR.puts "#{driver_name}: source closed"
  end

  destinations_driver.each do |driver_name, driver|
    driver.close
    STDERR.puts "#{driver_name}: destination closed"
  end

  exit(1)
end

done.receive
