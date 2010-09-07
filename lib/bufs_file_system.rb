#common libraries

#bufs libraries
require File.dirname(__FILE__) + '/helpers/hash_helpers'
require File.dirname(__FILE__) + '/bufs_escape'
#TODO: Figure out an import or configuration function for the dependent libs
require File.dirname(__FILE__) + '/bufs_info_libs_tmp'
require File.dirname(__FILE__) + '/bufs_file_libs_tmp'


#TODO: Move out the model specific  aspects into a seperate module
#TODO: Use as a generic class for all models
#This is the abstract class used.  Each user would get a unique
#class derived from this one.  In other words, a class context
#is specific to a user.  [User being used loosely to indicate a client-like relationship]

class BufsFileSystem

#TODO Figure out a way to distinguish method calls from dynamically set data
# that were assigned as instance variables
#TODO Dynamic Class definition should include the data store, structure and evironmental models

  ##Class Accessors
  class << self; attr_accessor :class_env,
                               :metadata_keys
  end

  ##Instance Accessors
  attr_accessor :user_data, :model_metadata, :attached_files
                #old accessors  :file_metadata, :filename, :my_dir, :attached_files

  ##Class Methods
  #Class Environment
  def self.set_environment(env)
    @class_env = ClassEnv.new(env)
    @metadata_keys = @class_env.metadata_keys 
  end

  ##Collection Methods
  #This returns all records, but does not create
  #an instance of this class for each record.  Each record is provided
  #in its native form.
  def self.all_native_records
    @class_env.query_all
  end

  def self.all
    raw_nodes = @class_env.raw_all
    raw_nodes.map! {|n| self.new(n)}
  end

  #TODO: Harmonize namespace usage
  def self.call_view(param, match_keys)
    view_method_name = "by_#{param}".to_sym #using CouchDB style for now
    records = if @class_env.views_mgr.respond_to? view_method_name
      puts "Calling View with datstore id: #{@class_env.user_datastore_id}"
      @class_env.views_mgr.__send__(view_method_name, @class_env.user_datastore_id, match_keys)
    else
      #TODO: Think of a more elegant way to handle an unknown view
      raise "Unknown design view #{view_method_name} called for: #{param}"
    end
    nodes = records.map{|r| self.new(r)}
  end

  def self.get(id)
    data = @class_env.get(id)
    rtn = if data
      self.new(data)
    else
      nil
    end
  end

  #This destroys all nodes in the model
  #this is more efficient than calling
  #destroy on instances of this class
  #as it avoids instantiating only to destroy it
  def self.destroy_all
    all_records = self.all_native_records
    @class_env.destroy_bulk(all_records)
  end

  ##Class methods
  #Create the document in the BUFS node format from an existing node.  A BUFS node is an object that ha
  #  my_category
  #  parent_categories
  #  description
  #  attachments in the form of data files
  #
  def self.create_from_other_node(node_obj)
    self.create_from_doc_node(node_obj)
  end

  #Returns the id that will be appended to the document ID to uniquely
  #identify attachment documents associated with the main document
  def self.attachment_base_id
    self.class_env.attachment_base_id #DataStoreModels::CouchRest::AttachmentBaseID
  end

  #Normal instantiation can take two forms that differ only in the source
  #for the initial parameters.  The constructor could be called by the user
  #and passed only user data, or the constructor could be called by a class
  #collection method and the initial parameters would come from a datastore.
  #In the latter case, some of the parameters will include information about
  #the datastore (model metadata).
  def initialize(init_params = {})
    raise "init_params cannot be nil" unless init_params
    @saved_to_model = nil #TODO rename to sychronized_to_model
    #make sure keys are symbols
    init_params = HashKeys.str_to_sym(init_params)
    @user_data, @model_metadata = filter_user_from_model_data(init_params)
    instance_data_validations(@user_data)
    node_key = get_user_data_id(@user_data)
    @model_metadata = update_model_metadata(@model_metadata, node_key)
    
    init_params.each do |attr_name, attr_value|
      iv_set(attr_name.to_sym, attr_value)
    end

    @attached_files = []
  end

  def filter_user_from_model_data(init_params)
    model_metadata_keys = DataStoreModels::FileStore::MetadataKeys
    model_metadata = {}
    model_metadata_keys.each do |k|
      model_metadata[k] = init_params.delete(k) #delete returns deleted value
    end
    [init_params, model_metadata]
  end

  def instance_data_validations(user_data)
    #raise user_data.inspect
    #Check for Required Keys
    required_keys = DataStructureModels::Bufs::RequiredInstanceKeys
    required_keys.each do |rk|
      raise ArgumentError, "Requires a value to be assigned to the key #{rk.inspect} for instantiation" unless user_data[rk]
    end
  end

  def save_data_validations(user_data)
    required_keys = DataStructureModels::Bufs::RequiredSaveKeys
    required_keys.each do |rk|
      raise ArgumentError, "Requires a value to be assigned to the key #{rk.inspect} to be set before saving" unless user_data[rk]
    end
  end

  def get_user_data_id(user_data)
    #FIXME User Node Key from user generated, not hard coded
    user_node_key = DataStructureModels::Bufs::NodeKey
    user_data[user_node_key]
  end

  def update_model_metadata(metadata, node_key)
    #updates @saved_to_model (make a method instead)?
    model_key = DataStoreModels::FileStore::ModelKey
    version_key = DataStoreModels::FileStore::VersionKey
    namespace_key = DataStoreModels::FileStore::NamespaceKey
    id = metadata[model_key]
    namespace = metadata[namespace_key]
    rev = metadata[version_key]
    namespace = @bfs_dir unless namespace #self.class.class_env.collection_namespace unless nam
    #id = DataStoreModels::CouchRest.generate_model_key(namespace, node_key) unless id  #faster
    updated_key_metadata = {model_key => id, namespace_key => namespace}
    #updated_key_metadata.delete(version_key) unless rev  #TODO Is this too model specific?
    metadata.merge!(updated_key_metadata)
    #if rev
    #  @saved_to_model = rev
    #  metadata.merge!({version_key => rev})
    #else
    #  metadata.delete(version_key)  #TODO  Is this too model specific?
    #end
    metadata
  end


  #TODO: Remove the hard coding of data as filenames and use 
  #config file
  #def parent_categories_file_basename
  #  "parent_categories.txt"
  #end

  def self.model_dir
    "#{@base_dir}/#{self.class.namespace}"
  end
  #def self.set_name_space(model_dir)
  #   FileUtils.mkdir_p(File.expand_path(model_dir))
  #   BufsFileSystem.name_space = model_dir
  #   self.normalize
  #end

  #This method will go through the entire model directory and make sure
  #all file names have been normalized (remove strange characters)
  #DANGER: this will fail if there are files in the directory that reduce to the same normalized name
  def self.normalize
    unless File.exists?(BufsFileSystem.name_space)
      raise "Cannot normalize. The File System Directory to work from does not exist: #{BufsFileSystem.name_space}"
    end
    my_dir = self.class.name_space + '/'
    all_entries = Dir.working_entries(my_dir)
    all_entries.each do |cat_entry|
      wkg_dir = my_dir + cat_entry + '/'
      files = Dir.file_data_entries(wkg_dir)
      files.each do |f|
        esc_f = ::BufsEscape.escape(f)
        unless f == esc_f
          full_f = wkg_dir + f
          full_esc_f = wkg_dir + esc_f
          FileUtils.mv(full_f, full_esc_f)
        end
      end
    end
  end

  def self.by_my_category(my_cat)
    puts "Warning:: Calling views by directly attached methods may be deprecated in the future"
    self.call_view(:my_category, my_cat)
  end
