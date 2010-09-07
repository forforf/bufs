#require 'couchrest'
require 'monitor'
require 'cgi'
require 'time'
require 'json'

#File Node Helpers
class Dir  #monkey patch  (duck punching?)
  def self.working_entries(dir=Dir.pwd)
    ignore_list = ['thumbs.db','all_child_files']
    all_entries = Dir.entries(dir)
    wkg_entries = all_entries.delete_if {|x| x[0] == '.'}
    wkg_entries = wkg_entries.delete_if {|x| ignore_list.include?(x.downcase)}
    return wkg_entries
  end

  def self.file_data_entries(dir=Dir.pwd)
    ignore_list = ['parent_categories.txt', 'description.txt']
    wkg_entries = Dir.working_entries(dir)
    file_data_entries = wkg_entries.delete_if {|x| ignore_list.include?(x.downcase)}
    return file_data_entries
  end
end




#bufs libraries
require File.dirname(__FILE__) + '/node_element_operations'

module DataStoreModels
  module FileStore #TODO Rename?

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
    def initialize(model_actor = {}) #provides the model actor that can manage files
      @model_actor = model_actor
      @record_ref = nil #id for files container  #PROBLEM - 
    end

    def add_files(node, file_datas)
      filenames = []
      file_datas.each do |k,v|
        filenames << file_datas[:src_filename]
      end
      filenames.each do |filename|
        my_dest_basename = ::BufsEscape.escape(File.basename(filename))
        #puts "Add Data File --- Basename (Esc) #{my_dest_basename}"
        #@filename = my_dest_basename
        #FileUtils.mkdir_p(@my_dir) unless File.exist?(@my_dir) #TODO Throw error if its a file
        node_dir = File.join(node.class.class_env.user_datastore_selector, node.my_category)  #TODO: this should be node id, not my cat
        my_dest = File.join(node_dir, my_dest_basename)
        #FIXME: obj.attached_files is broken, list_attached_files should work
        #@attached_files << my_dest
        same_file = filename == my_dest
        FileUtils.cp(filename, my_dest, :preserve => true, :verbose => true ) unless same_file
        #self.file_metadata = {filename => {'file_modified' => File.mtime(filename).to_s}}
      end
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


    def initialize(model_actor=nil)
      @model_actor = model_actor #provides the model actor that can provide views
      @data_file = model_actor[:data_file]
    end

    ## CouchDB View Definitions
    #CouchDB uses a map/reduce structure using javascript
    #map is essentially a query and reduce is a way of aggregating
    #the query into summary type of information (example: summing records)

    #TODO create an index to speed queries? sync issues?
    def by_my_category(user_datastore_selector, match_keys)
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
          data_file_path = File.join(wkg_dir, @data_file)
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

  def by_parent_categories(user_datastore_selector, match_keys)
    match_keys = [match_keys].flatten
    #all_nodes = all collection method when all is moved into here
    matching_node_data = []
    all_wkg_entries = Dir.working_entries(user_datastore_selector)
    all_wkg_entries.each do |entry|
      wkg_dir = File.join(user_datastore_selector, entry)
      if File.exists?(wkg_dir)
        data_file_path = File.join(wkg_dir, @data_file)
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


    ModelKey = :_id  #not used
    VersionKey = :_rev #to have timestapm
    NamespaceKey = :files_namespace
    MetadataKeys = [ModelKey, VersionKey, NamespaceKey]
    
    #collection_namespace corresponds to the namespace that is used to distinguish between unique
    #data sets (i.e., users) within the model
    def self.generate_model_key(collection_namespace, node_key)
      "#{collection_namespace}::#{node_key}"
    end  

    def self.save(model_save_params, data)
      #TODO: Figure out how to separate node_id and my_category, still munged currently
      parent_path = model_save_params[:nodes_save_path]
      node_path = File.join(parent_path, data[:my_category])  #<- Fix this dependency on my_cat
      file_name = model_save_params[:data_file]
      save_path = File.join(node_path, file_name)  
      raise "Path not found to save data: #{parent_path}" unless File.exist?(parent_path)
      #raise "No id found in data: #{data.inspect}" unless data[:_id]
      model_data = HashKeys.sym_to_str(data) #data.inject({}){|memo,(k,v)| memo["#{k}"] = v; memo}
      #raise "No id found in model data: #{model_data.inspect}" unless model_data['_id']
      #db.save_doc(model_data)
      FileUtils.mkdir_p(node_path) unless File.exist?(node_path)
      #begin
        #TODO: Genericize this
      #if File.exist?(save_path)
        #File.open(save_path, 'w') {|f| f.write(model_data.to_json)}
      rev = Time.now.hash #<- I would use File.mtime, but how to get the mod time before saving?
      model_data['_rev'] = rev
      f = File.open(save_path, 'w')
      f.write(model_data.to_json)
      f.close
      #else
      #  File.new(save_path, 'w') {|f| f.write(model_data.to_json)}
        #check_saved_data = File.open(save_path, 'r') {|f| f.read}
        #raise check_saved_data.inspect
      #end
      #rev = Time.now(save_path).hash  #<- revision is based on file modified time
      #model_data['rev'] = rev
      model_data['rev'] = model_data['_rev'] #TODO <- Fix this
      return model_data
        #res = db.save_doc(model_data)
      #rescue RestClient::RequestFailed => e
        #TODO Update specs to test for this
      #  if e.http_code == 409
      #    raise "Document Conflict in the Database, most likely this is duplication. Error Code was 409. Need to build handling routine"
          #TODO: Update the below to the new class scheme
          #existing_doc['_attachments'] = existing_doc['attachments'].merge(self['_attachments']) if self['_attachments']
          #existing_doc['file_metadata'] = existing_doc['file_metadata'].merge(self['file_metadata']) if self['file_metadata']
          #existing_doc.save
          #return existing_doc
      #  else
      #    raise "Request Failed -- Response: #{res.inspect} Error:#{e}"
      #  end
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

