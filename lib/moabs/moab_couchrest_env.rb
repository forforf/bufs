require 'couchrest'
require 'monitor'
require File.dirname(__FILE__) + '/couchrest_attachment_handler'

require File.dirname(__FILE__) + '/files_manager_base'

module CouchRestEnv
  ##Uncomment all mutexs and monitors for thread safety for this module (untested)
  #TODO Test for thread safety
  @@mutex = Mutex.new
  @@monitor = Monitor.new
  include CouchRest::Mixins::Views::ClassMethods

  ModelKey = :_id
  VersionKey = :_rev
  NamespaceKey = :bufs_namespace
  BaseMetadataKeys = [ModelKey, VersionKey, NamespaceKey]

  AttachmentBaseID = "_attachments"

  #The file handling is bound to the model, and can't be abstracted away. This means files can't be handle
  #via the dynamic methods used for other data structures.
  #models that will handle data files (whether filesystem files or attachments)
  #must provide a method called _files_mgr that provides an object that can add from a file, add from raw d
  #and subtract (i.e.) delete the file from the model. These functions must be implemented
  #by the following named methods.
      # .add_file(add_file_hashes)      -> adds file data from a file on the local file system (to this pr
      # .add_raw_data(raw_data_hashes)  -> creates a file in the model from the raw data provided
      # .subtract(filename_keys)        -> removes the file and metadata associated with the model_filenam
      # .list_files
      # .get_file(filename_key)

      # add_file_hash = { :model_filename => filename stored in model, (defaults to src_filename's basenam
      #                   :src_filename => source filename,  (either src_filename or raw_data must be prov
      #                   :content_type => :mime content type for the file (derived from file extension de
      #                 }

      # raw_data_hash = { :model_filename => filename stored in model, (required)
      #                   :src_data => source data, (the data to be stored in the file,
      #                   :content_type => :mime content type for the file (required)
      #                 }
      #
      # filename_key = model_filenames to delete
  class BIDStub
    attr_accessor :_model_metadata
    def self.attachment_base_id
      "_attachments"
    end
   
    def initialize(id)
      @_model_metadata = {}
      @_model_metadata[:_id] = id
    end
  end
  class FilesMgrInterface

    attr_accessor :attachment_location, :attachment_packages

    def self.get_att_doc(node)
      #FIXME: This is a hack that doesn't require changing the attachment class
      #id = node_env.generate_model_key(node_env.user_datastore_id, node_key)
      #stub_bid = BIDStub.new(id)
      #@attachment_doc_id = @attachment_doc_class.uniq_att_doc_id(stub_bid)
      attachment_doc_id = node.my_GlueEnv.attachClass.uniq_att_doc_id(node)
      att_doc = node.my_GlueEnv.db.get(attachment_doc_id)
      if att_doc
        return att_doc
      else
        return nil #self.new(node_env, node_key) #, node_key)
      end
    end


    def initialize(node_env,node_key) #, node_key)
      #for bufs node_key is the value of :my_category
      #TODO move from glue to moab
      @attachment_doc_class = node_env.attachClass
    end

    def add_files(node, file_datas)
      bia_class = @attachment_doc_class #node.my_GlueEnv.attachClass
      attachment_package = {}
      file_datas = [file_datas].flatten
      stored_basenames = []
      file_datas.each do |file_data|
        #get file data
        src_filename = file_data[:src_filename]
        src_basename = BufsEscape.escape(File.basename(src_filename))
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
        stored_basenames << src_basename  #TODO: Tie this more closely with successful attachment
      end
      #attachment package has now been created
      #create the attachment record
      #TODO: What if the attachment already exists?
      user_id = node.my_GlueEnv.db_user_id
      node_id = node._model_metadata[:_id]
      record = bia_class.add_attachment_package(node, attachment_package)
      if node.respond_to? :attachment_doc_id
        if node.attachment_doc_id && (node.attachment_doc_id != record['_id'] )
          raise "Attachment ID mismatch, current id: #{node.attachment_doc_id} new id: #{record['_id']}"
        elsif node.attachment_doc_id.nil?
          node.attachment_doc_id = record['_id']  #TODO How is it nil?
        end
      else
        node.__set_userdata_key(:attachment_doc_id,  record['_id'] )
      end
      #node.attachment_doc_id
      stored_basenames
    end

    def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
      bia_class = node.my_GlueEnv.attachClass
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
      #bia = bia_class.get(node.attachment_doc_id)
      record = bia_class.add_attachment_package(node, attachment_package)
      if node.respond_to? :attachment_doc_id
        if node.attachment_doc_id && (node.attachment_doc_id != record['_id'] )
          raise "Attachment ID mismatch, current id: #{node.attachment_doc_id} new id: #{record['_id']}"
        elsif node.attachment_doc_id.nil?
          node.attachment_doc_id = record['_id']  #TODO How is it nil?
        end
      else
        node.__set_userdata_key(:attachment_doc_id,  record['_id'] )
      end
      [attach_name]
      #@record_ref = record['_id']
    end

    #TODO  Document the :all shortcut somewhere
    def subtract_files(node, model_basenames)
      bia_class = node.my_GlueEnv.attachClass
      if model_basenames == :all
        subtract_all(node, bia_class)
      else
        subtract_some(node, model_basenames, bia_class)
      end
    end

    def get_raw_data(node, model_basename)
      bia_class = node.my_GlueEnv.attachClass
      bia_doc_id = bia_class.uniq_att_doc_id(node)
      bia_doc = bia_class.get(bia_doc_id)
      bia_doc.fetch_attachment(model_basename)
    end

    def get_attachments_metadata(node)
      bia_class = node.my_GlueEnv.attachClass
      bia_doc_id = bia_class.uniq_att_doc_id(node)
      bia_doc = bia_class.get(bia_doc_id)
      bia_doc.get_attachments
    end 

    #def get_attachment_metadata(node, model_basename)
    #  atts = get_attachments_metadata(node)
    #  atts[BufsEscape.escape(model_basename)]  #TODO This will break when filename is not the key field
    #end

    #def list_files(node)
    #  return nil unless node.attachment_doc_id
    #  bia_class = @model_actor[:attachment_actor_class]
    #  rtn = if node.attachment_doc_id
    #    bia_doc = bia_class.get(node.attachment_doc_id)
    #    bia_doc.get_attachments
    #  end
    #  rtn
    #end

    #def get_file_data(node, basename)
    #  bia_class = node.my_GlueEnv.attachClass
    #  data = bia_doc.fetch_attachment(basename)
    #end

    #def list_file_keys(node)
    #   return nil unless node.attachment_doc_id
    #   atts = list_files(node)
    #   rtn = atts.keys
    #end

    #TODO: make private
    def subtract_some(node, model_basenames, bia_class)
      if node.attachment_doc_id
        bia_doc = bia_class.get(node.attachment_doc_id)
        raise "BiaClass_Attach: #{node.class.user_attachClass} Node: #{node.class.name} AttID: #{node.attachment_doc_id}" unless bia_doc
        bia_doc.remove_attachment(model_basenames)
        rem_atts = bia_doc.get_attachments
        subtract_all(node, bia_class) if rem_atts.empty?
      end
    end
    #TODO: make private
    def subtract_all(node, bia_class)
      #delete the attachment record
      doc_db = node.my_GlueEnv.db
      if node.attachment_doc_id
        attach_doc = doc_db.get(node.attachment_doc_id)
        doc_db.delete_doc(attach_doc)
        node.__unset_userdata_key(:attachment_doc_id)
        node.__save
      else
        puts "Warning: Attempted to delete attachments when none existed"
      end
      node
    end
  end

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

  def self.set_db_metadata_keys #(collection_namespace)
    #more_keys = ['_id', '_rev', '_pos', '_deleted_conflicts', 'bufs_namespace']
    base_keys = BaseMetadataKeys
    db_metadata_keys = base_keys + [:_pos, :_deleted_conflicts] #+ more_keys
    
  end

  #TODO: this is a bit convoluted to just return the query string, simplify.
  def self.query_for_all_collection_records
    "by_all_bufs".to_sym
  end

  #collection_namespace corresponds to the namespace that is used to distinguish between unique
  #data sets (i.e., users) within the model
  def self.generate_model_key(collection_namespace, node_key)
    "#{collection_namespace}::#{node_key}"
  end

  def self.set_attach_class(db_root_location, attach_class_name)
    dyn_attach_class_def = "class #{attach_class_name} < BufsInfoAttachment
      use_database CouchRest.database!(\"http://#{db_root_location}/\")
 
      def self.namespace
        CouchRest.database!(\"http://#{db_root_location}/\")
      end
    end"
    
    self.class_eval(dyn_attach_class_def)
    self.const_get(attach_class_name)
  end

  #Nodal Actions
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
	puts "Document Conflict in the Database, most likely this is duplication."\
	      " Error Code was 409. Need to ensure current revs are maintained/current"\
	      "\nAdditonal Data: model params: #{model_save_params.inspect}"\
	      "\n                model data: #{model_data.inspect}"\
	      "\n                all data: #{data.inspect}"
	#TODO: Update the below to the new class scheme
        existing_doc = db.get(model_data['_id'])
        rev = existing_doc['_rev']
        data_with_rev = model_data.merge({'_rev' => rev})
        res = db_save_doc(data_with_rev)
	#existing_doc['_attachments'] = existing_doc['attachments'].merge(self['_attachments']) if self[
	#existing_doc['file_metadata'] = existing_doc['file_metadata'].merge(self['file_metadata']) if s
	#existing_doc.save
	#return existing_doc
      else
	raise "Request Failed -- Response: #{res.inspect} Error:#{e}"\
	      "\nAdditonal Data: model params: #{model_save_params.inspect}"\
	      "\n                model data: #{model_data.inspect}"\
	      "\n                all data: #{data.inspect}"
      end
    end
  end

  def self.destroy_node(node)
    att_doc = node.my_GlueEnv.attachClass.get(node.attachment_doc_id) if node.respond_to?(:attachment_doc_id)
    att_doc.destroy if att_doc
    begin
      self.destroy(node)
    rescue ArgumentError => e
      puts "Rescued Error: #{e} while trying to destroy #{node.my_category} node"
      node = node.class.get(node._model_metadata['_id'])
      self.destroy(node)
    end
  end

  def self.destroy(node)
    node.my_GlueEnv.db.delete_doc('_id' => node._model_metadata[ModelKey], 
				  '_rev' => node._model_metadata[VersionKey])
  end

end