=begin
    #raise "nt: #{nodetest.my_category.inspect}" if nodetest
    raise "No category provided for search" unless my_cat
    #puts "Searching for #{my_cat.inspect}"
    my_dir = self.namespace + '/'
    my_cat_dir = my_cat
    wkg_dir = my_dir + my_cat_dir + '/'
    if File.exists?(wkg_dir)
      #added 2/24 at 10:23 am due to spec failure in sync_node seems like BufsFileSystem bug fix
      node_data  = JSON.parse(File.open(wkg_dir + self.data_file_name){|f| f.read})
      bfs = self.new(node_data)
      bfss = []
      bfss << bfs 
      return bfss   #returned as an array for compatibility with other search and node types
    else
      puts "Warning: #{wkg_dir.inspect} was not found"
      return nil
    end
=end

  def self.by_parent_categories(par_cats)
    puts "Warning:: Calling views by directly attached methods may be deprecated in the future"
    self.call_view(:parent_categories, par_cats)
  end
=begin
    par_cats = [par_cats].flatten
    matched_nodes = []
    all_nodes = self.all
    par_cats.each do |par_cat|
      all_nodes.each do |node|
        matched_nodes << node if node.parent_categories.include?(par_cat)
      end 
    end
    return matched_nodes
  end
=end
=begin
  def initialize(init_params = {})
    @saved_to_model = nil #TODO rename to sychronized_to_model
    #make sure keys are symbols
    init_params = HashKeys.str_to_sym(init_params) 
    @user_data, @model_metadata = filter_user_from_model_data(init_params)
    instance_data_validations(@user_data)
    #raise "No parameters were passed to #{self.class} initialization" if (init_params.nil?||init_params.empty?)
    #raise "No directory has been set for #{self}" unless self.class.namespace
    node_key = get_user_data_id(@user_data)
    @model_metadata = update_model_metadata(@model_metadata, node_key)
    #@node_data_hash = {}
    init_params.each do |attr_name, attr_value|
      iv_set(attr_name.to_sym, attr_value)
    end
    #Hack to get around the fact that if my_category hasn't been set
    #then there is no my_category method either
    #iv_set(:my_category, nil)
    #raise "NS: #{self.class.namespace.inspect} My Cat: #{self.my_category.inspect}"
    #@my_dir = self.class.namespace + '/' + self.my_category + '/' if self.my_category

    @attached_files = []
  end

  def filter_user_from_model_data(init_params)
    model_metadata_keys = DataStoreModels::FileStore::MetadataKeys 
    model_metadata = {}
    model_metadata_keys.each do |k|
      model_metadata[k] = init_params.delete(k) #delete returns deleted value
    end
    [init_params, model_metadata]
  end

  def instance_data_validations(user_data)
    #raise user_data.inspect
    #Check for Required Keys
    required_keys = DataStructureModels::Bufs::RequiredInstanceKeys
    required_keys.each do |rk|
      raise ArgumentError, "Requires a value to be assigned to the key #{rk.inspect} for instantiation" unless user_data[rk]
    end
  end
  
  def save_data_validations(user_data)
    required_keys = DataStructureModels::Bufs::RequiredSaveKeys
    required_keys.each do |rk|
      raise ArgumentError, "Requires a value to be assigned to the key #{rk} to be set before saving" unless user_data[rk]
    end
  end

  def get_user_data_id(user_data)
    #FIXME User Node Key from user generated, not hard coded
    user_node_key = DataStructureModels::Bufs::NodeKey
    user_data[user_node_key]
  end

  def update_model_metadata(metadata, node_key)
    #updates @saved_to_model (make a method instead)?
    model_key = DataStoreModels::FileStore::ModelKey
    version_key = DataStoreModels::FileStore::VersionKey
    namespace_key = DataStoreModels::FileStore::NamespaceKey
    id = metadata[model_key] 
    namespace = metadata[namespace_key] 
    rev = metadata[version_key]
    namespace = @bfs_dir unless namespace #self.class.class_env.collection_namespace unless namespace
    #id = DataStoreModels::CouchRest.generate_model_key(namespace, node_key) unless id  #faster without the conditional?
    updated_key_metadata = {model_key => id, namespace_key => namespace}
    #updated_key_metadata.delete(version_key) unless rev  #TODO Is this too model specific?
    metadata.merge!(updated_key_metadata)
    #if rev 
    #  @saved_to_model = rev 
    #  metadata.merge!({version_key => rev}) 
    #else
    #  metadata.delete(version_key)  #TODO  Is this too model specific?
    #end
    metadata
  end
