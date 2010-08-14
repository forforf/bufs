#common libraries
require 'couchrest'
require 'monitor'

#bufs libraries
require File.dirname(__FILE__) + '/bufs_info_attachment'
require File.dirname(__FILE__) + '/bufs_info_link'
require File.dirname(__FILE__) + '/bufs_escape'

#TODO: Move this module to a more centralized place since it will
#      be used by any of the node based classes
module NodeElementOperations
  MyCategoryAddOp = lambda {|this,other| this} #my cat is not allowed to change
  MyCategorySubtractOp = lambda{ |this, other| this} #TODO use this to delete a node?
  MyCategoryOps = {:add => MyCategoryAddOp, :subtract => MyCategorySubtractOp}
  ParentCategoryAddOp = lambda {|this,other| 
                           this = this + [other].flatten
                           this.uniq!; this.compact!
                           this
                         }
  ParentCategorySubtractOp = lambda {|this,other| this -= [other].flatten!; this.uniq!; this}
  ParentCategoryOps = {:add => ParentCategoryAddOp, :subtract => ParentCategorySubtractOp}
  Ops = {:my_category => MyCategoryOps, :parent_categories => ParentCategoryOps}
end

module BufsInfoDocEnvMethods
  ##Uncomment all mutexs and monitors for thread safety for this module (untested)
  #TODO Test for thread safety
  @@mutex = Mutex.new
  @@monitor = Monitor.new
  include CouchRest::Mixins::Views::ClassMethods
  #Class Environment
  
  #Sets the specific environment needed for this particular class.
  #The goal is to have the class environment completed abstracted from the
  #operations (i.e. methods) of the class. Perfect abstraction would yield
  #a model class that could be readily applied to differnt models, and perhaps 
  #eliminate the need for an abstract class to encapsulate the modesl (the current approach) 
  #The class variables should be able to be reused across all models (yet to be seen if this is possible)
  #The structure of the environment is a hash (which can contain multiple class environments)
  #           { env_name => env_options_for_that_particular_class }
  #
  # Thus all classes would have a set_environment class method, but each class would have its own
  # environmental variables and structures

  def self.set_db_location(couch_db_host, db_name_path)
    @@mutex.synchronize {
      couch_db_host.chop if couch_db_host =~ /\/$/ #removes any trailing slash
      db_name_path = "/#{db_name_path}" unless db_name_path =~ /^\// #check for le
      couch_db_location = "#{couch_db_host}#{db_name_path}"
    }
  end

  #assigns a unique namespace to the collection of nodes belonging to this class
  def self.set_collection_namespace(db_name_path, db_user_id)
    @@mutex.synchronize {
      lose_leading_slash = db_name_path.split("/")
      lose_leading_slash.shift
      db_name = lose_leading_slash.join("")
      collection_namespace = "#{db_name}_#{db_user_id}"
    }
  end

  def self.set_namespace(db, db_user_id)
    @@mutex.synchronize {
      namespace = "#{db.to_s}::#{db_user_id}"
    }
  end

  def self.set_couch_design(db) #, view_name)
    @@mutex.synchronize {
      design_doc = CouchRest::Design.new
      design_doc.name = self.to_s + "_Design"
      #example of a map function that can be passed as a parameter if desired (currently not needed)
      #map_function = "function(doc) {\n  if(doc['#{@@collection_namespace}']) {\n   emit(doc['_id'], 1);\n  }\n}"
      #design_doc.view_by collection_namespace.to_sym #, {:map => map_function }
      design_doc.database = db
      begin
        design_doc = db.get(design_doc['_id'])
      rescue RestClient::ResourceNotFound
        design_doc.save
      end
      #self.set_view_all(db, design_doc)
      design_doc
    }
  end

  def self.set_view_all(db, design_doc, db_namespace)
    @@monitor.synchronize {
      view_name = "all_bufs"
      namespace_id = "bufs_namespace"
      map_str = "function(doc) {
                    if (doc['#{namespace_id}'] == '#{db_namespace}') {
                       emit(doc['_id'], doc);
                    }
                 }"
      map_fn = { :map => map_str } #returned from synced block
      self.set_view(db, design_doc, view_name, map_fn)
    }
  end

  def self.set_db_metadata_keys #(collection_namespace)
    db_metadata_keys = ['_id', '_rev', '_pos', '_deleted_conflicts', 'bufs_namespace']
  end

  #TODO: this is a bit convoluted to just return the query string, simplify.
  def self.query_for_all_collection_records(collection_namespace)
    "by_all_bufs".to_sym
  end

  def self.set_view(db, design_doc, view_name, opts={})
      #raise view_name if view_name == :parent_categories
    @@monitor.synchronize {
      #raise view_name if view_name == :parent_categories
      #TODO: Add options for custom maps, etc
      design_doc.view_by view_name.to_sym, opts
      #design_doc['_rev'] = nil 
      #raise "View Name: #{view_name} \n Des Doc: #{design_doc.inspect}" unless (view_name == "all_bufs" || view_name.to_s == "my_category")
      #db_view_name = "by_#{view_name}"
      #unless design_doc['views'].keys.include? db_view_name
      #  design_doc['_rev'] = nil
      #end
      begin
        view_rev_in_db = db.get(design_doc['_id'])['_rev']
        res = design_doc.save unless design_doc['rev'] == view_rev_in_db
      rescue RestClient::RequestFailed
        puts "Warning:: Request Failed, assuming because the design doc was already saved"
        puts "doc_rev: #{design_doc['_rev'].inspect}"
        puts "db_rev: #{view_rev_in_db}"
      end
    }  
  end

