#common libraries

#bufs libraries
require File.dirname(__FILE__) + '/helpers/hash_helpers'
require File.dirname(__FILE__) + '/bufs_escape'

#This is the base abstract class used.  Each user would get a unique
#class derived from this one.  In other words, a class context
#is specific to a user.
#[User being used loosely to indicate a client-like relationship]

#The generic model environment would be defined in this class, and the specific
#bindings would be implemented when the class was instantiated.  
#since this is the abstract base class, we only open up the class here to
#provide a bit more helpful error if we can't find a particular method
#When created it should support the following methods and/or accessors
# Methods
#   initialize(env) - Uses env parameters to set up the model environment
#   query_all - Queries for all records.
#   get(id) - Get a specific record based on its id
#   save(model_data) - save the record to the persistence model
#   destroy_node(node) - removes the record from the persistence model
#   generate_model_key(namespace, node_key) - generates a unique id for that model
#   raw_all - retreive all records in native persistence model format
#   destroy_bulk - destroy records in native persistence model format
# Important Accessors
#   :_files_mgr - points to the FilesMgr object that handles
#    files


#TODO: Figure out what I was thinking with these method missing error messages
class GlueEnv
  def method_missing(name)
    raise NameError,"#{name} not found in #{self.class}. Has it been"\
                    " overwritten to support the persistent model yet?"
  end
end

class FilesMgr

  #def method_missing(name)
  #  raise NameError,"#{name} not found in #{self.class}. Has it been"\
                    " overwritten to support file/attachment management yet?"

    #Allow dynamically adding of user data
    #TODO Add name checking to make sure its not misspelled or other clues that its not data
  #end


  attr_accessor :moab_interface

  def initialize(moab_interface)
    @moab_interface = moab_interface
  end

  #TODO: Move common file management functions from base node to here
  def add_files(node, file_datas)
    @moab_interface.add_files(node, file_datas)
  end

  def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
    @moab_interface.add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
  end

  def subtract_files(node, params)
    @moab_interface.subtract_files(node, params)
  end

  def get_raw_data(node, basename)
    @moab_interface.get_raw_data(node, basename)
  end

  def get_attachments_metadata(node)
    @moab_interface.get_attachments_metadata(node)
  end
end


class BufsBaseNode

