#Bufs directory organization defined in lib/helpers/require_helper.rb
require Bufs.midas 'bufs_data_structure'
require Bufs.glue 'filesystem/filesystem_files_mgr'
require Bufs.helpers 'hash_helpers'

#class ViewsMgr
module BufsFileSystemViews
  #Set Logger
  @@log = BufsLog.set(self.name, :warn)

  #Dependency on BufsInfoDocEnvMethods
  attr_accessor :model_actor


  #def initialize(model_actor=nil)
  #  @model_actor = model_actor #provides the model actor that can provide views
  #  @data_file = model_actor[:data_file]
  #end
  

  #TODO create an index to speed queries? sync issues?
  def self.by_my_category(moab_data, user_datastore_location, match_keys)
    data_file = moab_data[:moab_datastore_name]
    #raise "nt: #{nodetest.my_category.inspect}" if nodetest
    #raise "No category provided for search" unless my_cat
    #puts "Searching for #{my_cat.inspect}"
    match_keys = [match_keys].flatten
    my_dir = user_datastore_location
    bfss = nil
    match_keys.each do |match_key|
      my_cat_dir = match_key
      wkg_dir = File.join(my_dir, my_cat_dir)
      if File.exists?(wkg_dir)
	bfss = bfss || []
	data_file_path = File.join(wkg_dir, data_file)
	node_data  = JSON.parse(File.open(data_file_path){|f| f.read})
	#bfs = self.new(node_data)
	bfss << node_data #bfs
      end
      #return bfss   #returned as an array for compatibility with other search and node types
    #else
    #  puts "Warning: #{wkg_dir.inspect} was not found"
    #  return nil
    end
    return bfss
  end

  def self.by_parent_categories(moab_data, user_datastore_location, match_keys)
    data_file = moab_data[:moab_datastore_name]
    match_keys = [match_keys].flatten
    #all_nodes = all collection method when all is moved into here
    matching_node_data = []
    all_wkg_entries = Dir.working_entries(user_datastore_location)
    all_wkg_entries.each do |entry|
      wkg_dir = File.join(user_datastore_location, entry)
      if File.exists?(wkg_dir)
	      data_file_path = File.join(wkg_dir, data_file)
	      json_data  = JSON.parse(File.open(data_file_path){|f| f.read})
	      node_data = HashKeys.str_to_sym(json_data)
	        match_keys.each do |k|
	        pc = node_data[:parent_categories]
	        if pc && pc.include?(k)
	          matching_node_data << node_data
	          break  #we don't need to loop through each parent cat, if one already matches
	        end
        end
      end
    end
    #we now have all mathcing data
    return matching_node_data
  end
end 

module FilesystemViews

  def call_view(field_name, moab_data, namespace_key, user_datastore_location, match_key, view_name = nil)
    data_file = moab_data[:moab_datastore_name]
    matching_records = []
    all_file_records = Dir.working_entries(user_datastore_location)
    all_file_records.each do |file_record|
      record_path = File.join(user_datastore_location, file_record)
      if File.exists?(record_path)
        data_file_path = File.join(record_path, data_file)
        json_data = JSON.parse(File.open(data_file_path){|f| f.read})
        record = HashKeys.str_to_sym(json_data)
        field_data = record[field_name]
        if field_data == match_key
          matching_records << record
        end
      end
    end
    matching_records
  end

  def self.by_my_category(moab_data, user_datastore_location, match_keys)
    data_file = moab_data[:moab_datastore_name]
    #raise "nt: #{nodetest.my_category.inspect}" if nodetest
    #raise "No category provided for search" unless my_cat
    #puts "Searching for #{my_cat.inspect}"
    match_keys = [match_keys].flatten
    my_dir = user_datastore_location
    bfss = nil
    match_keys.each do |match_key|
      my_cat_dir = match_key
      wkg_dir = File.join(my_dir, my_cat_dir)
      if File.exists?(wkg_dir)
	bfss = bfss || []
	data_file_path = File.join(wkg_dir, data_file)
	node_data  = JSON.parse(File.open(data_file_path){|f| f.read})
	#bfs = self.new(node_data)
	bfss << node_data #bfs
      end
      #return bfss   #returned as an array for compatibility with other search and node types
    #else
    #  puts "Warning: #{wkg_dir.inspect} was not found"
    #  return nil
    end
    return bfss
  end
end


module BufsFilesystemEnv
  #EnvName = :filesystem_env
  
