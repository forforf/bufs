#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require Bufs.glue 'sdb_s3_glue_env'

describe SdbS3Env::GlueEnv, "Initialization" do
  
  before(:each) do
    env = {:host => nil, :path => 'test_domain', :user_id => 'init_test_user'}
    @persist_env = {:env => env}
    key_fields = {:required_keys => [:id],
                         :primary_key => :id }
    @data_model_bindings = {:key_fields => key_fields, :views => nil}
  end
  
  it "should initialize properly" do
    sdb_glue_obj = SdbS3Env::GlueEnv.new(@persist_env, @data_model_bindings)
    sdb_glue_obj.user_id.should == @persist_env[:env][:user_id]
    sdb_glue_obj.required_instance_keys.should == @data_model_bindings[:key_fields][:required_keys]
    sdb_glue_obj.required_save_keys.should == @data_model_bindings[:key_fields][:required_keys]
    sdb_glue_obj.node_key.should == @data_model_bindings[:key_fields][:primary_key]
    sdb_glue_obj.metadata_keys.should == [sdb_glue_obj.version_key, 
                                                            sdb_glue_obj.model_key,
                                                            sdb_glue_obj.namespace_key]
    path = @persist_env[:env][:path]
    sdb_glue_obj.user_datastore_location.should == "#{path}__#{sdb_glue_obj.user_id}"
    sdb_glue_obj._files_mgr_class.class.should_not == nil  #temp test
    sdb_glue_obj.views.should_not == nil #temp test
    sdb_glue_obj.moab_data.should_not == nil #temp test
  end  
end


describe SdbS3Env::GlueEnv, "Persistent Layer Operations" do
  
  before(:each) do
    env = {:host => nil, :path => 'test_domain', :user_id => 'init_test_user'}
    @persist_env = {:env => env}
    key_fields = {:required_keys => [:id],
                         :primary_key => :id }
    @data_model_bindings = {:key_fields => key_fields, :views => nil}
    @sdb_glue_obj = SdbS3Env::GlueEnv.new(@persist_env, @data_model_bindings)
  end
  
  after(:each) do
    domain = @sdb_glue_obj.model_save_params[:domain]
    sdb = @sdb_glue_obj.model_save_params[:sdb]
    sdb.delete_domain(domain)
  end
  
  it "should persist data and be able to retrieve it" do
    #:id was defined as the primary key
    data1 = {:id => "test_id1", :data => "test data"}
    empty_data = @sdb_glue_obj.get(data1[:id]) #hasn't been saved yet
    empty_data.should == {}
    @sdb_glue_obj.save(data1)
    #Don't use native get_attributes, use obj's get,  it will block until save is finished
    persisted_data = @sdb_glue_obj.get(data1[:id]) 
    persisted_data.should_not == nil
    persisted_data.should == data1
  end
end