#TODO Figure out a way to distinguish method calls from dynamically set data
# that were assigned as instance variables
#TODO Dynamic Class definition should include the data store, structure and 
#evironmental models

  #Class Accessors
  class << self; attr_accessor :myGlueEnv, #uppercased to highlight its supporting the class
                               :metadata_keys
  end

  ##Instance Accessors
  attr_accessor :_user_data, :_model_metadata, :attached_files, 
                :my_GlueEnv,  #note the "_" to differentiate from class accessor
                :_files_mgr

  #def method_missing(name, *otherstuff)
    #raise NameError,"#{name} not found in #{self.class}. Has it been"\
    #                " overwritten to support file/attachment management yet?"

    #Allow dynamically adding of user data
    #TODO Add name checking to make sure its not misspelled or other clues that its not data
    #self.__set_userdata_key(name.to_sym, nil)
  #end

  


  #Class Methods
  #Setting up the Class Environment - The class environment holds all
  # model-specific implementation details
  def self.set_environment(env, glue_name)
    reqs = env[:requires]  #nil if being created from factory
    #incs = env[:includes] 
    reqs.each {|r| require r} if reqs   #load software libraries needed
    #incs.each {|mod| include Module.const_get(mod)} if incs  #include the modules to mix in to the node
    glueModule = Object.const_get(glue_name)
    glueClass = glueModule::GlueEnv
    @myGlueEnv = glueClass.new(env)
    @metadata_keys = @myGlueEnv.metadata_keys 
  end

  #Collection Methods
  #This returns all records, but does not create
  #an instance of this class for each record.  Each record is provided
  #in its native form.
  def self.all_native_records
    @myGlueEnv.query_all
  end

  #TODO: Add the very cool feature to spec (creating new fields on the fly)
  #TODO: Document the feature too!!
  def self.all(data_structure_changes = {})
    #add_keys = data_structure_changes[:add]
    #remove_keys = data_structure_changes[:remove]
    #TODO: test for proper format

    raw_nodes = @myGlueEnv.raw_all

    raw_nodes.map! do |base_data| 
      combined_data = self.modify_data_structures(base_data, data_structure_changes)
      self.new(combined_data)
    end
  end

  def self.modify_data_structures(base_data, changes)
    add_keys_values = changes[:add]||{}
    remove_keys = changes[:remove]||[]  #note its an array
    removed_data = base_data.delete_if {|k,v| remove_keys.include?(k)}
    added_data = add_keys_values.merge(removed_data) #so that add doesn't overwrite existing keys
  end

  def self.call_view(param, match_keys, data_structure_changes = {})
    view_method_name = "by_#{param}".to_sym #using CouchDB style for now
    records = if @myGlueEnv.views.respond_to? view_method_name
      @myGlueEnv.views.__send__(view_method_name,
                                  @myGlueEnv.moab_data,
                                  @myGlueEnv.user_datastore_id, 
                                  match_keys)
    else
      #TODO: Think of a more elegant way to handle an unknown view
      raise "Unknown design view #{view_method_name} called for: #{param}"
    end
    
    nodes = []
    records.map do |base_data|
      if base_data
        combined_data = self.modify_data_structures(base_data, data_structure_changes)
        nodes << self.new(combined_data)
      end
    end
    return nodes
  end

  def self.get(id)
    data = @myGlueEnv.get(id)
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
    @myGlueEnv.destroy_bulk(all_records)
  end

  #TODO: Fix create from other node to work
  #Create the document in the BUFS node format from an existing node.
  def self.__create_from_other_node(other_node)
    #TODO:Figure out data structure imports
    #Idea, for duplicates, this node takes precedence
    #for new data structures, other node operations (if they exist) are used
    #Not implemented yet, though
    #TODO: add to spec
    #TODO: what about node id collisions? currently ignoring it
    #and letting the persistence model work it out
    this_node = self.new(other_node._user_data)
    this_node.__save
    this_node.__import_attachments(other_node.__export_attachments) if other_node.attached_files
  end

  #Returns the id that will be appended to the document ID to uniquely
  #identify attachment documents associated with the main document
  #TODO: NOT COMPLETELY ABSTRACTED YET
  def self.attachment_base_id
    @myGlueEnv.attachment_base_id 
  end


  #Normal instantiation can take two forms that differ only in the source
  #for the initial parameters.  The constructor could be called by the user
  #and passed only user data, or the constructor could be called by a class
  #collection method and the initial parameters would come from a datastore.
  #In the latter case, some of the parameters will include information about
  #the datastore (model metadata).
  def initialize(init_params = {})
    #setting the class accessor to also be an instance accessor
    #for convenience and hopefully doesn't create confusion
    @my_GlueEnv = self.class.myGlueEnv
    raise "init_params cannot be nil" unless init_params
    @saved_to_model = nil #TODO rename to sychronized_to_model
    #make sure keys are symbols
    init_params = HashKeys.str_to_sym(init_params)
    @_user_data, @_model_metadata = filter_user_from_model_data(init_params)
    instance_data_validations(@_user_data)
    node_key = get__user_data_id(@_user_data)
    moab_file_mgr = @my_GlueEnv._files_mgr_class.new(@my_GlueEnv, node_key)
    @_files_mgr = FilesMgr.new(moab_file_mgr)
    @_model_metadata = update__model_metadata(@_model_metadata, node_key)
    
    init_params.each do |attr_name, attr_value|
      __set_userdata_key(attr_name.to_sym, attr_value)
    end
  end

  #This will take a key-value pair and create an instance variable (actually
  # it's a method)using key as the method name, and sets the return value to
  # the value associated with that key changes to the key's value are reflected
  # in subsequent method calls, and the value can be updated by using
  # method_name = some value.  Additionally, any custom operations that have
  # been defined for that key name will be loaded in and assigned methods in
  # the form methodname_operation
  def __set_userdata_key(attr_var, attr_value)
    ops = NodeElementOperations::Ops
    #incorporates predefined methods
    add_op_method(attr_var, ops[attr_var]) if ops[attr_var]
    unless self.class.metadata_keys.include? attr_var.to_sym
      @_user_data[attr_var] = attr_value
    else
      raise "Key match: #{attr_var.to_sym.inspect} UserData: #{@_user_data.inspect}"
    end
    #manually setting instance variable (rather than using instance_variable_set),
    # so @node_data_hash can be updated
    #dynamic method acting like an instance variable getter
    self.class.__send__(:define_method, "#{attr_var}".to_sym,
       lambda {@_user_data[attr_var]} )
    #dynamic method acting like an instance variable setter
    self.class.__send__(:define_method, "#{attr_var}=".to_sym,
       lambda {|new_val| @_user_data[attr_var] = new_val} )
  end

  #TODO: Method Wrapper is not sufficiently tested
  #The method operations are completely decoupled from the object that they are bound to.
  #This creates a problem when operations act on themselves (for example adding x to
  #the current value requires the adder to determine the current value of x). To get
  #around this self-referential problem while maintaining the decoupling this wrapper is used.
  #Essentially it takes the unbound two parameter (this, other) and binds the current value
  #to (this).  This allows a more natural form of calling these operations.  In other words
  # description_add(new_string) can be used, rather than description_add(current_string, new_string).
  def __method_wrapper(param, unbound_op)
    #What I want is to call obj.param_op(other)   example: obj.links_add(new_link)
    #which would then add new_link to obj.links
    #however, the predefined operation (add in the example) has no way of knowing
    #about links, so the predefined operation takes two parameters (this, other)
    #and this method wraps the obj.links so that the links_add method doesn't have to
    #include itself as a paramter to the predefined operation
    #lambda {|other| @node_data_hash[param] = unbound_op.call(@node_data_hash[param], other)}
    lambda {|other| old_this = self.__send__("#{param}".to_sym) #original value
                    #we're going to compare the new value to the old later
                    if old_this
                      this = old_this.dup 
                    else
                      this = old_this
                    end
                    rtn_data = unbound_op.call(this, other)
                    new_this = rtn_data[:update_this]
                    self.__send__("#{param}=".to_sym, new_this)
                    it_changed = true
                    it_changed = false if (old_this == new_this) || !(rtn_data.has_key?(:update_this))
                    not_in_model = !@saved_to_model
                    self.__save if (not_in_model || it_changed)#unless (@saved_to_model && save) #don't save if the value hasn't changed
                    rtn = rtn_data[:return_value] || rtn_data[:update_this]
                    rtn
           }
  end

  def __unset_userdata_key(param)
    self.class.__send__(:remove_method, param.to_sym)
    @_user_data.delete(param)
  end

  #NOTE: For ruby objects that are automatically added that collide with user data names
  #that ruby functionality (currently) will be lost

  #Save the object to the CouchDB database
  def __save
    save_data_validations(self._user_data)
    node_key = @my_GlueEnv.node_key
    node_id = self._model_metadata[node_key]
    model_data = inject_node_metadata
    #raise model_data.inspect
    res = @my_GlueEnv.save(model_data)
    version_key = @my_GlueEnv.version_key
    rev_data = {version_key => res['rev']}
    update_self(rev_data)
    return self
  end


  def __export_attachment(attachment_name)
    md = __get_attachment_metadata(attachment_name)
    data = get_raw_data(attachment_name)
    export = {:metadata => md, :data => data}
  end

  def __import_attachment(attach_name, att_xfer_format)
    #transfer format is the format of the export method
    content_type = att_xfer_format[:metadata][:content_type]
    file_modified_at = att_xfer_format[:metadata][:file_modified]
    raw_data = att_xfer_format[:raw_data]
    add_raw_data(attach_name, content_type, raw_data, file_modified_at)
  end

  #Deletes the object
  def __destroy_node
    @my_GlueEnv.destroy_node(self)
  end

  def self.__create_from_other_node(other_node)
    #TODO: How to deal with differently defined data structures?
    #currently assume transfers are between models of identical data structures
    #either enforce that, or figure out generic solution

    #create new node
    new_basic_node = self.new(other_node._user_data)

    #transfer attachments
    if other_node.attached_files
      other_node.attached_files.each do |att_file|
        new_basic_node.__import_attachment(att_file, other_node.__export_attachment(att_file)) if att_file
      end
    end
    new_basic_node
  end

  def __get_attachments_metadata
    md = @_files_mgr.get_attachments_metadata(self)
    md = HashKeys.str_to_sym(md)
    md.each do |fbn, fmd|
      md[fbn] = HashKeys.str_to_sym(fmd)
    end
    md
  end

  def __get_attachment_metadata(attachment_name)
    all_md = __get_attachments_metadata
    index_name = BufsEscape.escape(attachment_name)
    all_md[index_name.to_sym]
  end



  #Deprecated Methods------------------------
  #Adds parent categories, it can accept a single category or an array of categories
  #aliased for backwards compatibility, this method is dynamically defined and generated
  def add_parent_categories(new_cats)
    raise "Warning:: add_parent_categories is being deprecated, use <param_name>_add instead ex: parent_categories_add(cats_to_add) "
    parent_categories_add(new_cats)
  end

  #Can accept a single category or an array of categories
  #aliased for backwards compatiblity the method is dynamically defined and generated
  def remove_parent_categories(cats_to_remove)
    raise "Warning:: remove_parent_categories is being deprecated, use <param_name>_subtract instead ex: parent_categories_subtract(cats_to_remove)"
    parent_categories_subtract(cats_to_remove)
  end
  #-------------------------------------------  

  #Attachment File Operation Methods-------------------------------

  #Get attachment content.  Note that the data is read in as a complete block, this may be something that needs optimized.
  #TODO: add_raw_data parameters to a hash?
  def add_raw_data(attach_name, content_type, raw_data, file_modified_at = nil)
    attached_basenames = @_files_mgr.add_raw_data(self, attach_name, content_type, raw_data, file_modified_at = nil)
    if self.attached_files
      self.attached_files += attached_basenames
    else
      self.__set_userdata_key(:attached_files, attached_basenames)
    end

    self.__save
  end

  def files_add(file_datas)
    file_datas = [file_datas].flatten
    #TODO keep original names, and have model abstract character issues
    #TODO escaping is spread all over, do it in one place
    attached_basenames = @_files_mgr.add_files(self, file_datas)
    if self.attached_files
      self.attached_files += attached_basenames
    else
      self.__set_userdata_key(:attached_files, attached_basenames)
    end
    self.__save
  end

  def files_subtract(file_basenames)
    file_basenames = [file_basenames].flatten
    @_files_mgr.subtract_files(self, file_basenames)
    self.attached_files -= file_basenames
    self.__save
  end

  def files_remove_all
    @_files_mgr.subtract_files(self, :all)
    self.attached_files = nil
    self.__save
  end
  
  def get_raw_data(attachment_name)
    @_files_mgr.get_raw_data(self, attachment_name)
  end