=end
  #this method is basically to make it sort of act like a hash and struct
  #FIXME: IMPORTANT: This breaks under some circumstances of dynamic classing
  #When a new instance is created from the same class, these methods are
  #recreated and use the new instances hash?  At least I think that's what's
  #going on.  Need to isolate and test.  Work around is to use the hash to
  #access the data
  def iv_set(attr_var, attr_value)
    ops = NodeElementOperations::Ops
    add_op_method(attr_var, ops[attr_var]) if ops[attr_var] #incorporates predefined methods
    #update the data store
    @user_data[attr_var] = attr_value
    #instance_variable_set("@#{attr_var}", attr_value)
    #dynamic method acting like an instance variable getter
    self.class.__send__(:define_method, "#{attr_var}".to_sym,
       lambda {@user_data[attr_var]} )
    #dynamic method acting like an instance variable setter
    self.class.__send__(:define_method, "#{attr_var}=".to_sym, 
       lambda {|new_val| @user_data[attr_var] = new_val} )
    #why not just use instance variables?
    #because instance variables don't have a callback method
    #that would allow me to update the data store (@node_data_hash)
    #the data store is needed to iterate over all values stored by 
    #the instance
  end
  
  def add_op_method(param, ops)
    ops.each do |op_name, op_proc|
      method_name = "#{param.to_s}_#{op_name.to_s}".to_sym
      wrapped_op = method_wrapper(param, op_proc)
      self.class.__send__(:define_method, method_name, wrapped_op)
    end
  end 

  #TODO: If a wrapper it is applied the data will be saved to the model
  #      This creates a bit of inconsistent behavior between data w/o operations
  #      and data with operations.  See if it can be made consistent.

  #The method operations are completely decoupled from the object that they are bound to.
  #This creates a problem when operations act on themselves (for example adding x to
  #the current value requires the adder to determine the current value of x). To get
  #around this self-referential problem while maintaining the decoupling this wrapper is used.
  #Essentially it takes the unbound two parameter (this, other) and binds the current value
  #to (this).  This allows a more natural form of calling these operations.  In other words
  # description_add(new_string) can be used, rather than description_add(current_string, new_string).
  def method_wrapper(param, unbound_op)
    #What I want is to call obj.param_op(other)   example: obj.links_add(new_link)
    #which would then add new_link to obj.links
    #however, the predefined operation (add in the example) has no way of knowing
    #about links, so the predefined operation takes two parameters (this, other)
    #and this method wraps the obj.links so that the links_add method doesn't have to
    #include itself as a paramter to the predefined operation
    #lambda {|other| @user_data[param] = unbound_op.call(@user_data[param], other)}
    lambda {|other| this = self.__send__("#{param}".to_sym) #original value
                    rtn_data = unbound_op.call(this, other)
                    new_this = rtn_data[:update_this]
                    self.__send__("#{param}=".to_sym, new_this)
                    it_changed = true
                    it_changed = false if (this == new_this) || !(rtn_data.has_key?(:update_this)) 
                    not_in_model = !@saved_to_model
                    self.save if (not_in_model || it_changed)#unless (@saved_to_model && save) #don't save if the value hasn't changed
                    rtn = rtn_data[:return_value] || rtn_data[:update_this]
                    rtn
           }
  end

  #TODO: Add to spec
  def path_to_node_data
    raise "The category has not been set for #{self}" unless self.my_category
    self.class.namespace + '/' + self.my_category
  end

  def to_hash
    @user_data
  end

  def save
    save_data_validations(self.user_data)
    node_key = DataStructureModels::Bufs::NodeKey
    node_id = self.model_metadata[node_key]
    model_data = inject_node_metadata
    #raise model_data.inspect
    #TODO decide between explicit parameter passing vs keeping model stuff in model
    res = DataStoreModels::FileStore.save(self.class.class_env.model_save_params, model_data)
    version_key = DataStoreModels::FileStore::VersionKey
    rev_data = {version_key => res['rev'].to_s}
    update_self(rev_data)
    #unless self.my_category
    #  raise ArgumentError, "Requires my_category to be set before saving"
    #end
    #TODO: If parent categories are not mandatory the code raising an error can be removed
    #if self.parent_categories.nil? || self.parent_categories.empty?
    #  raise ArgumentError, "Requires at least one parent category to be set before saving"
    #end

    #make model directory
      #debug for permissions problems
      #FileUtils.mkdir_p "/tmp/bfs_test"
      #end debug
    #my_dir = File.join(@namespace, self.my_category)
    #FileUtils.mkdir_p(my_dir)

    #node_data_file = my_dir + self.class.data_file_name
    #user_data = self.to_hash
    #raise "No data found for #{self}" unless user_data

    #desc_file = my_dir + BufsFileSystem.description_file_basename
    #self.description = 'This description was automatically generated on #{Time.now}' unless self.description
    #File.open(desc_file, 'w') { |f| f.write(self.description.to_s)} if self.description
    #File.open(node_data_file, 'w') {|f| f.write(user_data.to_json)} #FIXME need to mixin model data
    #file metadata is part of the data file itself (if it exists)
    #self  <-- Right thing to do, but need stability beofre changing (for testing)
  end

  def inject_node_metadata
    inject_metadata(@user_data)
  end

  def inject_metadata(node_data)
    node_data.merge(@model_metadata)
  end

  def update_self(rev_data)
    self.model_metadata.merge!(rev_data)
    version_key = DataStoreModels::FileStore::VersionKey
    @saved_to_model = rev_data[version_key]
  end

  def  self.create_from_doc_node(node_obj)
    init_params = {}
    init_params['my_category'] = node_obj.my_category
    init_params['parent_categories'] = node_obj.parent_categories
    init_params['description'] = node_obj.description if node_obj.description
    new_bfs = self.new(init_params)
    new_bfs.save
    if node_obj.get_attachment_names.nil? || node_obj.get_attachment_names.empty?
      #do nothing, easier to read like this
    else
      node_obj.get_attachment_names.each do |att_name|
        raw_data = node_obj.attachment_data(att_name)
        #att_file_name = self.namespace + '/' + new_bfs.my_category + '/' 
        puts "Adding Raw Data For: #{node_obj.inspect}"
        file_modified_at = node_obj.get_attachment_metadata['md_attachments'][::BufsEscape.escape(att_name)]['file_modified']
        new_bfs.add_raw_data(att_name, new_bfs.my_category, raw_data,
                   file_modified_at) 
      end
    end
    if node_obj.respond_to?(:list_links) && (node_obj.list_links.nil? || node_obj.list_links.empty?)
      #do nothing, no link data
    elsif node_obj.respond_to?(:list_links)
      new_bfs.add_links(node_obj.list_links) 
    else
      #do nothing, no link method
    end 
    return new_bfs.class.by_my_category(new_bfs.my_category).first
  end

  #TODO: replace hard coded methods based on data names with dynamically generated ones
  def add_parent_categories(new_cats)
    puts "Warning:: add_parent_categories is being deprecated, use <param_name>_add instead ex: parent_categories_add(cats_to_add) "
    parent_categories_add(new_cats)
  end
