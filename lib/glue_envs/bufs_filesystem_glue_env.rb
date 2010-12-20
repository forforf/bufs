#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')

#require 'monitor'

require Bufs.midas 'bufs_data_structure'
require Bufs.moabs 'moab_filesystem_env'

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


module BufsFilesystemEnv
  EnvName = :filesystem_env
  
class GlueEnv
  #This class provides a generic persistence layer interface to the
  #outside world that maps to the specific implementations of the
  #underlying persistent layers
  #Set Logger
  @@log = BufsLog.set(self.name, :warn)
  
  #used to identify metadata for models (should be consistent across models)
  ModelKey = :_id 
  VersionKey = :_rev #to have timestamp
  NamespaceKey = :files_namespace
  
  MoabDataStoreDir = ".model"
  MoabDatastoreName = ".node_data.json"
  
  #include FileSystemEnv

#TODO: Rather than using File class directly, should a special class be used?
#=begin
attr_accessor :user_id,
			     :moab_datastore_name,
			     #:collection_namespace,
			     :user_datastore_location,
			     #:design_doc,
			     #:query_all
			     :metadata_keys,
			     :required_instance_keys,
			     :required_save_keys,
			     #:base_metadata_keys,
			     #:namespace,
			     :node_key,
			     :model_key,
			     :version_key,
			     :namespace_key,
			     :_files_mgr_class,
           :views,
			     :model_save_params,
           :moab_data
#=end

  def initialize(persist_env)
    
    #via environmental settings
    filesystem_env = persist_env[:env]
    key_fields = persist_env[:key_fields]
    fs_path = filesystem_env[:path]
    @user_id = filesystem_env[:user_id]
    @required_instance_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredInstanceKeys
    @required_save_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredSaveKeys
    @node_key = key_fields[:primary_key] #DataStructureModels::Bufs::NodeKey

    @moab_datastore_name = MoabDatastoreName
    @version_key = VersionKey  #
    @model_key = ModelKey
    @namespace_key = NamespaceKey
    @metadata_keys = [@version_key, @model_key, @namespace_key] 
    @user_datastore_location = File.join(fs_path, @user_id, MoabDataStoreDir)    
    @model_save_params = {:nodes_save_path => @user_datastore_location, :data_file => @moab_datastore_name, :node_key => @node_key}
    @_files_mgr_class = FilesystemEnv::FilesMgrInterface
    @views = BufsFileSystemViews
    @moab_data = {:moab_datastore_name => @moab_datastore_name}
    #@views_mgr = ViewsMgr.new({:data_file => @data_file_name})
    
    FileUtils.mkdir_p(fs_path) unless File.exists?(fs_path)
  end

  def query_all  #TODO move to ViewsMgr
    unless File.exists?(@user_datastore_location)
      @@log.debug {"Warning: Can't query records. The File System Directory to work from does not exist: #{@user_datastore_location}"} if @@log.debug?
    end
    all_nodes = []
    my_dir = @user_datastore_location + '/' #TODO: Can this be removed?
    all_entries = Dir.working_entries(my_dir)
    return all_entries || []
  end

  def get(id)
    #TODO my_cat and id are identical, this is probably not a good thing
    #maybe put in some validations to ensure its from the proper collection namespace?
    
    #FIXME: Hack to make it work
    id_path = id.gsub("::","/")
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
      model_data['_rev'] = rev
      f = File.open(save_path, 'w')
      f.write(model_data.to_json)
      f.close
      model_data['rev'] = model_data['_rev'] #TODO <-Investigate to see if it could be consistent
      return model_data
  end

  def destroy_node(node)
    root_dir = @user_datastore_location
    node_dir_name = node._user_data[@node_key]
    node_dir = File.join(root_dir, node_dir_name)
    FileUtils.rm_rf(node_dir)
    node = nil
  end
  
    #namespace is used to distinguish between unique
    #data sets (i.e., users) within the model
  def generate_model_key(namespace, node_key)
    #was in FileSystemEnv mixin
    #fs_generate_model_key(namespace, node_key)
    #TODO: Make sure namespace is portable across model migrations
    "#{namespace}::#{node_key}"
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
