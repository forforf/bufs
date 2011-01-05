#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require Bufs.glue 'bufs_couchrest_glue_env'

GlueTestDb = CouchRest.database!("http://127.0.0.1:5984/couchrest_glue_test")
GlueTestDb.compact!

describe BufsCouchrestEnv::GlueEnv, "Initialization" do
  before(:each) do
    #set up env
    persist_env = { :host => GlueTestDb.host,
                          :path => GlueTestDb.uri,
                          :user_id => 'couch_glue_user'}
    

    @persist_env = {:name => :couchrest_glue_spec, :env => persist_env}
    
    key_fields = { :required_keys => [:my_id],
                        :primary_key => :my_id }
    
    @data_model_bindings =  { :key_fields => key_fields,
                                          :views => nil }
    
  end
  
  after(:each) do
    GlueTestDb.delete!
  end
  
  it "should initialize properly" do
    couchrest_glue_obj = BufsCouchrestEnv::GlueEnv.new(@persist_env, @data_model_bindings)
    #@data_dir = couchrest_glue_obj.user_datastore_location
    
    #couchrest_glue_obj.dbh.connected?.should == true
    
    couchrest_glue_obj.user_id.should == @persist_env[:env][:user_id]
    couchrest_glue_obj.required_instance_keys.should == @data_model_bindings[:key_fields][:required_keys]
    couchrest_glue_obj.required_save_keys.should == @data_model_bindings[:key_fields][:required_keys]
    couchrest_glue_obj.node_key.should == @data_model_bindings[:key_fields][:primary_key]
    required_metadata_keys = [couchrest_glue_obj.version_key, 
                                        couchrest_glue_obj.model_key,
                                        couchrest_glue_obj.namespace_key]
    (couchrest_glue_obj.metadata_keys & required_metadata_keys).sort.should == required_metadata_keys.sort
    path = @persist_env[:env][:path]
    user_id = @persist_env[:env][:user_id]
    #p GlueTestDb.to_s
    couchrest_glue_obj.user_datastore_location.should == user_id #?
    couchrest_glue_obj._files_mgr_class.class.should_not == nil    #The file manager class will handle file attachments
  end  
  
end


describe BufsCouchrestEnv::GlueEnv, "Persistent Layer Basic Operations" do
  
  before(:each) do
    #set up env
    persist_env = { :host => GlueTestDb.host,
                          :path => GlueTestDb.uri,
                          :user_id => 'couch_glue_user'}
    
    #name isn't used in these specs, since that's used by the node factory to select the glue env
    #but shown for clarity
    @persist_env = {:name => :couchrest_glue_test, :env => persist_env}
    
    key_fields = { :required_keys => [:my_id],
                        :primary_key => :my_id }
    
    @data_model_bindings =  { :key_fields => key_fields,
                                          :views => nil }
    
    @couchrest_glue_obj = BufsCouchrestEnv::GlueEnv.new(@persist_env, @data_model_bindings)
  end
  
  after(:each) do
    GlueTestDb.delete!
  end
  
  it "should persist data and be able to retrieve it" do
    @couchrest_glue_obj.should_not == nil
    #:id was defined as the primary key
    data1 = {:my_id => "test_id1", :data => "test data"}
    empty_data = @couchrest_glue_obj.get(data1[:my_id]) #hasn't been saved yet
    empty_data.should == nil
    @couchrest_glue_obj.save(data1)
    #Don't use native get_attributes, use obj's get,  it will block until save is finished
    persisted_data = @couchrest_glue_obj.get(data1[:my_id]) 
    persisted_data.should_not == nil
    #puts "Persisted data for my_id: #{persisted_data}"
    persisted_data[:my_id].should == data1[:my_id]
    persisted_data[:data].should == data1[:data]
  end

  it "should be able to delete data" do
    data1 = {:my_id => "test_id1", :data => "test data1"}
    data2 = {:my_id => "test_id2", :data => "test data2"}
    @couchrest_glue_obj.save(data1)
    @couchrest_glue_obj.save(data2)
    persisted_data1 = @couchrest_glue_obj.get(data1[:my_id])
    persisted_data2 = @couchrest_glue_obj.get(data2[:my_id])
    persisted_data1[:data].should == "test data1"
    persisted_data2[:data].should == "test data2"
    @couchrest_glue_obj.destroy_node({:my_id => data2[:my_id]})
    persisted_data1 = @couchrest_glue_obj.get(data1[:my_id])
    persisted_data2 = @couchrest_glue_obj.get(data2[:my_id])
    persisted_data1[:data].should == "test data1"
    persisted_data2.should == nil    
  end