=begin
    current_cats = orig_cats = self.parent_categories||[]
    #current_cats = orig_cats = self.parent_categories||[]
    #TODO: should update node_data_hash
    new_cats = [new_cats].flatten
    current_cats += new_cats
    current_cats.uniq!
    current_cats.compact!
    if current_cats.size > orig_cats.size
      self.parent_categories = current_cats
      self.save
    end
=end
  alias :add_category :add_parent_categories
  alias :add_categories :add_parent_categories

  def remove_parent_categories(cats_to_remove)
    #TODO: should update node_data_hash
    cats_to_remove = [cats_to_remove].flatten
    cats_to_remove.each do |remove_cat|
      self.parent_categories.delete(remove_cat)
    end
    self.save
    raise "temp error due to no parent categories existing" if self.parent_categories.empty?
  end

  #TODO: Rationalize with BufsInfoDoc
  #FIXME: my_cat not needed?
  def add_raw_data(file_name, my_cat, raw_data, file_modified_at = nil)
    #file_name = unescape(file_name)  #Hack to avoid escaping twice (and changing the name in the process)
    #content type is lost when data is saved into the file model.
    puts "Add Raw Data --- (Unesc) File Name: #{File.basename(file_name)}"
    esc_filename = ::BufsEscape.escape(file_name)
    puts "Add Raw Data --- (Esc) File Name: #{File.basename(esc_filename)}"
    raw_data_dir = #@my_dir # + my_cat
    FileUtils.mkdir_p(raw_data_dir) unless File.exist?(raw_data_dir)
    raw_data_filename = raw_data_dir + '/' + esc_filename
    File.open(raw_data_filename, 'wb'){|f| f.write(raw_data)}
    puts "Model built at: #{raw_data_filename}"
    if file_modified_at
      File.utime(Time.parse(file_modified_at), Time.parse(file_modified_at), raw_data_filename)
    else
      file_modified_at = File.mtime(raw_data_filename).to_s     
    end
    @file_metadata = {'file_modified' => file_modified_at}
    @attached_files << raw_data_filename
    @filename = esc_filename
  end

  #TODO: Need to update spec to include multiple files 
  def add_data_file(file_datas)
    #TODO Use self or user_data?
    self.class.class_env.files_mgr.add_files(self, file_datas)
  end