#TODO: Add to spec (currently not used)  I think used by web server, need to genericize (use FilesMgr?)
  #def attachment_url(attachment_name)
  #  current_node_doc = self.class.get(self['_id'])
  #  att_doc_id = current_node_doc['attachment_doc_id']
  #  current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
  #  current_node_attachment_doc.attachment_url(attachment_name)
  #end

  def get_file_data(attachment_name)
    @_files_mgr.get_file_data(self, attachment_name)
    #current_node_doc = self.class.get(self['_id'])
    #att_doc_id = current_node_doc['attachment_doc_id']
    #current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
    #current_node_attachment_doc.read_attachment(attachment_name)
  end
#-----------------------------------------------------------
#------------------------------------------------------------
  private

  def add_op_method(param, ops)
       ops.each do |op_name, op_proc|
         method_name = "#{param.to_s}_#{op_name.to_s}".to_sym
         wrapped_op = __method_wrapper(param, op_proc)
         self.class.__send__(:define_method, method_name, wrapped_op)
       end
  end 

  def filter_user_from_model_data(init_params)
    _model_metadata_keys = @my_GlueEnv.metadata_keys
    #_model_metadata_keys = @my_GlueEnv.base_metadata_keys
    _model_metadata = {}
    _model_metadata_keys.each do |k|
      _model_metadata[k] = init_params.delete(k) if init_params[k] #delete returns deleted value
    end
    [init_params, _model_metadata]
  end

  def instance_data_validations(_user_data)
    #Check for Required Keys
    required_keys = @my_GlueEnv.required_instance_keys
    required_keys.each do |rk|
      err_str = "The key #{rk.inspect} must be associated with a"\
                " value for instantiation"
      raise ArgumentError, err_str unless _user_data[rk]
    end
  end

  def save_data_validations(_user_data)
    required_keys = @my_GlueEnv.required_save_keys
    required_keys.each do |rk|
      err_str = "The key #{rk.inspect} must be associated with a"\
                " value before saving"
      raise ArgumentError, err_str unless _user_data[rk]
    end
  end

  #TODO Rename to remove extra line space
  def get__user_data_id(_user_data)
    user_node_key = @my_GlueEnv.node_key
    _user_data[user_node_key]
  end

  def update__model_metadata(metadata, node_key)
    #updates @saved_to_model (make a method instead)?
    model_key = @my_GlueEnv.model_key
    version_key = @my_GlueEnv.version_key
    namespace_key = @my_GlueEnv.namespace_key
    id = metadata[model_key] 
    namespace = metadata[namespace_key] 
    rev = metadata[version_key]
    namespace = @my_GlueEnv.user_datastore_id unless namespace
    id = @my_GlueEnv.generate_model_key(namespace, node_key)  unless id
    updated_key_metadata = {model_key => id, namespace_key => namespace}
    updated_key_metadata.delete(version_key) unless rev 
    metadata.merge!(updated_key_metadata)
    if rev 
      @saved_to_model = rev 
      metadata.merge!({version_key => rev}) 
    else
      metadata.delete(version_key)  #TODO  Is this too model specific?
    end
    metadata
  end


  def inject_node_metadata
    inject_metadata(@_user_data)
  end

  def inject_metadata(node_data)
    node_data.merge(@_model_metadata)
  end

  def update_self(rev_data)
    self._model_metadata.merge!(rev_data)
    version_key = @my_GlueEnv.version_key 
    @saved_to_model = rev_data[version_key]
  end

end