module DataStructureModels
  module Bufs 
    #Required Keys on instantiation
    RequiredInstanceKeys = [:my_category]
    RequiredSaveKeys = [:my_category]  #duplicative?
    NodeKey = :my_category #TODO look at supporting multiple node keys
    
  end
end


module BufsFileEnvMethods
  ##Uncomment all mutexs and monitors for thread safety for this module (untested)
  #TODO Test for thread safety
  @@mutex = Mutex.new
  @@monitor = Monitor.new
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
=begin
  def self.set_db_location(couch_db_host, db_name_path)
    @@mutex.synchronize {
      couch_db_host.chop if couch_db_host =~ /\/$/ #removes any trailing slash
      db_name_path = "/#{db_name_path}" unless db_name_path =~ /^\// #check for le
      couch_db_location = "#{couch_db_host}#{db_name_path}"
    }
  end
=end

  #assigns a inter-model, consistent and unique namespace to the collection of nodes belonging to this class
#  def self.set_collection_namespace(fs_name_path, fs_user_id)
#    @@mutex.synchronize {
#      #lose_leading_slash = fs_name_path.split("/")
#      #lose_leading_slash.shift
#      #fs_name = lose_leading_slash.join("_")
#      collection_root = File.basename(fs_name_path)
#      collection_namespace = "#{collection_root}_#{fs_user_id}"
#    }
#  end

  def self.set_user_datastore_selector(fs_name_path, fs_user_id)
    @@mutex.synchronize {
      File.join(fs_name_path, fs_user_id)
    }
  end

  def self.set_user_datastore_id(fs_name_path, fs_user_id)
    @@mutex.synchronize {
      File.join(fs_name_path, fs_user_id)
      #lose_leading_slash = fs_name_path.split("/")
      #lose_leading_slash.shift
      #fs_name = lose_leading_slash.join("_")
      #collection_root = File.basename(fs_name_path)
      #collection_namespace = "#{collection_root}_#{fs_user_id}"
    }
  end

  #model namespace
  def self.set_namespace(fs_name_path, fs_user_id)
    @@mutex.synchronize {
      namespace = File.join(fs_name_path, fs_user_id)
    }
  end