end


#TODO: Move out the generic aspects into a seperate module
#This is the abstract class used.  Each user would get a unique
#class derived from this one.  In other words, a class context
#is specific to a user.  [User being used loosely to indicate a client-like relationship]
class BufsInfoDoc 
#TODO Figure out a way to distinguish method calls from dynamically set data
# that were assigned as instance variables
  include BufsInfoDocEnvMethods
  AttachmentBaseID = "_attachments"
  LinkBaseID = "_links"

  ##Class Accessors
  class << self; attr_accessor :db_uder_id,
                               :db,
                               :collection_namespace,
                               :design_doc,
                               :query_all,
                               :db_metadata_keys,
                               :namespace
  end

  ##Instance Accessors
  attr_accessor :node_data_hash, :model_metadata, :saved_to_model

  ###Class Methods
  ##Class Environment
  def self.set_environment(env)
    #BufsInfoDocEnvMethods.set_environment(env)
    env_name = :bufs_info_doc_env  #"#{self.to_s}_env".to_sym  <= (same thing but not needed yet)
    couch_db_host = env[env_name][:host]
    db_name_path = env[env_name][:path]
    db_user_id = env[env_name][:user_id]
    @db_user_id = db_user_id
    couch_db_location = BufsInfoDocEnvMethods.set_db_location(couch_db_host, db_name_path)
    @db = CouchRest.database!(couch_db_location)
    @collection_namespace = BufsInfoDocEnvMethods.set_collection_namespace(db_name_path, db_user_id)
    @design_doc = BufsInfoDocEnvMethods.set_couch_design(@db)#, @collection_namespace)
    @query_all = BufsInfoDocEnvMethods.query_for_all_collection_records(@collection_namespace)
    @db_metadata_keys = BufsInfoDocEnvMethods.set_db_metadata_keys #(@collection_namespace)
    @namespace = BufsInfoDocEnvMethods.set_namespace(@db, db_user_id)
    BufsInfoDocEnvMethods.set_view_all(@db, @design_doc, @collection_namespace)
    return @namespace 
  end

  ##Associated Classes (e.g., for attachments)
  #This should be defined in the dynamic class definition
  #The default value here is for teting basic functionality
  def self.user_attachClass
    BufsInfoAttachment #this should be overwritten
  end

  #This should be defined in the dynamic class definition
  #The default value here is for teting basic functionality
  def self.user_linkClass
    BufsInfoLink  #this should be overwritten
  end

  ##Collection Methods
  #This returns all db records, but does not create
  #an instance of this class for each record.  Each record is provided
  #in its native form.
  def self.all_native_records
    #query db
    raw_res = self.design_doc.view self.query_all
    raw_data = raw_res["rows"]
    records = raw_data.map {|d| d['value']}#puts "raw_datum: #{d.inspect}"}
  end

  #convert collection of CouchRest::Document into a
  #collection of this class
  def self.all
    nodes = self.all_native_records
    nodes.map! {|n| self.new(n)}
  end

  ## CouchDB View Creation
  #View as it is referred to here is a query to the underlying model
  #and structures the way the result is returned from the model.
  #The view here magically uses a couple of class methods, but I'm not sure how to get around that yet
  #FIXME: This binds the model and the data, and I can't figure out a way to unbind it
  #Thus its cluttering up the class. The bindings of dynamic data to the map/reduce creation
  #make it problematic to decouple and abstract
  def self.call_view(param, match_keys)
     #the type of view depends on the paramter type
     #note also that the type of model (CouchDB in this case)
     #dictates the structure of the view query
     case param
     when :my_category
       self.by_my_category(self.collection_namespace, match_keys)
     when :parent_categories
       self.by_parent_categories(self.collection_namespace, match_keys)
     else
       #TODO: Think of a more elegant way to handle an unknown view
       raise "Unknown design view called for: #{param}"
     end
  end

  ## CouchDB View Definitions
  #CouchDB uses a map/reduce structure using javascript
  #map is essentially a query and reduce is a way of aggregating
  #the query into summary type of information (example: summing records)
  def self.by_my_category(namespace, match_keys)
    match_keys = [match_keys].flatten
    match_str = "&& ("
    match_keys.each do |k|
      match_str += "doc.my_category == '#{k}' || "
    end
    match_str += "null)"
    map_str = "function(doc) {
                  if (doc['bufs_namespace']=='#{namespace}' && doc.my_category #{match_str}) {
                    emit(doc['_id'], doc);
                  }
               }"
    map_fn = { :map => map_str }
    BufsInfoDocEnvMethods.set_view(self.db, self.design_doc, :my_category, map_fn)
    raw_res = self.design_doc.view :by_my_category, map_fn
    #puts "By My Category Response:"
    rows = raw_res["rows"]
    records = rows.map{|r| r["value"]}
  end
  #
  def self.by_parent_categories(namespace, match_keys)
    match_keys = [match_keys].flatten
    match_str = ""
    match_keys.each do |k|
      match_str += "cat == '#{k}' || "
    end
    match_str.gsub!(/\|\|\s$/, "") #removes the extra stuff at the end from the iterator
    map_str = "function(doc) {
                  if (doc['bufs_namespace'] == '#{namespace}' && doc.parent_categories) {
                     doc.parent_categories.forEach(function(cat){
                        if (#{match_str}) {
                            emit(doc['_id'], doc);
                        }
                      });
                  };
               }"
    map_fn = { :map => map_str }
    BufsInfoDocEnvMethods.set_view(self.db, self.design_doc, :parent_categories, map_fn)
    raw_res = self.design_doc.view :by_parent_categories, map_fn
    rows = raw_res["rows"]
    #TODO Move the uniq funtion to a reduce function in CouchDB
    records = rows.map{|r| r["value"]}.uniq
  end


  def self.get(id)
    #maybe put in some validations to ensure its from the proper collection namespace?
    rtn = begin
      data = self.db.get(id)
      self.new(data)
    rescue RestClient::ResourceNotFound => e
      nil
    end
    rtn
  end

  #This destroys all nodes in the model
  #this is more efficient than calling
  #destroy on instances of this class
  #as it avoids instantiating only to destroy it
  def self.destroy_all
    all_records = self.all_native_records
    all_records.each do |record|
      self.db.delete_doc(record)
    end
    ##The below  might work if 'couchrest-type' is used
    #all_docs.each {|doc| doc.destroy} 
    nil
  end

  #I can't figure out how to abstract the queries on collections
  #to be either model independent or parameter independent.
  #Each model has different ways of querying collections, and different paramter
  #data structures need to be mapped in different ways.
  

  ##Class methods 
  #Create the document in the BUFS node format from an existing node.  A BUFS node is an object that has the following properties:
  #  my_category
  #  parent_categories
  #  description
  #  attachments in the form of data files
  #
  #TODO If this is handled in the base models then each base model should
  #have a common way of providing the collection of parameters
  #rather than this hard coded version.
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

   #TODO move these to accessor style
  #Returns the id that will be appended to the document ID to uniquely
  #identify attachment documents associated with the main document
  def self.attachment_base_id
    AttachmentBaseID 
  end

  #Returns the id that will be appended to the document ID to uniquely
  #identify link documents associated with the main document
  def self.link_base_id
    LinkBaseID 
  end

  def initialize(init_params = {})
    @saved_to_model = nil
    #make sure keys are symbols
    init_params = init_params.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

    raise "No namespace has been set for #{self}" unless self.class.namespace
    raise ArgumentError, "Requires a category to be assigned to the instance" unless init_params[:my_category]
    #CouchDB metadata
    node_id = self.class.db_id(init_params[:my_category])
    #TODO Find a way to genericize this across models
    @model_metadata = { '_id' => node_id, 'bufs_namespace' => "#{self.class.collection_namespace}"} #'_rev' => rev}
    if init_params[:_rev]
      @saved_to_model = init_params[:_rev]
      @model_metadata.merge!({'_rev' => init_params[:_rev]})
    end
    @node_data_hash = {}
    init_params.each do |attr_name, attr_value|
      iv_set(attr_name.to_sym, attr_value) 
    end
  end

  def iv_set(attr_var, attr_value)
    ops = NodeElementOperations::Ops
    add_op_method(attr_var, ops[attr_var]) if ops[attr_var] #incorporates predefined methods
    @node_data_hash[attr_var] = attr_value unless self.class.db_metadata_keys.include? attr_var.to_s
    #manually setting instance variable, so @node_data_hash can be updated
    #dynamic method acting like an instance variable getter
    self.class.__send__(:define_method, "#{attr_var}".to_sym,
       lambda {@node_data_hash[attr_var]} )
    #dynamic method acting like an instance variable setter
    self.class.__send__(:define_method, "#{attr_var}=".to_sym,
       lambda {|new_val| @node_data_hash[attr_var] = new_val} )
    #create view not quite working as I want yet
    #create_view(attr_var)
  end
     
  def add_op_method(param, ops)
       ops.each do |op_name, op_proc|
         method_name = "#{param.to_s}_#{op_name.to_s}".to_sym
         #puts method_name

         wrapped_op = method_wrapper(param, op_proc)
         self.class.__send__(:define_method, method_name, wrapped_op)
       end
  end  

  def method_wrapper(param, unbound_op)
    #What I want is to call obj.param_op(other)   example: obj.links_add(new_link)
    #which would then add new_link to obj.links
    #however, the predefined operation (add in the example) has no way of knowing
    #about links, so the predefined operation takes two parameters (this, other)
    #and this method wraps the obj.links so that the links_add method doesn't have to
    #include itself as a paramter to the predefined operation
    #lambda {|other| @node_data_hash[param] = unbound_op.call(@node_data_hash[param], other)}
    lambda {|other| orig = self.__send__("#{param}".to_sym)
                    new = self.__send__("#{param}=".to_sym, unbound_op.call(self.__send__("#{param}".to_sym), other))
                    self.save unless (@saved_to_model && orig == new)
           }
  end

  #Save the object to the CouchDB database
  def save
    #puts "Saving"
    raise ArgumentError, "Requires my_category to be set before saving" unless self.my_category
    existing_doc = self.class.get(self.db_id)
    begin
      res = self.class.db.save_doc(inject_node_db_metadata)
    rescue RestClient::RequestFailed => e
      if e.http_code == 409
        raise "Document Conflict in the Database, most likely. Error Code was 409, however my handling routine needs to be updated to new architecture"
        puts "Found existing doc (id: #{self.db_id} while trying to save ... using it instead"
        existing_doc.parent_categories = (existing_doc.parent_categories + self.parent_categories).uniq
        existing_doc.description = self.description if self.description
        #TODO: Update the below to the new class scheme
        existing_doc['_attachments'] = existing_doc['attachments'].merge(self['_attachments']) if self['_attachments']
        existing_doc['file_metadata'] = existing_doc['file_metadata'].merge(self['file_metadata']) if self['file_metadata']
        existing_doc.save
        return existing_doc
      else
        raise e
      end
    end
      rev_data = {"_rev" => res['rev']}
      update_self(rev_data)
      #self.model_metadata.merge!(rev_data)
    return self
  end

  def create_view(param)
    BufsInfoDocEnvMethods.set_view(self.class.db, self.class.design_doc, param)
  end

  #TODO: This is not being tested and currently it doesn't do anything
  #def destroy
  #  puts "Destroy Method Size: #{BufsInfoDoc.all.size}"
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
  #TODO: 
  def my_attachment_doc_id
    if self['_id']
      return self['_id'] + self.class.attachment_base_id
    else
      raise "Can't attach to a document that has not first been saved to the db"
    end
  end

  def get_attachment_names
    att_doc_id = self.class.get(self['_id']).attachment_doc_id
    att_doc = self.class.get(att_doc_id)||{}
    attachments = att_doc['_attachments']||{}
    att_names = attachments.keys
  end

  #Get attachment content.  Note that the data is read in as a complete block, this may be something that needs optimized.
  def add_raw_data(attach_name, content_type, raw_data, file_modified_at = nil)
    file_metadata = {}
    if file_modified_at
      file_metadata['file_modified'] = file_modified_at
    else
      file_metadata['file_modified'] = Time.now.to_s
    end
    file_metadata['content_type'] = content_type #TODO: is unknown content handled gracefully?
    attachment_package = {}
    unesc_attach_name = BufsEscape.unescape(attach_name)
    attachment_package[unesc_attach_name] = {'data' => raw_data, 'md' => file_metadata}
    bia = self.class.user_attachClass.get(self.my_attachment_doc_id)
    if bia
      bia.update_attachment_package(self, attachment_package)
    else
      bia = self.class.user_attachClass.create_attachment_package(self, attachment_package)
    end

    current_node_doc = self.class.get(self['_id'])
    current_node_doc.attachment_doc_id = bia['_id']
    current_node_attach = self.class.user_attachClass.get(current_node_doc.attachment_doc_id)
    current_node_attach.save
  end

  #Add an attachment to the BufsInfoDoc object from a file
  def add_data_file(attachment_filenames)
    #TODO: Ok to do silent returns here?
    return if attachment_filenames.nil?
    return if attachment_filenames.empty?
    attachment_package = {}
    attachment_filenames = [attachment_filenames].flatten
    attachment_filenames.each do |at_f|
      at_basename = File.basename(at_f)
      #basename can't contain '+', replace with space
      at_basename.gsub!('+', ' ')
      file_metadata = {}
      file_metadata['file_modified'] = File.mtime(at_f).to_s
      file_metadata['content_type'] = MimeNew.for_ofc_x(at_basename)
      file_data = File.open(at_f, "rb"){|f| f.read}
      ##{at_basename => {:file_modified => File.mtime(at_f)}}
      #Unescaping '+' to space  because CouchDB will escape it leading to space -> + -> %2b
      unesc_at_basename = BufsEscape.unescape(at_basename)
      attachment_package[unesc_at_basename] = {'data' => file_data, 'md' => file_metadata}
    end
    #getting attachment doc id
    attachment_record = self.class.user_attachClass.get(my_attachment_doc_id)
    if attachment_record
      #puts "Updating Attachment"
      attachment_record.update_attachment_package(self, attachment_package)
    else
      #puts "Creating new Attachment"
      attachment_record = self.class.user_attachClass.create_attachment_package(self, attachment_package)
    end

    current_node_doc = self.class.get(self['_id'])
    current_node_doc.attachment_doc_id = attachment_record['_id']
    current_node_doc.save
    current_node_attach = self.class.user_attachClass.get(current_node_doc.attachment_doc_id)
    current_node_attach.save
  end

  def remove_attachments  #Spec is in user_doc_spec
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc.delete('attachment_doc_id')
    current_node_doc.save
    current_node_attach = self.class.user_attachClass.get(att_doc_id)
    current_node_attach.destroy
  end


  def remove_attachment(attachment_name)
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc['attachment_doc_id']
    current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
    current_node_attachment_doc['md_attachments'].delete(attachment_name)
    current_node_attachment_doc.delete_attachment(attachment_name)
    current_node_attachment_doc.save
  end

