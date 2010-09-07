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

class BufsInfoDoc

#TODO Figure out a way to distinguish method calls from dynamically set data
# that were assigned as instance variables
#TODO Dynamic Class definition should include the data store, structure and evironmental models

  ##Class Accessors
  class << self; attr_accessor :class_env,
                               :metadata_keys
  end

  ##Instance Accessors
  attr_accessor :user_data, :model_metadata, :attached_files
                #old accessors :saved_to_model

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
  #Create the document in the BUFS node format from an existing node.  A BUFS node is an object that has the following properties:
  #  my_category
  #  parent_categories
  #  description
  #  attachments in the form of data files
  #
  def self.create_from_other_node(node_obj)
    self.create_from_file_node(node_obj)
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
    model_metadata_keys = self.class.class_env.base_metadata_keys
    model_metadata = {}
    model_metadata_keys.each do |k|
      model_metadata[k] = init_params.delete(k) #delete returns deleted value
    end
    [init_params, model_metadata]
  end

  def instance_data_validations(user_data)
    #Check for Required Keys
    required_keys = self.class.class_env.required_instance_keys
    required_keys.each do |rk|
      raise ArgumentError, "Requires a value to be assigned to the key #{rk} for instantiation" unless user_data[rk]
    end
  end

  def save_data_validations(user_data)
    required_keys = self.class.class_env.required_save_keys
    required_keys.each do |rk|
      raise ArgumentError, "Requires a value to be assigned to the key #{rk} to be set before saving" unless user_data[rk]
    end
  end

  def get_user_data_id(user_data)
    #FIXME User Node Key from user generated, not hard coded
    user_node_key = self.class.class_env.node_key
    user_data[user_node_key]
  end

  def update_model_metadata(metadata, node_key)
    #updates @saved_to_model (make a method instead)?
    model_key = self.class.class_env.model_key #DataStoreModels::CouchRest::ModelKey
    version_key = self.class.class_env.version_key #DataStoreModels::CouchRest::VersionKey
    namespace_key = self.class.class_env.namespace_key #DataStoreModels::CouchRest::NamespaceKey
    id = metadata[model_key] 
    namespace = metadata[namespace_key] 
    rev = metadata[version_key]
    #id = self.class.db_id(node_key) unless id
    namespace = self.class.class_env.user_datastore_id unless namespace
    id = self.class.class_env.generate_model_key(namespace, node_key)  unless id #DataStoreModels::CouchRest.generate_model_key(namespace, node_key) unless id  #faster without the conditional?
    updated_key_metadata = {model_key => id, namespace_key => namespace}
    updated_key_metadata.delete(version_key) unless rev  #TODO Is this too model specific?
    metadata.merge!(updated_key_metadata)
    if rev 
      @saved_to_model = rev 
      metadata.merge!({version_key => rev}) 
    else
      metadata.delete(version_key)  #TODO  Is this too model specific?
    end
    metadata
  end

  #TODO There should be a better way that combines assign user node key
  #def get_model_key
  #  #FIXME: Should come from model data, not hard coded
  #  '_id'
  #end

  #This will take a key-value pair and create an instance variable (actually it's a method)
  # using key as the method name, and sets the return value to the value associated with that key
  # changes to the key's value are reflected in subsequent method calls, and the value can be 
  # updated by using method_name = some value.  Additionally, any custom operations that have been
  # defined for that key name will be loaded in and assigned methods in the form methodname_operation
  def iv_set(attr_var, attr_value)
    ops = NodeElementOperations::Ops 
    add_op_method(attr_var, ops[attr_var]) if ops[attr_var] #incorporates predefined methods
    @user_data[attr_var] = attr_value unless self.class.metadata_keys.include? attr_var.to_sym #self.class.db_metadata_keys.include? attr_var.to_s
    #manually setting instance variable (rather than using instance_variable_set),
    # so @node_data_hash can be updated
    #dynamic method acting like an instance variable getter
    self.class.__send__(:define_method, "#{attr_var}".to_sym,
       lambda {@user_data[attr_var]} )
    #dynamic method acting like an instance variable setter
    self.class.__send__(:define_method, "#{attr_var}=".to_sym,
       lambda {|new_val| @user_data[attr_var] = new_val} )
  end
     
  def add_op_method(param, ops)
       ops.each do |op_name, op_proc|
         method_name = "#{param.to_s}_#{op_name.to_s}".to_sym
         wrapped_op = method_wrapper(param, op_proc)
         self.class.__send__(:define_method, method_name, wrapped_op)
       end
  end  

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
    #lambda {|other| @node_data_hash[param] = unbound_op.call(@node_data_hash[param], other)}
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

  def iv_unset(param)
    self.class.__send__(:remove_method, param.to_sym)
    @user_data.delete(param)
  end

  #some object convenience methods for accessing class methods
  def files_mgr
    self.class.files_mgr
  end


  #Save the object to the CouchDB database
  def save
    save_data_validations(self.user_data)
    node_key = self.class.class_env.node_key 
    node_id = self.model_metadata[node_key]
    model_data = inject_node_metadata
    #raise model_data.inspect
    res = self.class.class_env.save(model_data) 
    version_key = self.class.class_env.version_key
    rev_data = {version_key => res['rev']}
    update_self(rev_data)
    return self
  end

  #def create_view(param)
  #  BufsInfoDocEnvMethods.set_view(self.class.db, self.class.design_doc, param)
  #end


  #Adds parent categories, it can accept a single category or an array of categories
  #aliased for backwards compatibility, this method is dynamically defined and generated
  def add_parent_categories(new_cats)
    puts "Warning:: add_parent_categories is being deprecated, use <param_name>_add instead ex: parent_categories_add(cats_to_add) "
    parent_categories_add(new_cats)
  end

  #Can accept a single category or an array of categories
  #aliased for backwards compatiblity the method is dynamically defined and generated
  def remove_parent_categories(cats_to_remove)
    puts "Warning:: remove_parent_categories is being deprecated, use <param_name>_subtract instead ex: parent_categories_subtract(cats_to_remove)"
    parent_categories_subtract(cats_to_remove)
  end  

  #Returns the attachment id associated with this document.  Note that this does not depend upon there being an attachment.
  #TODO: Verify this is abstracted from the model (I don't hink it is (see attachment_base_id)
  def my_attachment_doc_id
    if self.model_metadata[:_id]
      return self.model_metadata[:_id] + self.class.attachment_base_id
    else
      raise "Can't attach to a document that has not first been saved to the db"
    end
  end

  def get_attachment_names
    self.class.class_env.files_mgr.list_file_keys(self)
  end

  #Get attachment content.  Note that the data is read in as a complete block, this may be something that needs optimized.
  #TODO: add_raw_data parameters to a hash?
  def add_raw_data(attach_name, content_type, raw_data, file_modified_at = nil)
    self.class.class_env.files_mgr.add_raw_data(self, attach_name, content_type, raw_data, file_modified_at = nil)
  end

  def files_add(file_data)
    attach_id = self.class.class_env.files_mgr.add_files(self, file_data)
    self.iv_set(:attachment_doc_id, attach_id)
    self.save
  end

  def files_subtract(file_basenames)
    self.class.class_env.files_mgr.subtract_files(self, file_basenames)
  end