class GlueEnv
  #This class provides a generic persistence layer interface to the
  #outside world that maps to the specific implementations of the
  #underlying persistent layers
  #Set Logger
  @@log = BufsLog.set(self.name, :warn)
  
  include FilesystemViews
  
  #PersistLayerKey not needed, node key can be used as persistent layer key
  #see mysql_glue_env to decouple persistent layer key from node key
  VersionKey = :_rev #to have timestamp
  NamespaceKey = :files_namespace
  
  MoabDataStoreDir = ".model"
  MoabDatastoreName = ".node_data.json"
  
  #include FileSystemEnv

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
           :moab_data,
           #accessors specific to this persitence model
            :moab_datastore_name
            
            
  def initialize(persist_env, data_model_bindings)
    
    #via environmental settings
    filesystem_env = persist_env[:env]
    #key_fields = persist_env[:key_fields]
    fs_path = filesystem_env[:path]
    @user_id = filesystem_env[:user_id]
    
    #data_model_bindings from NodeElementOperations
    key_fields = data_model_bindings[:key_fields] 
    initial_views_data = data_model_bindings[:views]
    
    @required_instance_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredInstanceKeys
    @required_save_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredSaveKeys
    @node_key = key_fields[:primary_key] #DataStructureModels::Bufs::NodeKey

    @moab_datastore_name = MoabDatastoreName
    @version_key = VersionKey  #
    @model_key = @node_key #ModelKey
    @namespace_key = NamespaceKey
    @metadata_keys = [@version_key, @model_key, @namespace_key] 
    @user_datastore_location = File.join(fs_path, @user_id, MoabDataStoreDir)    
    @model_save_params = {:nodes_save_path => @user_datastore_location, :data_file => @moab_datastore_name, :node_key => @node_key}
    @_files_mgr_class = FilesystemInterface::FilesMgr
    @views = BufsFileSystemViews
    @moab_data = {:moab_datastore_name => @moab_datastore_name}
    #@views_mgr = ViewsMgr.new({:data_file => @data_file_name})
    
    FileUtils.mkdir_p(fs_path) unless File.exists?(fs_path)
  end

  def query_all  #TODO move to ViewsMgr
    unless File.exists?(@user_datastore_location)
      @@log.debug {"Warning: Can't query records. The File System Directory to work from does not exist: #{@user_datastore_location}"} if @@log.debug?
    end
    all_records = []
    my_dir = @user_datastore_location + '/' #TODO: Can this be removed?
    all_entries = Dir.working_entries(my_dir)
    all_entries.each do|entry|
      all_records << get(entry)
    end
    return all_records|| []
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
    results =[]
    query_all.each do |record|
      test_val = record[key]
      results << record  if test_val == this_value
    end
    results
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
    #TODO my_cat and id are identical, this is probably not a good thing
    #maybe put in some validations to ensure its from the proper collection namespace?
    
    id_path = File.join(@user_datastore_location, id)
    rtn = if File.exists?(id_path)
      data_file_path = File.join(id_path, @moab_datastore_name)
      json_data = File.open(data_file_path, 'r'){|f| f.read}
      node_data = JSON.parse(json_data)
      node_data = HashKeys.str_to_sym(node_data)
    else
      nil
    end
  end

  def save(new_data)
    #was in FileSystemEnv mixin
    #fs_save(@model_save_params, model_data)
      parent_path = @model_save_params[:nodes_save_path]
      node_key = @model_save_params[:node_key]
      node_path = File.join(parent_path, new_data[node_key])
      file_name = @model_save_params[:data_file]
      save_path = File.join(node_path, file_name)  
      model_data = HashKeys.sym_to_str(new_data)
      FileUtils.mkdir_p(node_path) unless File.exist?(node_path)
      rev = Time.now.hash #<- I would use File.mtime, but how to get the mod time before saving?
      model_data[@version_key] = rev
      f = File.open(save_path, 'w')
      f.write(model_data.to_json)
      f.close
      model_data['rev'] = model_data[@version_key] #TODO <-Investigate to see if it could be consistent
      return model_data
  end

  def destroy_node(model_metadata)
    root_dir = @user_datastore_location
    node_id = model_path(model_metadata[@model_key])
    node_dir = File.join(root_dir, node_id)
    
    FileUtils.rm_rf(node_dir)
    #node = nil
  end
  
    #namespace is used to distinguish between unique
    #data sets (i.e., users) within the model
  def generate_model_key(namespace, node_key)
    #was in FileSystemEnv mixin
    #fs_generate_model_key(namespace, node_key)
    #TODO: Make sure namespace is portable across model migrations
    "#{namespace}::#{node_key}"
  end
  
  def model_path(model_key_value)
    model_key_value.gsub("::","/")
  end
    
  def raw_all
    entries = query_all
    raw_nodes = []
    entries.each do |entry|
    data_path = File.join(@user_datastore_location, entry, @moab_datastore_name)
      data_json = File.open(data_path, 'r'){|f| f.read}
      data = JSON.parse(data_json)
      raw_nodes << data
    end
    raw_nodes
  end

  def destroy_bulk(list_of_native_records)
    return nil unless list_of_native_records
    list_of_native_records.each do |r|
      #puts "Dir: #{File.dirname(r)}"
      r = File.join(@user_datastore_location, r) if File.dirname(r) == "."
      #puts "Removing: #{r.inspect}"
      FileUtils.rm_rf(r)
    end
    [] #TODO ok to return nil if all docs destroyed? also, not verifying
  end
end 
end
