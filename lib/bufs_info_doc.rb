#common libraries
require 'couchrest'
require 'monitor'


#bufs libraries
require File.dirname(__FILE__) + '/bufs_info_attachment'
require File.dirname(__FILE__) + '/bufs_info_link'
require File.dirname(__FILE__) + '/bufs_escape'
require File.dirname(__FILE__) + '/node_element_operations'



#TODO: Move this module to a more centralized place since it will
#      be used by any of the node based classes
=begin
module NodeElementOperations
  #TODO the hash inside the proc is confusing (the curly braces) update to better readability
  MyCategoryAddOp = lambda {|this,other|   Hash[:update_this => this]  } #my cat is not allowed to change
  MyCategorySubtractOp = lambda{ |this, other| Hash[:update_this => this] } #TODO use this to delete a node?
  MyCategoryOps = {:add => MyCategoryAddOp, :subtract => MyCategorySubtractOp}
  ParentCategoryAddOp = lambda {|this,other| 
                           this = this + [other].flatten
                           this.uniq!; this.compact!
                           Hash[:update_this => this]
                         }
  ParentCategorySubtractOp = lambda {|this,other| this -= [other].flatten!; this.uniq!; this.compact!; Hash[:update_this => this] }
  ParentCategoryOps = {:add => ParentCategoryAddOp, :subtract => ParentCategorySubtractOp}
  LinkAddOp = lambda {|this, other|
                                 this = this || {}  #investigate why its passed as nil (probably hasn't been built yet
                                 srcs = other.keys
                                 srcs.each {|s| if this[s]
                                            this[s] = [ other[s] ].flatten
                                           else
                                            this[s] = [ other[s] ].flatten
                                           end
                                           this[s].uniq!
                                           this[s].compact!
                                  }
                           { :update_this => this }
                         }
  #if link_name is used besides other, then all link_names would need to be unique, so we use other
  LinkSubtractOp = lambda {|this, other| srcs = other.keys
                                         srcs.each { |s| this[s].delete(other[s]) 
                                                    this.delete(s) if this[s].empty?
                                              }
                                         { :update_this => this }
                           }
  #think if this is what you want, returning a single uri if only one exists, while an array if more than one?
  #I think so since it's *almost* an error case if more than one url exists for a name, but I'm not sure this is the best approach
  LinkGetOp = lambda {|this, link_name| 
                                       this_ary = this.to_a
                                       puts "From LinkGetOp: this_ary: #{this_ary.inspect}"
                                       return {:return_value => nil, :update_this => this} unless this_ary.flatten.include? link_name
                                       srcs = []
                                       this_ary.each { |s, ls| srcs << s if ls.include? link_name }
                                       return {:return_value => srcs } if srcs.size > 1
                                       return {:return_value => srcs.first} if srcs.size i== 1
                     }

  LinkOps = {:add => LinkAddOp, :subtract => LinkSubtractOp, :get => LinkGetOp}
                          
  Ops = {:my_category => MyCategoryOps, :parent_categories => ParentCategoryOps, :link => LinkOps}
end
=end

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
      #ok raise design_doc.inspect
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
      #raise "set_view_all: #{design_doc.inspect
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
      #ok raise design_doc.inspect
      #raise view_name if view_name == :parent_categories
    @@monitor.synchronize {
      #raise view_name if view_name == :parent_categories
      #TODO: Add options for custom maps, etc
      #creating view in design_doc
      design_doc.view_by view_name.to_sym, opts
      #design_doc['_rev'] = nil 
      #ok raise "View Name: #{view_name} \n Des Doc: #{design_doc.inspect}" unless (view_name == "all_bufs" || view_name.to_s == "my_category")
      db_view_name = "by_#{view_name}"
      views = design_doc['views'] || {}
      view_keys = views.keys || []
      unless view_keys.include? db_view_name
        design_doc['_rev'] = nil
      end
      #ok raise "DesDoc: #{design_doc.inspect}  view: #{db_view_name}"
      begin
        view_rev_in_db = db.get(design_doc['_id'])['_rev']
        res = design_doc.save unless design_doc['rev'] == view_rev_in_db
      rescue RestClient::RequestFailed
        puts "Warning: Request Failed, assuming because the design doc was already saved?"
        puts "doc_rev: #{design_doc['_rev'].inspect}"
        puts "db_rev: #{view_rev_in_db}"
      end
      #ok raise design_doc.inspect
    }  
  end

