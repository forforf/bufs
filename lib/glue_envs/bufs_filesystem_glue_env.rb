#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')

require 'monitor'

require Bufs.midas 'bufs_data_structure'
require Bufs.moabs 'moab_filesystem_env'

#class ViewsMgr
module BufsFileSystemViews

  #Dependency on BufsInfoDocEnvMethods
  attr_accessor :model_actor


  #def initialize(model_actor=nil)
  #  @model_actor = model_actor #provides the model actor that can provide views
  #  @data_file = model_actor[:data_file]
  #end

  #TODO create an index to speed queries? sync issues?
  def self.by_my_category(moab_data, user_datastore_selector, match_keys)
    data_file = moab_data[:data_file_name]
    #raise "nt: #{nodetest.my_category.inspect}" if nodetest
    #raise "No category provided for search" unless my_cat
    #puts "Searching for #{my_cat.inspect}"
    match_keys = [match_keys].flatten
    my_dir = user_datastore_selector
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

  def self.by_parent_categories(moab_data, user_datastore_selector, match_keys)
    data_file = moab_data[:data_file_name]
    match_keys = [match_keys].flatten
    #all_nodes = all collection method when all is moved into here
    matching_node_data = []
    all_wkg_entries = Dir.working_entries(user_datastore_selector)
    all_wkg_entries.each do |entry|
      wkg_dir = File.join(user_datastore_selector, entry)
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
  @@this_file = File.basename(__FILE__)
  #Set Logger
  @@log = BufsLog.set(@@this_file)


#TODO: Rather than using File class directly, should a special class be used?
#=begin
attr_accessor :fs_user_id,
           :user_id,  #need to add to spec and mesh with fs_user_id
			     :data_file_name,
			     :collection_namespace,
			     :user_datastore_selector,
			     :user_datastore_id,
			     #:design_doc,
			     #:query_all,
			     :fs_metadata_keys,
			     :metadata_keys,
			     :required_instance_keys,
			     :required_save_keys,
			     :base_metadata_keys,
			     :namespace,
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
    filesystem_env = persist_env[:env]
    key_fields = persist_env[:key_fields]
    #env_name = :bufs_file_system_env  #"#{self.to_s}_env".to_sym  <= (same thing but not needed yet)
    #puts "GlueFileSys env keys: #{env.keys.inspect}" 
    #fs_path = env[env_name][:path]
    
    #fs_user_id = env[env_name][:user_id]
    #@user_id = fs_user_id
    fs_path = filesystem_env[:path]
    @user_id = filesystem_env[:user_id]
    
    FileUtils.mkdir_p(fs_path) unless File.exists?(fs_path)
    #@collection_namespace = FileSystemEnv.set_collection_namespace(fs_path, fs_user_id)
    #TODO: user_datastore_selector gets .model added at it at some point magically, set in one place to maintain consistency
    @user_datastore_selector = FileSystemEnv.set_user_datastore_selector(fs_path, @user_id)
    @user_datastore_id = FileSystemEnv.set_user_datastore_id(fs_path, @user_id)

    @fs_metadata_keys = FileSystemEnv.set_fs_metadata_keys #(@collection_namespace)
    @metadata_keys = @fs_metadata_keys #TODO spaghetti code alert
    @base_metadata_keys = FileSystemEnv::BaseMetadataKeys
    @required_instance_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredInstanceKeys
    @required_save_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredSaveKeys
    @node_key = key_fields[:primary_key] #DataStructureModels::Bufs::NodeKey
    @version_key = FileSystemEnv::VersionKey
    @model_key = FileSystemEnv::ModelKey
    @namespace_key = FileSystemEnv::NamespaceKey
    #@user_datastore_selector = FileSystemEnv.set_namespace(fs_path, fs_user_id)
    @namespace = FileSystemEnv.set_namespace(fs_path, @user_id)
    #BufsInfoDocEnvMethods.set_view_all(@db, @design_doc, @collection_namespace)
    #@user_attachClass = attachClass  
    @data_file_name = FileSystemEnv.set_data_file_name
    @model_save_params = {:nodes_save_path => @user_datastore_selector, :data_file => @data_file_name, :node_key => @node_key}
    @_files_mgr_class = FileSystemEnv::FilesMgrInterface
    @views = BufsFileSystemViews
    @moab_data = {:data_file_name => @data_file_name}
    #@views_mgr = ViewsMgr.new({:data_file => @data_file_name})
  end

  def query_all  #TODO move to ViewsMgr
    unless File.exists?(@user_datastore_selector)
      @@log.debug {"Warning: Can't query records. The File System Directory to work from does not exist: #{@user_datastore_selector}"} if @@log.debug?
    end
    all_nodes = []
    my_dir = @user_datastore_selector + '/' #TODO: Can this be removed?
    all_entries = Dir.working_entries(my_dir)
    return all_entries || []
  end

  def get(id)
    #TODO my_cat and id are identical, this is probably not a good thing
    #maybe put in some validations to ensure its from the proper collection namespace?
    
    #FIXME: Hack to make it work
    id_path = id.gsub("::","/")
    rtn = if File.exists?(id_path)
      data_file_path = File.join(id_path, @data_file_name)
      json_data = File.open(data_file_path, 'r'){|f| f.read}
      node_data = JSON.parse(json_data)
      node_data = HashKeys.str_to_sym(node_data)
    else
      nil
    end
  end

  def save(model_data)
    FileSystemEnv.save(@model_save_params, model_data)
  end

  def destroy_node(node)
    root_dir = @user_datastore_selector
    node_dir_name = node._user_data[@node_key]
    node_dir = File.join(root_dir, node_dir_name)
    FileUtils.rm_rf(node_dir)
    node = nil
  end

  def generate_model_key(namespace, node_key)
    FileSystemEnv.generate_model_key(namespace, node_key)
  end

  def raw_all
    entries = query_all
    raw_nodes = []
    entries.each do |entry|
    data_path = File.join(@user_datastore_selector, entry, @data_file_name)
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
      r = File.join(@user_datastore_selector, r) if File.dirname(r) == "."
      #puts "Removing: #{r.inspect}"
      FileUtils.rm_rf(r)
    end
    [] #TODO ok to return nil if all docs destroyed? also, not verifying
  end
end 
end