#TODO: Add to spec (currently not used)  I think used by web server, need to genericize (use FilesMgr?)
  def attachment_url(attachment_name)
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc['attachment_doc_id']
    current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
    current_node_attachment_doc.attachment_url(attachment_name)
  end

  def attachment_data(attachment_name)
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc['attachment_doc_id']
    current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
    current_node_attachment_doc.read_attachment(attachment_name)
  end

  def get_attachment_metadata
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc['attachment_doc_id']
    current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
  end

  #TODO: Genericize for all models
#  def self.db_id(node_id)
#    puts "Warning:: method db_id has been deprecated use DataStoreModels::<data store model>.generate_model_key(coll_ns, node_id) instead"
#    #@collection_namespace + '::' + node_id
#    DataStoreModels::CouchRest.generate_model_key(@class_env.collection_namespace, node_id)
#  end

#  def db_id
#    puts "Warning:: instance method db_id has been deprecated use instance method model_key instead"
#    self.class.db_id(self.my_category)
#  end

#  def model_key
#    node_key = DataStructureModels::Bufs::NodeKey 
#    node_id = self.user_data[node_key]
#    DataStoreModels::CouchRest.generate_model_key(@clas_env.collection_namespace, node_id)
#  end
  
  #meta_data should not be in node data so this shouldn't be necessary
  #def remove_node_db_metadata
  #  remove_node_db_metadata(@node_data_hash)
  #end
  
  #this won't work as an instance method because the data needs to be
  #purged before creating the instance
  #def remove_db_metadata(raw_data)
  #  db_metadata_keys = @db_metadata
  #  db_metadata_keys.each {|k| raw_data.delete(k)}
  #  raw_data #now with metadata removed
  #end

  def inject_node_metadata
    inject_metadata(@user_data)
  end

  def inject_metadata(node_data)
    node_data.merge(@model_metadata)
  end

  def update_self(rev_data)
    self.model_metadata.merge!(rev_data)
    version_key = self.class.class_env.version_key #DataStoreModels::CouchRest::VersionKey
    @saved_to_model = rev_data[version_key]
  end

  #Deletes the object and its CouchDB entry
  def destroy_node
    self.class.class_env.destroy_node(self) #DataStoreModels::CouchRest::destroy_node(self)
  end
 
  #Last to be fixed
  def self.create_from_file_node(node_obj)
    #TODO Update this to support the new dynamic architecture once
    #file node is updated to the new architecture
    init_params = {}
    init_params['my_category'] = node_obj.my_category
    init_params['description'] = node_obj.description if (node_obj.respond_to?(:description) && node_obj.description)
    new_bid = self.new(init_params)
    new_bid.add_parent_categories(node_obj.parent_categories)
    new_bid.save
    new_bid.add_data_file(node_obj.list_attached_files) if node_obj.list_attached_files
    #TODO Add to spec test for links
    if node_obj.respond_to?(:list_links) && (node_obj.list_links.nil? || node_obj.list_links.empty?)
      #do nothing, no link data
    elsif node_obj.respond_to?(:list_links)
      new_bid.add_links(node_obj.list_links)
    else
      #do nothing, no link mehtod
    end
    return new_bid.class.get(new_bid['_id'])
  end

end