=begin
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
=end

=begin
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
=end


  def self.set_fs_metadata_keys #(collection_namespace)
    db_metadata_keys = ['_id', '_rev']
  end

=begin
  #TODO: this is a bit convoluted to just return the query string, simplify.
  def self.query_for_all_collection_records(collection_namespace)
    "by_all_bufs".to_sym
  end
=end
=begin
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
=end

  def self.set_data_file_name
    ".node_data.json"
  end

  class ClassEnv
  #TODO: Rather than using File class directly, should a special class be used?
#=begin
  attr_accessor :fs_user_id,
                               :data_file_name,
                               :collection_namespace,
                               :user_datastore_selector,
                               :user_datastore_id,
                               #:design_doc,
                               #:query_all,
                               :fs_metadata_keys,
                               :metadata_keys,
                               :namespace,
                               :files_mgr,
                               :views_mgr,
                               :model_save_params,
                               :user_attachClass #should be overwritten?
#=end

  def initialize(env)
    env_name = :bufs_file_system_env  #"#{self.to_s}_env".to_sym  <= (same thing but not needed yet)
    #couch_db_host = env[env_name][:host]
    fs_path = env[env_name][:path]
    fs_user_id = env[env_name][:user_id]
    #TODO move the other couch specific stuff from user_doc into here as well
    user_attach_class_name = "UserAttach#{fs_user_id}"
    #the rescue is so that testing works
    begin
      #UserDB name should be changed to the name for the sync manager
      attachClass = UserFileNode.const_get(user_attach_class_name)
    rescue NameError
      puts "Warning:: Multiuser support for attachments not enabled. This is useful only for basic testing"
      attachClass = "AttachClassShouldBeInFileHandler"
    end

    #@collection_namespace = BufsFileEnvMethods.set_collection_namespace(fs_path, fs_user_id)
    @user_datastore_selector = BufsFileEnvMethods.set_user_datastore_selector(fs_path, fs_user_id)
    @user_datastore_id = BufsFileEnvMethods.set_user_datastore_id(fs_path, fs_user_id)

    @fs_metadata_keys = BufsFileEnvMethods.set_fs_metadata_keys #(@collection_namespace)
    @metadata_keys = @fs_metadata_keys #TODO spaghetti code alert
    @user_datastore_selector = BufsFileEnvMethods.set_namespace(fs_path, fs_user_id)
    @namespace = BufsFileEnvMethods.set_namespace(fs_path, fs_user_id)
    #BufsInfoDocEnvMethods.set_view_all(@db, @design_doc, @collection_namespace)
    @user_attachClass = attachClass  
    @data_file_name = BufsFileEnvMethods.set_data_file_name
    @model_save_params = {:nodes_save_path => @user_datastore_selector, :data_file => @data_file_name}
    @files_mgr = DataStoreModels::FileStore::FilesMgr.new
    @views_mgr = DataStoreModels::FileStore::ViewsMgr.new({:data_file => @data_file_name})
  end

  def query_all  #TODO move to ViewsMgr
    unless File.exists?(@user_datastore_selector)
      raise "Can't get all. The File System Directory to work from does not exist: #{@user_datastore_selector}"
    end
    all_nodes = []
    my_dir = @user_datastore_selector + '/' #TODO: Can this be removed?
    all_entries = Dir.working_entries(my_dir)
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
    list_of_native_records.each do |r|
      #puts "Dir: #{File.dirname(r)}"
      r = File.join(@user_datastore_selector, r) if File.dirname(r) == "."
      #puts "Removing: #{r.inspect}"
      FileUtils.rm_rf(r)
    end
    nil #TODO ok to return nil if all docs destroyed? also, not verifying
  end

  end #ClassEnv

end