end

#TODO: Move out the model specific  aspects into a seperate module
#TODO: Use as a generic class for all models
#This is the abstract class used.  Each user would get a unique
#class derived from this one.  In other words, a class context
#is specific to a user.  [User being used loosely to indicate a client-like relationship]
class BufsInfoDoc

  #TODO Move Mgr Classes to a model specific module  

  #The file handling is bound to the model, and can't be abstracted away. This means files can't be handled
  #via the dynamic methods used for other data structures.
  #models that will handle data files (whether filesystem files or attachments)
  #must provide a method called files_mgr that provides an object that can add from a file, add from raw data
  #and subtract (i.e.) delete the file from the model. These functions must be implemented
  #by the following named methods.
      # .add_file(add_file_hashes)      -> adds file data from a file on the local file system (to this program)
      # .add_raw_data(raw_data_hashes)  -> creates a file in the model from the raw data provided
      # .subtract(filename_keys)        -> removes the file and metadata associated with the model_filename matching filename keys
      # .list_files
      # .get_file(filename_key)

      # add_file_hash = { :model_filename => filename stored in model, (defaults to src_filename's basename)
      #                   :src_filename => source filename,  (either src_filename or raw_data must be provided)
      #                   :content_type => :mime content type for the file (derived from file extension defaults to TBD if no extension}
      #                 }

      # raw_data_hash = { :model_filename => filename stored in model, (required)
      #                   :src_data => source data, (the data to be stored in the file,
      #                   :content_type => :mime content type for the file (required)
      #                 }
      #
      # filename_key = model_filenames to delete

  #TODO Make thread safe
  class FilesMgr
    #class << self; attr_accessor :model_mgrClass; end
    #@model_mgrClass = nil  #FIXME: Not needed for every model?  How to abstract then?

    attr_accessor :model_actor, :record_ref
    #TODO: after class is functionally complete, evaluate if model_actor is needed
    def initialize(model_actor) #provides the model actor that can manage files
      @model_actor = model_actor
      @record_ref = nil #id for files container
    end

    def add_files(node, file_datas)
      bia_class = @model_actor[:attachment_actor_class]
      attachment_package = {}
      file_datas = [file_datas].flatten
      file_datas.each do |file_data|
        #get file data
        src_filename = file_data[:src_filename]
        src_basename = File.basename(src_filename)
        raise "File data must include the source filename when adding a file to the model" unless src_filename
        model_basename = file_data[:model_basename] || src_basename
        model_basename.gsub!('+', ' ')  #plus signs are problematic
        #TODO: Consider creating BufsEscape.unescape method
        model_basename = CGI.unescape(model_basename)
        content_type = file_data[:content_type] || MimeNew.for_ofc_x(model_basename)
        modified_time = file_data[:modified_time] || File.mtime(src_filename).to_s
        #create attachment class data structure
        file_metadata = {}
        file_metadata['content_type'] = content_type
        file_metadata['file_modified'] = modified_time
        #read in file
        #TODO: reading the file in this way is memory intensive for large files, chunking it up woudl be better
        file_data = File.open(src_filename, "rb") {|f| f.read}
        attachment_package[model_basename] = {'data' => file_data, 'md' => file_metadata}
      end
      #attachment package has now been created
      #create the attachment record
      #TODO: What if the attachment already exists?
      user_id = node.class.db_user_id
      node_id = node.model_metadata['_id']
      record = bia_class.add_attachment_package(node, attachment_package)
      @record_ref = record['_id']
    end

    def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
      bia_class = @model_actor[:attachment_actor_class]
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
      bia = bia_class.get(node.my_attachment_doc_id)
      record = bia_class.add_attachment_package(node, attachment_package)
      @record_ref = record['_id']
    end

    #TODO  Document the :all shortcut somewhere
    def subtract_files(node, model_basenames)
      bia_class = @model_actor[:attachment_actor_class]
      if model_basenames == :all
        subtract_all(node, bia_class)
      else
        subtract_some(node, model_basenames, bia_class)
      end
    end

    def list_files(node)
      return nil unless node.attachment_doc_id
      bia_class = @model_actor[:attachment_actor_class]
      rtn = if node.attachment_doc_id
        bia_doc = bia_class.get(node.attachment_doc_id)
        bia_doc.get_attachments
      end
      rtn
    end

    def list_file_keys(node)
       return nil unless node.attachment_doc_id
       atts = list_files(node)
       p atts
       rtn = atts.keys
    end
    #TODO: make private
    def subtract_some(node, model_basenames, bia_class)
      if node.attachment_doc_id
        bia_doc = bia_class.get(node.attachment_doc_id)
        bia_doc.remove_attachment(model_basenames)
        rem_atts = bia_doc.get_attachments
        subtract_all(node, bia_class) if rem_atts.empty?
      end
    end
    #TODO: make private
    def subtract_all(node, bia_class)
      #delete the attachment record
      doc_db = node.class.db
      if node.attachment_doc_id
        attach_doc = doc_db.get(node.attachment_doc_id)
        doc_db.delete_doc(attach_doc)
        node.iv_unset(:attachment_doc_id)
        node.save
      else
        puts "Warning: Attempted to delete attachments when none existed"
      end
      node
    end
  end

  #TODO Make thread safe
  class ViewsMgr
    attr_accessor :model_actor


    def initialize(model_actor)
      @model_actor = model_actor #provides the model actor that can provide views
    end

    ## CouchDB View Definitions
    #CouchDB uses a map/reduce structure using javascript
    #map is essentially a query and reduce is a way of aggregating
    #the query into summary type of information (example: summing records)

    #Note this couples the model (CouchDB) and the parameter (my_category).  In other words
    #this presupposes my_category should exist in the model, rather than inferring how to construct
    #the view from the fact that my_category was used (I don't think the latter is possible for views)
    def by_my_category(collection_namespace, match_key)

      #TODO
      #TODO My views are screwed up, the match_keys are part of the query, not the view
      #TODO Further more to match multiple keys requires a modified view, see http://books.couchdb.org/relax/design-documents/views
      #TODO the couchdb book update I think most is cleaned up, but figure out where constructor goes for nodes
      #TODO
      #match_keys = [match_keys].flatten
      #match_str = "&& ("
      #match_keys.each do |k|
      #  match_str += "doc.my_category == '#{k}' || "
      #end
      #match_str += "null)"
      map_str = "function(doc) {
                     if (doc.bufs_namespace =='#{collection_namespace}' && doc.my_category ){
                       emit(doc.my_category, doc);
                    }
                 }"
      map_fn = { :map => map_str }
      BufsInfoDocEnvMethods.set_view(@model_actor[:db], @model_actor[:design_doc], :my_category, map_fn)
      puts "Match Key: #{match_key}"
      raw_res = @model_actor[:design_doc].view :by_my_category, :key => match_key
      #puts "By My Category Response:"
      rows = raw_res["rows"]
      records = rows.map{|r| r["value"]}
    end


  def by_parent_categories(collection_namespace, match_keys)
    #match_keys = [match_keys].flatten
    #match_str = ""
    #match_keys.each do |k|
    #  match_str += "cat == '#{k}' || "
    #end
    #match_str.gsub!(/\|\|\s$/, "") #removes the extra stuff at the end from the iterator

    
    map_str = "function(doc) {
                  if (doc.bufs_namespace == '#{collection_namespace}' && doc.parent_categories) {
                         emit(doc.parent_categories, doc);
                      };
                  };"
            #   }"
    map_fn = { :map => map_str }
    
    BufsInfoDocEnvMethods.set_view(@model_actor[:db], @model_actor[:design_doc], :parent_categories, map_fn)
    raw_res = @model_actor[:design_doc].view :by_parent_categories
    rows = raw_res["rows"]
    records = rows.map{|r| r["value"] if r["value"]["parent_categories"].include? match_keys}
    #raise "Keys #{match_keys.inspect} Records: #{records.inspect}"
  end

  end 
 