#TODO: Add to spec (currently not used)
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

  #TODO: move to class method section
  def self.db_id(node_id)
    @collection_namespace + '::' + node_id
  end

  def db_id
    self.class.db_id(self.my_category)
  end
  
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

  def inject_node_db_metadata
    inject_db_metadata(@node_data_hash)
  end

  def inject_db_metadata(node_data)
    node_data.merge(@model_metadata)
    #node_data.delete('_rev')
    #node_data
  end

  def update_self(rev_data)
    self.model_metadata.merge!(rev_data)
    @saved_to_model = rev_data["_rev"]
  end

  def my_link_doc_id
    return self['_id'] + self.class.link_base_id
  end


  def add_links(links)
    self.links_doc_id = self.my_link_doc_id  
    self.save
    self.class.user_linkClass.add_links(self, links)
  end

  def remove_links(links_to_remove)
    self.links_doc_id = self.my_link_doc_id
    self.save
    self.class.user_linkClass.remove_links(self, links_to_remove)
  end

  def get_link_names
    link_doc_id = self.class.get(self['_id']).links_doc_id
    link_doc = self.class.get(link_doc_id)||{}
    links = link_doc['uris']||{}
    #new_links = {} 
    #if links.class != Hash  #TODO: fix db to get rid of back compat hack
    #  links.each {|lnk| new_links[lnk] = nil}
    #else
    #  new_links = links
    #end
    #raise links.inspect
    link_names = links #new_links
  end

  alias_method(:list_links, :get_link_names) #TODO: synchronize with bufs_file_system

  #Deletes the object and its CouchDB entry
  def destroy_node
    att_doc = self.class.get(self.attachment_doc_id)
    att_doc.destroy if att_doc
    link_doc = self.class.get(self.links_doc_id)
    link_doc.destroy if link_doc
    begin
      self.destroy
    rescue ArgumentError => e
      puts "Rescued Error: #{e} while trying to destroy #{self.my_category} node"
      me = self.class.get(self['_id'])
      me.destroy
    end
  end
end

