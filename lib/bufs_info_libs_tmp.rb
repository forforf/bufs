require 'couchrest'
require 'monitor'
require File.dirname(__FILE__) + '/bufs_info_attachment'
require File.dirname(__FILE__) + '/bufs_info_link'


#bufs libraries
require File.dirname(__FILE__) + '/node_element_operations'

module DataStoreModels
  module CouchRest

  AttachmentBaseID = "_attachments"
  LinkBaseID = "_links"


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
      #                   :content_type => :mime content type for the file (derived from file extension defaults to TBD if no extension
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
      @record_ref = nil #id for files container  #PROBLEM - 
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
      user_id = node.class.class_env.db_user_id
      node_id = node.model_metadata[:_id]
      record = bia_class.add_attachment_package(node, attachment_package)
      if node.respond_to? :attachment_doc_id
        if node.attachment_doc_id && (node.attachment_doc_id != record['_id'] )
          raise "Attachment ID mismatch, current id: #{node.attachment_doc_id} new id: #{record['_id']}"
        elsif node.attachment_doc_id.nil?
          node.attachment_doc_id = record['_id']  #TODO How is it nil?
        end
      else
        node.iv_set(:attachment_doc_id,  record['_id'] )
      end
      node.attachment_doc_id
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
      doc_db = node.class.class_env.db
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
    #Dependency on BufsInfoDocEnvMethods
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
    def by_my_category(user_datastore_id, match_key)
      map_str = "function(doc) {
                     if (doc.bufs_namespace =='#{user_datastore_id}' && doc.my_category ){
                       emit(doc.my_category, doc);
                    }
                 }"
      map_fn = { :map => map_str }
      BufsInfoDocEnvMethods.set_view(@model_actor[:db], @model_actor[:design_doc], :my_category, map_fn)
      raw_res = @model_actor[:design_doc].view :by_my_category, :key => match_key
      rows = raw_res["rows"]
      records = rows.map{|r| r["value"]}
    end

    #namespace vs collection namespace may be confused here
    def by_parent_categories(user_datastore_id, match_keys)
    
      map_str = "function(doc) {
                  if (doc.bufs_namespace == '#{user_datastore_id}' && doc.parent_categories) {
                         emit(doc.parent_categories, doc);
                      };
                  };"
            #   }"
      map_fn = { :map => map_str }
    
      BufsInfoDocEnvMethods.set_view(@model_actor[:db], @model_actor[:design_doc], :parent_categories, map_fn)
      raw_res = @model_actor[:design_doc].view :by_parent_categories
      rows = raw_res["rows"]
      records = rows.map{|r| r["value"] if r["value"]["parent_categories"].include? match_keys}
    end

  end 


    ModelKey = :_id
    VersionKey = :_rev
    NamespaceKey = :bufs_namespace
    BaseMetadataKeys = [ModelKey, VersionKey, NamespaceKey]
    
    #collection_namespace corresponds to the namespace that is used to distinguish between unique
    #data sets (i.e., users) within the model
    def self.generate_model_key(collection_namespace, node_key)
      "#{collection_namespace}::#{node_key}"
    end  

    def self.save(model_save_params, data)
      db = model_save_params[:db]
      raise "No database found to save data" unless db
      raise "No id found in data: #{data.inspect}" unless data[:_id]
      model_data = HashKeys.sym_to_str(data) #data.inject({}){|memo,(k,v)| memo["#{k}"] = v; memo}
      raise "No id found in model data: #{model_data.inspect}" unless model_data['_id']
      #db.save_doc(model_data)
      begin
        #TODO: Genericize this
        res = db.save_doc(model_data)
      rescue RestClient::RequestFailed => e
        #TODO Update specs to test for this
        if e.http_code == 409
          raise "Document Conflict in the Database, most likely this is duplication. Error Code was 409. Need to build handling routine"
          #TODO: Update the below to the new class scheme
          #existing_doc['_attachments'] = existing_doc['attachments'].merge(self['_attachments']) if self['_attachments']
          #existing_doc['file_metadata'] = existing_doc['file_metadata'].merge(self['file_metadata']) if self['file_metadata']
          #existing_doc.save
          #return existing_doc
        else
          raise "Request Failed -- Response: #{res.inspect} Error:#{e}"
        end
      end
    end

    def self.destroy_node(node)
      att_doc = node.class.user_attachClass.get(node.attachment_doc_id) if node.respond_to?(:attachment_doc_id)
      att_doc.destroy if att_doc
      begin
        self.destroy(node)
      rescue ArgumentError => e
        puts "Rescued Error: #{e} while trying to destroy #{node.my_category} node"
        node = node.class.get(node.model_metadata['_id'])
        self.destroy(node)
      end
    end

    def self.destroy(node)
      node.class.class_env.db.delete_doc('_id' => node.model_metadata[ModelKey], '_rev' => node.model_metadata[VersionKey])
    end

  end