#TODO Figure out a way to distinguish method calls from dynamically set data
# that were assigned as instance variables
  include BufsInfoDocEnvMethods
  AttachmentBaseID = "_attachments"
  LinkBaseID = "_links"

  ##Class Accessors
  class << self; attr_accessor :db_user_id,
                               :db,
                               :collection_namespace,
                               :design_doc,
                               :query_all,
                               :db_metadata_keys,
                               :namespace,
                               :files_mgr,
                               :views_mgr
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
    @files_mgr = FilesMgr.new(:attachment_actor_class => self.user_attachClass)
    @views_mgr = ViewsMgr.new(:db => @db, :design_doc => @design_doc)
    return @namespace 
  end

  
  def self.files_mgr
    @files_mgr
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
  #The view her
  def self.call_view(param, match_keys)
     view_method_name = "by_#{param}".to_sym #using CouchDB style for now
     #If the views_mgr object has a view for this parameter then use it
     records = if self.views_mgr.respond_to? view_method_name
       #TODO Make distinction clearer between namespace and collection_namespace
       self.views_mgr.__send__(view_method_name, self.collection_namespace, match_keys)
       #puts "NAMESPACE: #{self.namespace}"
     else
       #TODO: Think of a more elegant way to handle an unknown view
       raise "Unknown design view #{view_method_name} called for: #{param}"
     end
     nodes = records.map{|r| self.new(r)}
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
    lambda {|other| this = self.__send__("#{param}".to_sym) #original value
                    #orig = self.__send__("#{param}".to_sym)
                    #rtn_data = self.__send__("#{param}=".to_sym, unbound_op.call(this, other))
                    rtn_data = unbound_op.call(this, other)
                    new_this = rtn_data[:update_this]
                    self.__send__("#{param}=".to_sym, new_this)
                    save = true
                    save = false if (this == new_this)
                    #self.save unless (@saved_to_model && save) #don't save if the value hasn't changed
                    self.save #FIXME: 
                    rtn = rtn_data[:return_value] || rtn_data[:update_this]
                    puts "from wrapper: #{rtn.inspect} Saved: #{save.inspect}"
                    rtn
           }
  end

  def iv_unset(param)
    self.class.__send__(:remove_method, param.to_sym)
    @node_data_hash.delete(param)
  end

  #some object convenience methods for accessing class methods
  def files_mgr
    self.class.files_mgr
  end

  #def links_mgr
  #  self.class.links_mg
  #end

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
    if self.model_metadata['_id']
      return self.model_metadata['_id'] + self.class.attachment_base_id
    else
      raise "Can't attach to a document that has not first been saved to the db"
    end
  end

  def get_attachment_names
    self.class.files_mgr.list_file_keys(self)
  end

  #Get attachment content.  Note that the data is read in as a complete block, this may be something that needs optimized.
  #TODO: add_raw_data parameters to a hash?
  def add_raw_data(attach_name, content_type, raw_data, file_modified_at = nil)
    self.class.files_mgr.add_raw_data(self, attach_name, content_type, raw_data, file_modified_at = nil)
  end

  def files_add(file_data)
    attach_id = self.class.files_mgr.add_files(self, file_data)
    self.iv_set(:attachment_doc_id, attach_id)
    self.save
  end

  def files_subtract(file_basenames)
    self.class.files_mgr.subtract_files(self, file_basenames)
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
=begin
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
=end
  #Deletes the object and its CouchDB entry
  def destroy_node
    #att_doc = self.class.get(self.files_mgr.record_ref) if self.files_mgr.record_ref
    att_doc = self.class.user_attachClass.get(self.attachment_doc_id) if self.attachment_doc_id
    att_doc.destroy if att_doc
    #link_doc = self.class.get(self.links_doc_id)
    #link_doc.destroy if link_doc
    begin
      self.destroy
    rescue ArgumentError => e
      puts "Rescued Error: #{e} while trying to destroy #{self.my_category} node"
      me = self.class.get(self.model_metadata['_id'])
      me.destroy
    end
  end

  def destroy
    self.class.db.delete_doc('_id' => self.model_metadata['_id'], '_rev' => self.model_metadata['_rev'])
  end
end

