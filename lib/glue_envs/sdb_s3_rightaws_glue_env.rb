#Bufs directory structure defined in lib/helpers/require_helpers'
require Bufs.midas 'bufs_data_structure'
require Bufs.glue '/sdb_s3/sdb_s3_files_mgr'
require Bufs.helpers 'hash_helpers'
require Bufs.helpers 'log_helper'

#require 'right_aws'
require 'aws_sdb'
require 'json'

module SdbS3Env
class GlueEnv
  
  
  @@log = BufsLog.set(self.name, :info)
   #used to identify metadata for models (should be consistent across models)
  ModelKey = :_id 
  VersionKey = :_rev #to have timestamp
  NamespaceKey = :files_namespace
  
  MoabDataStoreDir = ".model"
  MoabDatastoreName = ".node_data.json"

#TODO: Rather than using File class directly, should a special class be used?
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
    @record_locker = {}  #tracks records that are in the process of being saved
  end

  def query_all  #TODO move to ViewsMgr
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    #block_until_all_free #this takes too long
    
    sdb.query(domain)
  end

  def get(id)
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]

    #check to see if the record is in the process of being saved, and blocks until it finishes
    #block_when_busy(id)
=begin
    if @record_locker[id] == :thread_starting
      @@log.info { "Blocked while waiting for thread finishes saving data (init)" } if @@log.info?
      until @record_locker[id] != :thread_starting do
        sleep 0.01
      end
      if @record_locker[id].class == Thread
        @@log.info { "Blocked while waiting for thread to finish saving data (running)[1]"} if @@log.info?
        @record_locker[id].join
      else
        raise "record locker went into unknown state: #{@record_locker[id].inspect}"
      end
    elsif @record_locker[id].class == Thread
      @@log.info { "Blocked while waiting for thread to finish saving data (running)[2]"} if @@log.info?
      @record_locker[id].join
    elsif @record_locker[id] == nil
      #do nothing
    else #something unexpected happened
      raise "record locker went into unkwown state: #{@record_locker[id].inspect}"
    end
=end  

    raw_data = sdb.get_attributes(domain, id)
    #attrib_data = raw_data[:attributes]  #right_aws
    #data = from_sdb(attrib_data) #right_aws
    
  end

  def save(new_data)
    sdb = @model_save_params[:sdb]
    domain = @model_save_params[:domain]
    #although we could pull @node_key directly, I do it this way to make it clear
    #that it's a parameter used in saving to the persistence model
    #I should try to be consistent on this
    node_key = @model_save_params[:node_key]
    model_data = to_sdb(HashKeys.sym_to_str(new_data))
    
    @record_locker[new_data[node_key]] = :thread_starting
    #get will check and see if the thread has joined
    t = Thread.new do
      #t.abort_on_exception = true
      @record_locker[new_data[node_key]] = t
      sdb.put_attributes(domain, new_data[node_key], model_data)
    
      #make sure the data is available before moving on
      #performance hit, but data assurance
    
      if new_data[node_key]  #do this if the data is not nil
        @@log.info { "Entered Ensure Save Loop for saving (threaded): #{new_data[node_key].inspect}"} if @@log.info?
        sleep_base_time = 0.2
        sleep_increment = 0.1
        sleep_maximum = 10
        sleep_time = sleep_base_time
        
        save_data = sdb.get_attributes(domain, new_data[node_key])[:attributes]
        until save_data != {}
          
          @@log.info{ "Checking if data is saved: #{save_data.inspect} [1]" } if @@log.info?
          sleep sleep_time
          sleep_time += sleep_increment
          break if sleep_time > sleep_maximum
          save_data = sdb.get_attributes(domain, new_data[node_key])[:attributes]
          @@log.info{ "Checking if data is saved: #{save_data.inspect} [2]" } if @@log.info?
        end
      end
      
      @@log.info {"Finished Saving Data: #{new_data[node_key].inspect}"} if @@log.info?
    end
  end

  def destroy_node(node)
  end
  
    #namespace is used to distinguish between unique
    #data sets (i.e., users) within the model
  def generate_model_key(namespace, node_key)

  end

  def raw_all
  end

  def destroy_bulk(list_of_native_records)
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

  def block_when_busy(id)
        #check to see if the record is in the process of being saved, and blocks until it finishes
    if @record_locker[id] == :thread_starting
      @@log.info { "Blocked while waiting for thread finishes saving data (init)" } if @@log.info?
      until @record_locker[id] != :thread_starting do
        sleep 0.01
      end
      if @record_locker[id].class == Thread
        @@log.info { "Blocked while waiting for thread to finish saving data (running)[1]"} if @@log.info?
        @record_locker[id].join
        @record_locker.delete(id)
      else
        raise "record locker went into unknown state: #{@record_locker[id].inspect}"
      end
    elsif @record_locker[id].class == Thread
      @@log.info { "Blocked while waiting for thread to finish saving data (running)[2]"} if @@log.info?
      @record_locker[id].join
      @record_locker.delete(id)
    elsif @record_locker[id] == nil
      #do nothing
    else #something unexpected happened
      raise "record locker went into unkwown state: #{@record_locker[id].inspect}"
    end
  end
  
  def block_until_all_free
    #get threads that are initializing
    initializing_threads = {}
    running_threads = {}
    @record_locker.each do |id, thread|
      initializing_threads = @record_locker[id] if thread == :thread_starting
      running_threads = @record_locker[id] if thread.class == Thread
    end
    
    initializing_threads.each do |id, thread|
      until @record_locker[id] != :thread_starting do
        sleep 0.01
      end
      if @record_locker[id].class == Thread
        @@log.info { "Blocked while waiting for thread to finish saving data (running)[3]"} if @@log.info?
        @record_locker[id].join
        @record_locker.delete(id)
      else
        raise "record locker went into unknown state: #{@record_locker[id].inspect}"
      end
    end
    
    running_threads.each do |id, thread|
      @@log.info { "Blocked while waiting for thread to finish saving data (running)[3]"} if @@log.info?
      thread.join
      @record_locker.delete(id)
    end
  end #def
end#class
end#module