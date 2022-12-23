# @author (2021) Jovany Leandro G.C <jovany@picallex.com>

require "./spec_helper"

class FakeFsocketFactory < Sqlsync::Driver::Fsocket::FsocketFactory
  def create(host : String, port : Int32, password : String)
    FakeFsocketConnection.new
  end
end

class FakeFsocketConnection < Sqlsync::Driver::Fsocket::FsocketConnection
  def json(table : String) : String
    case table
    when "calls"
      %({"row_count":1,"rows":[{"uuid":"ed2370f7-49e1-4d82-b425-f99e58d2dbb4","direction":"inbound","created":"2021-12-21 22:15:25","created_epoch":"1640124925","name":"sofia/cloudpbxdev.picallex.com/1003@cloudpbxclient1.picallex.com","state":"CS_EXECUTE","cid_name":"1003","cid_num":"1003","ip_addr":"181.49.102.14","dest":"573165387562","presence_id":"1003@cloudpbxclient1.picallex.com","presence_data":"","accountcode":"","callstate":"ACTIVE","callee_name":"","callee_num":"","callee_direction":"","call_uuid":"ed2370f7-49e1-4d82-b425-f99e58d2dbb4","hostname":"ip-10-81-83-94.us-east-2.compute.internal","sent_callee_name":"","sent_callee_num":"","b_uuid":"b7d2160d-6441-4469-b610-d9b962ef0d4d","b_direction":"outbound","b_created":"2021-12-21 22:15:27","b_created_epoch":"1640124927","b_name":"sofia/cloudpbxdev.picallex.com/573165387562","b_state":"CS_EXCHANGE_MEDIA","b_cid_name":"Vip2phone Pruebas","b_cid_num":"17863057605","b_ip_addr":"181.49.102.14","b_dest":"573165387562","b_presence_id":"","b_presence_data":"","b_accountcode":"","b_callstate":"ACTIVE","b_callee_name":"Outbound Call","b_callee_num":"573165387562","b_callee_direction":"","b_sent_callee_name":"","b_sent_callee_num":"","call_created_epoch":"1640124935"}]})
    when "channels"
      %({"row_count":2,"rows":[{"uuid":"9d1589aa-64a5-438b-b4fb-8d336efe9032","direction":"inbound","created":"2021-12-21 22:14:56","created_epoch":"1640124896","name":"sofia/cloudpbxdev.picallex.com/1003@cloudpbxclient1.picallex.com","state":"CS_EXECUTE","cid_name":"1003","cid_num":"1003","ip_addr":"181.49.102.14","dest":"573165387562","application":"bridge","application_data":"{bridge_early_media=false,effective_caller_id_number=573165387562,effective_caller_id_name=573165387562,ignore_display_updates=true,origination_caller_id_number=17863057605,origination_caller_id_name=Vip2phone Pruebas}[]sofia/gateway/Telinta/573165387562|error/NO_ROUTE_DESTINATION","dialplan":"XML","context":"cloudpbxclient1.picallex.com","read_codec":"L16","read_rate":"8000","read_bit_rate":"128000","write_codec":"PCMA","write_rate":"8000","write_bit_rate":"64000","secure":"","hostname":"ip-10-81-83-94.us-east-2.compute.internal","presence_id":"1003@cloudpbxclient1.picallex.com","presence_data":"","accountcode":"","callstate":"EARLY","callee_name":"","callee_num":"","callee_direction":"","call_uuid":"","sent_callee_name":"","sent_callee_num":"","initial_cid_name":"1003","initial_cid_num":"1003","initial_ip_addr":"181.49.102.14","initial_dest":"573165387562","initial_dialplan":"XML","initial_context":"cloudpbxclient1.picallex.com"},{"uuid":"e4b21ae1-56c1-49a2-bc83-050da2b5a8d4","direction":"outbound","created":"2021-12-21 22:14:59","created_epoch":"1640124899","name":"sofia/cloudpbxdev.picallex.com/573165387562","state":"CS_CONSUME_MEDIA","cid_name":"Vip2phone Pruebas","cid_num":"17863057605","ip_addr":"181.49.102.14","dest":"573165387562","application":"","application_data":"","dialplan":"XML","context":"cloudpbxclient1.picallex.com","read_codec":"","read_rate":"","read_bit_rate":"","write_codec":"","write_rate":"","write_bit_rate":"","secure":"","hostname":"ip-10-81-83-94.us-east-2.compute.internal","presence_id":"","presence_data":"","accountcode":"","callstate":"DOWN","callee_name":"Outbound Call","callee_num":"573165387562","callee_direction":"","call_uuid":"9d1589aa-64a5-438b-b4fb-8d336efe9032","sent_callee_name":"","sent_callee_num":"","initial_cid_name":"Vip2phone Pruebas","initial_cid_num":"17863057605","initial_ip_addr":"181.49.102.14","initial_dest":"573165387562","initial_dialplan":"XML","initial_context":"cloudpbxclient1.picallex.com"}]})
    else
      ""
    end
  end
end

describe Sqlsync::Driver::Fsocket do
  it "unmarshal calls as json" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "calls"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["call_uuid", "hostname"])
      desc.add_column "call_uuid", "string"
      desc.add_column "hostname", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["call_uuid", "hostname"])
      desc.add_column "call_uuid", "string"
      desc.add_column "hostname", "string"
    end
    destination_data = Sqlsync::Data.new(dest)

    driver = Sqlsync::Driver::Fsocket.new(source, "fsocket://user:pass@localhost:8021", FakeFsocketFactory.new)

    quoter = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(driver.get_data(nil), destination_data)
    diff.tosql(quoter).join(";").should eq(%[INSERT INTO "destino" ("call_uuid","hostname") VALUES ('ed2370f7-49e1-4d82-b425-f99e58d2dbb4', 'ip-10-81-83-94.us-east-2.compute.internal')])
  end

  it "unmarshal channels as json" do
    source = Sqlsync::Table.new do |desc|
      desc.table_name = "channels"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["uuid", "hostname"])
      desc.add_column "uuid", "string"
      desc.add_column "hostname", "string"
    end

    dest = Sqlsync::Table.new do |desc|
      desc.table_name = "destino"
      desc.identifier = Sqlsync::Table::Descriptor::IdentifierMultiColumnPrimaryKey.new(["uuid", "hostname"])
      desc.add_column "uuid", "string"
      desc.add_column "hostname", "string"
    end
    destination_data = Sqlsync::Data.new(dest)

    driver = Sqlsync::Driver::Fsocket.new(source, "fsocket://user:pass@localhost:8021", FakeFsocketFactory.new)

    quoter = Sqlsync::Driver::Postgres::Quoter.new
    diff = Sqlsync.diff(driver.get_data(nil), destination_data)
    diff.tosql(quoter).join(";").should eq(%[INSERT INTO "destino" ("uuid","hostname") VALUES ('9d1589aa-64a5-438b-b4fb-8d336efe9032', 'ip-10-81-83-94.us-east-2.compute.internal'),('e4b21ae1-56c1-49a2-bc83-050da2b5a8d4', 'ip-10-81-83-94.us-east-2.compute.internal')])
  end
end