end

module DataStructureModels
  module Bufs
    #Required Keys on instantiation
    RequiredInstanceKeys = [:my_category]
    RequiredSaveKeys = [:my_category]  #duplicative?
    NodeKey = :my_category #TODO look at supporting multiple node keys
    
  end
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
  #elimivgnate the need for an abstract class to encapsulate the modesl (the current approach) 
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

  def self.set_namespace(db_name_path, db_user_id)
    @@mutex.synchronize {
      #namespace = "#{db.to_s}::#{db_user_id}"
      lose_leading_slash = db_name_path.split("/")
      lose_leading_slash.shift
      db_name = lose_leading_slash.join("")
      namespace = "#{db_name}_#{db_user_id}"
    }
  end

  def self.set_user_datastore_selector(db, db_user_id)
    @@mutex.synchronize {
      "#{db.to_s}::#{db_user_id}"
    }
  end

  def self.set_user_datastore_id
    @@mutex.synchronize {
      "#{db.to_s}::#{db_user_id}"
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
    more_keys = ['_id', '_rev', '_pos', '_deleted_conflicts', 'bufs_namespace']
    #base_keys = DataStoreModels::CouchRest::BaseMetadataKeys
    #db_metadata_keys = base_keys + [:_pos, :_deleted_conflicts] + more_keys
    
  end

  #TODO: this is a bit convoluted to just return the query string, simplify.
  def self.query_for_all_collection_records
    "by_all_bufs".to_sym
  end

  def self.set_view(db, design_doc, view_name, opts={})
    @@monitor.synchronize {
      #raise view_name if view_name == :parent_categories
      #TODO: Add options for custom maps, etc
      #creating view in design_doc
      design_doc.view_by view_name.to_sym, opts
      db_view_name = "by_#{view_name}"
      views = design_doc['views'] || {}
      view_keys = views.keys || []
      unless view_keys.include? db_view_name
        design_doc['_rev'] = nil
      end
      begin
        view_rev_in_db = db.get(design_doc['_id'])['_rev']
        res = design_doc.save unless design_doc['rev'] == view_rev_in_db
      rescue RestClient::RequestFailed
        puts "Warning: Request Failed, assuming because the design doc was already saved?"
        puts "doc_rev: #{design_doc['_rev'].inspect}"
        puts "db_rev: #{view_rev_in_db}"
      end
    }  
  end

  class ClassEnv
  attr_accessor :db_user_id,
                               :db,
                               :user_datastore_selector,
                               :user_datastore_id,
                               :collection_namespace,
                               :design_doc,
                               :query_all,
                               :attachment_base_id,
                               :db_metadata_keys,
                               :metadata_keys,
                               :base_metadata_keys,
                               :required_instance_keys,
                               :required_save_keys,
                               :node_key,
                               :model_key,
                               :version_key,
                               :namespace_key,
                               :namespace,
                               :files_mgr,
                               :views_mgr,
                               :model_save_params,
                               :user_attachClass #should be overwritten?

  def initialize(env)
    env_name = :bufs_info_doc_env  #"#{self.to_s}_env".to_sym  <= (same thing but not needed yet)
    couch_db_host = env[env_name][:host]
    db_name_path = env[env_name][:path]
    db_user_id = env[env_name][:user_id]
    #TODO move the other couch specific stuff from user_doc into here as well
    user_attach_class_name = "UserAttach#{db_user_id}"
    #the rescue is so that testing works
    begin
      attachClass = UserDB.const_get(user_attach_class_name)
    rescue NameError
      puts "Warning:: Multiuser support for attachments not enabled. This is useful only for basic testing"
      attachClass = BufsInfoAttachment
    end
    @db_user_id = db_user_id
    couch_db_location = BufsInfoDocEnvMethods.set_db_location(couch_db_host, db_name_path)
    @db = CouchRest.database!(couch_db_location)
    @model_save_params = {:db => @db}
    @collection_namespace = BufsInfoDocEnvMethods.set_collection_namespace(db_name_path, db_user_id)
    @user_datastore_selector = BufsInfoDocEnvMethods.set_user_datastore_selector(@db, @db_user_id)
    @user_datastore_id = BufsInfoDocEnvMethods.set_collection_namespace(db_name_path, db_user_id)
    @design_doc = BufsInfoDocEnvMethods.set_couch_design(@db)#, @collection_namespace)
    @define_query_all = "by_all_bufs".to_sym #BufsInfoDocEnvMethods.query_for_all_collection_records
    @attachment_base_id = DataStoreModels::CouchRest::AttachmentBaseID
    @db_metadata_keys = BufsInfoDocEnvMethods.set_db_metadata_keys #(@collection_namespace)
    @metadata_keys = @db_metadata_keys
    @base_metadata_keys = DataStoreModels::CouchRest::BaseMetadataKeys
    @required_instance_keys = DataStructureModels::Bufs::RequiredInstanceKeys
    @required_save_keys = DataStructureModels::Bufs::RequiredSaveKeys
    @model_key = DataStoreModels::CouchRest::ModelKey
    @version_key = DataStoreModels::CouchRest::VersionKey
    @namespace_key = DataStoreModels::CouchRest::NamespaceKey
    @node_key = DataStructureModels::Bufs::NodeKey
    #TODO: namespace is identical to collection_namespace?
    @namespace = BufsInfoDocEnvMethods.set_namespace(db_name_path, db_user_id)
    BufsInfoDocEnvMethods.set_view_all(@db, @design_doc, @collection_namespace)
    @user_attachClass = attachClass  
    @files_mgr = DataStoreModels::CouchRest::FilesMgr.new(:attachment_actor_class => @user_attachClass)
    @views_mgr = DataStoreModels::CouchRest::ViewsMgr.new(:db => @db, :design_doc => @design_doc)
  end

  def query_all  #TODO move to ViewsMgr and change the confusing accessor/method clash
   raw_res = @design_doc.view @define_query_all
   raw_data = raw_res["rows"]
   raw_data.map {|d| d['value']}
  end

  def get(id)
    #maybe put in some validations to ensure its from the proper collection namespace?
    rtn = begin
      @db.get(id)
    rescue RestClient::ResourceNotFound => e
      nil
    end
    rtn
  end

  def save(model_data)
    DataStoreModels::CouchRest.save(@model_save_params, model_data)
  end

  def destroy_node(node)
    DataStoreModels::CouchRest::destroy_node(node)
  end

  def generate_model_key(namespace, node_key)
    DataStoreModels::CouchRest.generate_model_key(namespace, node_key)
  end

  #some models have additional processing required, but not this one
  def raw_all
    query_all
  end

  def destroy_bulk(list_of_native_records)
    list_of_native_records.each do |r|
      begin
        @db.delete_doc(r)
      rescue RestClient::RequestFailed
        puts "Warning:: Failed to delete document?"
      end
    end
    nil #TODO ok to return nil if all docs destroyed? also, not verifying
  end

  end #ClassEnv


end