end


describe BufsCouchrestEnv::GlueEnv, "Persistent Layer Collection Operations" do

  before(:each) do
    #set up env
    persist_env = { :host => GlueTestDb.host,
                          :path => GlueTestDb.uri,
                          :user_id => 'couch_glue_user'}
    
    #name isn't used in these specs, since that's used by the node factory to select the glue env
    #but shown for clarity
    @persist_env = {:name => :couchrest_glue_test, :env => persist_env}
    
    key_fields = { :required_keys => [:my_id],
                        :primary_key => :my_id }
    
    @data_model_bindings =  { :key_fields => key_fields,
                                          :views => nil }
    
    @couchrest_glue_obj = BufsCouchrestEnv::GlueEnv.new(@persist_env, @data_model_bindings)
  end
  
  after(:each) do
    #GlueTestDb.delete!
  end

  it "should be able to query all" do
    data1 = {:my_id => "test_id1", :data => "test data1"}
    data2 = {:my_id => "test_id2", :data => "test data2"}
    @couchrest_glue_obj.save(data1)
    @couchrest_glue_obj.save(data2)
  
    results = @couchrest_glue_obj.query_all
    results.size.should == 2
    results.each do |raw_data|
      case raw_data[:my_id]
        when "test_id1"
          raw_data[:data].should == "test data1"
        when "test_id2"
          raw_data[:data].should == "test data2"  
        else
          raise "Unknown dataset #{raw_data.inspect}"
      end#case
    end#each
  end

  it "should be able to find matching data" do
    data1 = {:my_id => "test_id1", :data => "test data1", :tags => ['a', 'b', 'c']}
    data2 = {:my_id => "test_id2", :data => "test data2", :tags => ['c', 'd', 'e']}
    data3 = {:my_id => "test_id3", :data => "test data2", :tags => ['c', 'b', 'z']}
    data_list = [data1, data2, data3]
    data_list.each {|data| @couchrest_glue_obj.save(data)}
    
    result1 = @couchrest_glue_obj.find_nodes_where(:my_id, :equals, "test_id1")
    result1.size.should == 1
    result1.first[:my_id].should == "test_id1"
    
    result2 = @couchrest_glue_obj.find_nodes_where(:my_id, :equals, "oops")
    result2.should be_empty
    
    result3 = @couchrest_glue_obj.find_nodes_where(:data, :equals, "test data2")
    result3.size.should == 2
    ["test_id2", "test_id3"].should include result3.first[:my_id]
    ["test_id2", "test_id3"].should include result3.last[:my_id]
    
    result4 = @couchrest_glue_obj.find_nodes_where(:tags, :equals, ['c', 'd', 'e'])
    result4.size.should == 1
    result4.first[:my_id].should == "test_id2"    
  end

  it "should be able to find containting data" do
    data1 = {:my_id => "test_id1", :data => "test data1", :tags => ['a', 'b', 'c']}
    data2 = {:my_id => "test_id2", :data => "test data2", :tags => ['c', 'd', 'e']}
    data3 = {:my_id => "test_id3", :data => "test data2", :tags => ['c', 'b', 'z']}
    data_list = [data1, data2, data3]
    data_list.each {|data| @couchrest_glue_obj.save(data)}
    
    result1 = @couchrest_glue_obj.find_nodes_where(:my_id, :contains, "test_id2")
    result1.size.should == 1
    result1.first[:my_id].should == "test_id2"
    
    result2 = @couchrest_glue_obj.find_nodes_where(:tags, :contains, "c")
    result2.size.should == 3
    
    result3 = @couchrest_glue_obj.find_nodes_where(:tags, :contains, "b")
    result3.size.should == 2
    ["test_id1", "test_id3"].should include result3.first[:my_id]
    ["test_id1", "test_id3"].should include result3.last[:my_id]
    
    result4 = @couchrest_glue_obj.find_nodes_where(:tags, :contains, "oops")
    result4.should be_empty
  end

  it "should be able to delete in bulk" do  
    data1 = {:my_id => "test_id1", :data => "delete me"}
    data2 = {:my_id => "test_id2", :data => "keep me"}
    data3 = {:my_id => "test_id3", :data => "delete me too"}
    @couchrest_glue_obj.save(data1)
    @couchrest_glue_obj.save(data2)
    @couchrest_glue_obj.save(data3)
    
    results = @couchrest_glue_obj.query_all

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
    @couchrest_glue_obj.destroy_bulk(raw_rcds_to_delete)
    
    results = @couchrest_glue_obj.query_all
    #puts "Destroy Bulk results: #{results.inspect}"
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
