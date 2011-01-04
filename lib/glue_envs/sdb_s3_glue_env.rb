#Bufs directory structure defined in lib/helpers/require_helpers'
require Bufs.midas 'bufs_data_structure'
require Bufs.glue '/sdb_s3/sdb_s3_files_mgr'
require Bufs.helpers 'hash_helpers'
require Bufs.helpers 'log_helper'

#require 'right_aws'
require 'aws_sdb'  #published as forforf-aws-sdb
#require 'aws/s3'
require 'json'

module SdbS3Env
class GlueEnv
  
  
  @@log = BufsLog.set(self.name, :info)
   #used to identify metadata for models (should be consistent across models)
  ModelKey = :_id 
  VersionKey = :_rev #to have timestamp
  NamespaceKey = :sdbs3_namespace
  
  #MoabDataStoreDir = ".model"
  #MoabDatastoreName = ".node_data.json"

#TODO: Rather than using File class directly, should a special class be used? <- still applicable?
attr_accessor :user_id,
           :user_datastore_location,
			     :metadata_keys,
			     :required_instance_keys,
			     :required_save_keys,
			     :node_key,
			     :model_key,
			     :version_key,
			     :namespace_key,
			     :_files_mgr_class,
           :views,
			     :model_save_params,
           :moab_data
           #accessors specific to this persitence model
           
            
            
  def initialize(persist_env, data_model_bindings)
    #host = "https://sdb.amazonaws.com/"  (not provided by user)
   
    #user_id = env[:user_id]
    sdb_s3_env = persist_env[:env]
    #TODO: validations on format
    domain_base_name = sdb_s3_env[:path]
    @user_id = sdb_s3_env[:user_id]
    
    #data_model_bindings from NodeElementOperations
    key_fields = data_model_bindings[:key_fields] 
    initial_views_data = data_model_bindings[:views]
    
    @required_instance_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredInstanceKeys
    @required_save_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredSaveKeys
    @node_key = key_fields[:primary_key] #DataStructureModels::Bufs::NodeKey

    #@moab_datastore_name = MoabDatastoreName
    @version_key = VersionKey  
    @model_key = ModelKey
    @namespace_key = NamespaceKey
    @metadata_keys = [@version_key, @model_key, @namespace_key] 
    aak = ENV["AMAZON_ACCESS_KEY_ID"]
    asak = ENV["AMAZON_SECRET_ACCESS_KEY"]
    #rightaws_log = BufsLog.set("RightAWS::SDBInterface", :warn)
    #sdb = RightAws::SdbInterface.new(aak, asak, :logger => rightaws_log, :multi_thread => true)    
    sdb = AwsSdb::Service.new  #aws-sdb
    @user_datastore_location = use_domain!(sdb, "#{domain_base_name}__#{@user_id}") 
    @model_save_params = {:sdb => sdb, :domain => user_datastore_location, :node_key => @node_key}
    @_files_mgr_class = SdbS3Interface::FilesMgr
    @views = "temp"
    @moab_data = {}
    #@views_mgr = ViewsMgr.new({:data_file => @data_file_name})    
    #@record_locker = {}  #tracks records that are in the process of being saved
  end

  def query_all  #TODO move to ViewsMgr
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    query = "select * from `#{domain}`"
    raw_data = sdb.select(query).first
    data = {}
    #puts "QA Raw: #{raw_data.inspect}"
    raw_data.each do |k,v|
      data[k] = from_sdb(v)
    end
    #puts "QA: #{data.inspect}"
    data.values
  end

  #current relations supported:
  # - :equals (data in the key field matches this_value)
  # - :contains (this_value is contained in the key field data (same as equals for non-enumerable types )
  def find_nodes_where(key, relation, this_value)
    res = case relation
      when :equals
        find_equals(key, this_value)
      when :contains
        find_contains(key, this_value)
    end #case
    return res    
  end
  
  def find_equals(key, this_value) 
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    query = "SELECT * FROM `#{domain}`"
    #SDB Queries drive me nuts so we're doing it in ruby
    raw_data = sdb.select(query).first
    data = {}
    raw_data.each do |k,v|
      row_values = from_sdb(v)
      test_val = row_values[key]
      data[k] = row_values if test_val == this_value
    end
    #puts "FE: #{data.inspect}"
    data.values   
  end
  
  def find_contains(key, this_value) 
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    query = "SELECT * FROM `#{domain}`"
    #SDB Queries drive me nuts so we're doing it in ruby
    raw_data = sdb.select(query).first
    data = {}
    raw_data.each do |k,v|
      row_values = from_sdb(v)
      test_val = row_values[key]
      data[k] = row_values if find_contains_type_helper(test_val, this_value)
    end
    #puts "FE: #{data.inspect}"
    data.values   
  end  

  def find_contains_type_helper(stored_data, this_value)
    #p stored_dataj
    resp = nil
    #stored_data = jparse(stored_dataj)
    if stored_data.respond_to?(:"include?")
      resp = (stored_data.include?(this_value))
    else
      resp = (stored_data == this_value)
    end
    return resp
  end

  def get(id)
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    raw_data = sdb.get_attributes(domain, id)
    #puts "Raw Data: #{raw_data.inspect}"
    data = from_sdb(raw_data)
    data = nil if data.empty?
    return data
  end

  def save(new_data)
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    #although we could pull @node_key directly, I do it this way to make it clear
    #that it's a parameter used in saving to the persistence model
    #I should try to be consistent on this
    node_key = @model_save_params[:node_key]
    rev_data = new_data.dup
    rev_data[@version_key] = Time.now.hash
    raw_model_data = HashKeys.sym_to_str(rev_data)
    model_data = to_sdb(raw_model_data)
    sdb.put_attributes(domain, new_data[node_key], model_data)
    return raw_model_data
  end

  def destroy_node(model_metadata)
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    #node_key = @model_save_params[:node_key]
    item_name = model_metadata[@model_key]
    sdb.delete_attributes(domain, item_name)
  end
  
    #namespace is used to distinguish between unique
    #data sets (i.e., users) within the model
  def generate_model_key(namespace, node_key)
    "#{namespace}::#{node_key}"
  end

  def raw_all
    query_all
  end

  def destroy_bulk(list_of_native_records)
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    node_key = @model_save_params[:node_key]
    list_of_native_records.each do |rcd|
      item_name = rcd[node_key]
      #TODO: use the batch delete request
      sdb.delete_attributes(domain, item_name)
    end
  end
  
  private
  
  def use_domain!(sdb, domain_name)
    all_domains = parse_sdb_domains(sdb.list_domains)
    if all_domains.include?(domain_name)
      return domain_name
    else #no domain by that name exists yet
      sdb.create_domain(domain_name)
      return domain_name
    end
  end
    
  def parse_sdb_domains(raw_list_results)
    if raw_list_results.last == ""
    #if raw_list_results[:next_token].nil? #right-aws
      #return raw_list_results[:domains] #right-aws
      return raw_list_results.first  #aws-sdb
    else
      raise "Have not implemented large list handling yet"
    end
  end

  def from_sdb(sdb_data)
    rtn_data = {}
    sdb_data.each do |k_s, v_json|
      k = k_s.to_sym
      rtn_data[k] = jparse(v_json.first)
    end
    rtn_data
  end

  def to_sdb(data)
    formatted_data = {}
    data.each do |k,v|
      k_f = k.to_s
      v_f = v.to_json
      formatted_data[k_f] = v_f
    end
    formatted_data
  end
  
  def jparse(str)
    return JSON.parse(str) if str =~ /\A\s*[{\[]/
    JSON.parse("[#{str}]")[0]
    #JSON.parse(str)
  end
  
end#class
end#module