=begin
    filenames = [filenames].flatten
    filenames.each do |filename|
      my_dest_basename = ::BufsEscape.escape(File.basename(filename))
      #puts "Add Data File --- Basename (Esc) #{my_dest_basename}"
      @filename = my_dest_basename
      FileUtils.mkdir_p(@my_dir) unless File.exist?(@my_dir) #TODO Throw error if its a file
      my_dest = @my_dir + '/' + @filename
      #FIXME: obj.attached_files is broken, list_attached_files should work
      @attached_files << my_dest
      same_file = filename == my_dest
      FileUtils.cp(filename, my_dest, :preserve => true, :verbose => true ) unless same_file
      self.file_metadata = {filename => {'file_modified' => File.mtime(filename).to_s}}
    end
  end
=end

   def attached_files?
    #if @attached_files.size > 0
    #  return true
    #else
     
    #Its better to check the authorative model
    if Dir.file_data_entries(path_to_node_data).size > 0
      #raise "#{path_to_node_data.inspect}"
      #raise "#{Dir.file_data_entries(path_to_node_data).inspect}"
      return true
    else
      return false
    end
  end
  
  def list_attached_files
    #FIXME: Fix @attached_files to work or get rid of it and replace with this method
    Dir.file_data_entries(path_to_node_data)
  end

  def get_attachment_names
    list_attached_files.map {|fn| File.basename(fn)}
  end

  def remove_attached_files(att_basenames)
    att_basenames = [att_basenames].flatten
    att_esc_bn = att_basenames.collect {|bn| BufsEscape.escape(bn)}
    att_filenames = att_esc_bn.collect {|bn| path_to_node_data + '/' + bn}
    FileUtils.rm_f(att_filenames)
  end

  def get_file_data
    my_dest = @my_dir + '/' + @filename
    return  File.open(my_dest, 'rb'){|f| f.read}
  end

  #TODO: Which architecture for links? FileNode or InfoDoc/
  #TODO: Move links' methods to be part of data hash?
  

  def list_links
    node_link_file_name = path_to_node_data + '/' + self.class.link_file_name
    if File.exists?(node_link_file_name)
      links =  JSON.parse(File.open(node_link_file_name) {|f| f.read})
      return links
    else
      return nil
    end
  end

  def add_links(links_to_add)
    #links_to_add = [links_to_add].flatten
    existing_links = list_links||{}
    updated_links = existing_links.merge(links_to_add)
    #updated_links = list_links||[] + links_to_add
    node_link_file_name = path_to_node_data + '/' + self.class.link_file_name
    File.open(node_link_file_name, 'w') {|f| f.write(updated_links.to_json)}
  end

  def remove_links(links_to_remove)
    links_to_remove = [links_to_remove].flatten
    if list_links
      updated_links = list_links - links_to_remove
      node_link_file_name = path_to_node_data + '/' + self.class.link_file_name
      File.open(node_link_file_name, 'w') {|f| f.write(updated_links.to_json)}
      return updated_links
    else
      return []
    end
  end

  def destroy_node
    if self.my_category
      #TODO: my_dir should be from path_to_node_data?
      my_dir = self.class.namespace + '/' + self.my_category + '/'
      p "Destroying: #{my_dir}"
      #rm_f(Dir.glob(my_dir + '*'))
      FileUtils.remove_dir(my_dir, :force => true)
      #how to set self to nil?
    else
      raise "Cannot destroy node, cannot determine its category, has it been saved?"
    end
    raise "Error, unable to delete file data: #{my_dir}" if File.exists?(my_dir)
  end
  alias destroy :destroy_node

end

