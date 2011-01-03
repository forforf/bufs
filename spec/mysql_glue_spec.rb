#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require Bufs.glue 'mysql_glue_env'



describe MysqlEnv::GlueEnv, "Initialization" do
  
  before(:each) do
    #host is the database
    env = {:host => nil, :path => 'test_domain', :user_id => 'init_test_user'}
    @persist_env = {:env => env}
    key_fields = {:required_keys => [:my_id],
                         :primary_key => :my_id }
    @data_model_bindings = {:key_fields => key_fields, :views => nil}
  end
  
  it "should initialize properly" do
    mysql_glue_obj = MysqlEnv::GlueEnv.new(@persist_env, @data_model_bindings)
    mysql_glue_obj.dbh.connected?.should == true
    
    mysql_glue_obj.user_id.should == @persist_env[:env][:user_id]
    mysql_glue_obj.required_instance_keys.should == @data_model_bindings[:key_fields][:required_keys]
    mysql_glue_obj.required_save_keys.should == @data_model_bindings[:key_fields][:required_keys]
    mysql_glue_obj.node_key.should == @data_model_bindings[:key_fields][:primary_key]
    mysql_glue_obj.metadata_keys.should == [mysql_glue_obj.version_key, 
                                                            mysql_glue_obj.model_key,
                                                            mysql_glue_obj.namespace_key]
    path = @persist_env[:env][:path]
    mysql_glue_obj.user_datastore_location.should == "#{path}__#{mysql_glue_obj.user_id}"
    mysql_glue_obj._files_mgr_class.class.should_not == nil  #temp test
    #sdb_glue_obj.views.should_not == nil #temp test
    #sdb_glue_obj.moab_data.should_not == nil #temp test
  end  
end

describe MysqlEnv::GlueEnv, "Persistent Layer Basic Operations" do
  
  before(:each) do
    env = {:host => nil, :path => 'test_domain', :user_id => 'init_test_user'}
    @persist_env = {:env => env}
    key_fields = {:required_keys => [:my_id],
                         :primary_key => :my_id }
    @data_model_bindings = {:key_fields => key_fields, :views => nil}
    @mysql_glue_obj = MysqlEnv::GlueEnv.new(@persist_env, @data_model_bindings)
  end
  
  after(:each) do
    table = @mysql_glue_obj.model_save_params[:table]
    dbh = @mysql_glue_obj.model_save_params[:dbh]
    sql = "DROP TABLE `#{table}`"
    dbh.do(sql)
  end
  
  it "should persist data and be able to retrieve it" do
    @mysql_glue_obj.should_not == nil
    #:id was defined as the primary key
    data1 = {:my_id => "test_id1", :data => "test data"}
    empty_data = @mysql_glue_obj.get(data1[:my_id]) #hasn't been saved yet
    empty_data.should == {}
    @mysql_glue_obj.save(data1)
    #Don't use native get_attributes, use obj's get,  it will block until save is finished
    persisted_data = @mysql_glue_obj.get(data1[:my_id]) 
    persisted_data.should_not == nil
    p persisted_data
    persisted_data[:my_id].should == data1[:my_id]
    persisted_data[:data].should == data1[:data]
  end
 
  it "should be able to delete data" do
    data1 = {:my_id => "test_id1", :data => "test data1"}
    data2 = {:my_id => "test_id2", :data => "test data2"}
    @mysql_glue_obj.save(data1)
    @mysql_glue_obj.save(data2)
    persisted_data1 = @mysql_glue_obj.get(data1[:my_id])
    persisted_data2 = @mysql_glue_obj.get(data2[:my_id])
    persisted_data1[:data].should == "test data1"
    persisted_data2[:data].should == "test data2"
    @mysql_glue_obj.destroy_node({:my_id => data2[:my_id]})
    persisted_data1 = @mysql_glue_obj.get(data1[:my_id])
    persisted_data2 = @mysql_glue_obj.get(data2[:my_id])
    persisted_data1[:data].should == "test data1"
    persisted_data2.should == {}    
  end
end
  
describe MysqlEnv::GlueEnv, "Persistent Layer Collection Operations" do

  before(:each) do
    env = {:host => nil, :path => 'test_domain', :user_id => 'init_test_user'}
    @persist_env = {:env => env}
    key_fields = {:required_keys => [:my_id],
                         :primary_key => :my_id }
    @data_model_bindings = {:key_fields => key_fields, :views => nil}
    @mysql_glue_obj = MysqlEnv::GlueEnv.new(@persist_env, @data_model_bindings)
  end
  
  after(:each) do
    table = @mysql_glue_obj.model_save_params[:table]
    dbh = @mysql_glue_obj.model_save_params[:dbh]
    sql = "DROP TABLE `#{table}`"
    dbh.do(sql)
  end
  
  it "should be able to query all" do
    data1 = {:my_id => "test_id1", :data => "test data1"}
    data2 = {:my_id => "test_id2", :data => "test data2"}
    @mysql_glue_obj.save(data1)
    @mysql_glue_obj.save(data2)
  
    results = @mysql_glue_obj.query_all
    #results.should == 'blah'
    results.each do |raw_data|
      case raw_data[:my_id]
        when "test_id1"
          raw_data[:data].should == "test data1"
        when "test_id2"
          raw_data[:data].should == "test data2"
        else
          raise "Unknown dataset"
      end#case
    end#each
  end

  it "should be able to delete in bulk" do  
    data1 = {:my_id => "test_id1", :data => "delete me"}
    data2 = {:my_id => "test_id2", :data => "keep me"}
    data3 = {:my_id => "test_id3", :data => "delete me too"}
    @mysql_glue_obj.save(data1)
    @mysql_glue_obj.save(data2)
    @mysql_glue_obj.save(data3)
    
    results = @mysql_glue_obj.query_all
    results.each do |raw_data|
      case raw_data[:my_id]
        when "test_id1"
          raw_data[:data].should == "delete me"
        when "test_id2"
          raw_data[:data].should == "keep me"
        when "test_id3"
          raw_data[:data].should == "delete me too"
        else
          raise "Unknown dataset"
      end#case
    end#each
    
    raw_rcds_to_delete = [data1, data3]
    @mysql_glue_obj.destroy_bulk(raw_rcds_to_delete)
    
    results = @mysql_glue_obj.query_all
    puts "Destroy Bulk results: #{results.inspect}"
    results.each do |raw_data|
      case raw_data[:my_id]
        when "test_id1"
          raise "Oops should have been deleted"
        when "test_id2"
          raw_data[:data].should == "keep me"
        when "test_id3"
          raise "Oops should have been deleted"
        else
          raise "Unknown dataset"
      end#case
    end#each    
  end#it
end

