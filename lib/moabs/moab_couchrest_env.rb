#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')

require 'couchrest'
require 'monitor'

require Bufs.moabs '/couchrest_attachment_handler'
#require Bufs.moabs 'files_manager_base'  #Not implemented yet

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
  
  
  class FilesMgrInterface

    attr_accessor :attachment_doc_class

    def self.get_att_doc(node)
      node_id = node._model_metadata[:_id]
      attachment_doc_id = node.my_GlueEnv.attachClass.uniq_att_doc_id(node_id)
      att_doc = node.my_GlueEnv.db.get(attachment_doc_id)
      if att_doc
        return att_doc
      else
        return nil 
      end
    end

    def initialize(node_env, node_key)
      #for bufs node_key is the value of :my_category
      #although it is not used in this class, it is required to 
      #maintain consitency with bufs_base_node
      #TODO: Actually the goal is for moab's to have no dependency on bufs_base_node
      #so maybe the glue environment should have a files interface to bufs_base_node??
      @attachment_doc_class = node_env.attachClass
    end

    def add_files(node, file_datas)
      bia_class = @attachment_doc_class
      attachment_package = {}
      file_datas = [file_datas].flatten
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
        #TODO: reading the file in this way is memory intensive for large files, chunking it up would be better
        file_data = File.open(src_filename, "rb") {|f| f.read}
        attachment_package[model_basename] = {'data' => file_data, 'md' => file_metadata}
      end
      #attachment package has now been created
      #create the attachment record
      #The attachment handler (bia_class) will deal with creating vs updating
      user_id = node.my_GlueEnv.user_id
      node_id = node._model_metadata[:_id]
      #TODO: There is probably a cleaner way to do add attachments, but low on the priority list
      record = bia_class.add_attachment_package(node_id, bia_class, attachment_package)
      #get the basenames we just stored
      stored_basenames = record['_attachments'].keys
      if node.respond_to? :attachment_doc_id
        #make sure the objects attachment id matches the persistence layer's record id
        if node.attachment_doc_id && (node.attachment_doc_id != record['_id'] )
          raise "Attachment ID mismatch, current id: #{node.attachment_doc_id} new id: #{record['_id']}"
        #if the attachment id doesn't exist, create it
        elsif node.attachment_doc_id.nil?
          node.attachment_doc_id = record['_id']  #TODO How is it nil?
        else
          #we will reach here when everything is fine but we don't need to do anything
        end
      else #it's a new attachment and the attachment id has not been set, so we create and set it
        node.__set_userdata_key(:attachment_doc_id,  record['_id'] )
      end
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
      file_metadata['content_type'] = content_type 
      attachment_package = {}
      unesc_attach_name = BufsEscape.unescape(attach_name)
      attachment_package[unesc_attach_name] = {'data' => raw_data, 'md' => file_metadata}
      node_id = node._model_metadata[:_id]
      record = bia_class.add_attachment_package(node_id, bia_class, attachment_package)
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
      node_id = node._model_metadata[:_id]
      bia_doc_id = bia_class.uniq_att_doc_id(node_id)
      bia_doc = bia_class.get(bia_doc_id)
      bia_doc.fetch_attachment(model_basename)
    end

    def get_attachments_metadata(node)
      bia_class = node.my_GlueEnv.attachClass
      node_id = node._model_metadata[:_id]
      bia_doc_id = bia_class.uniq_att_doc_id(node_id)
      bia_doc = bia_class.get(bia_doc_id)
      bia_doc.get_attachments
    end 


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
  #eliminate the need for an abstract class to encapsulate the models (the current approach) 
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

  #TODO: Convert namespace to be identical to this?
  def self.set_user_datastore_location(db, db_user_id)
    @@mutex.synchronize {
      "#{db.to_s}::#{db_user_id}"
    }
  end

  def self.set_couch_design(db, user_id) #, view_name)
    @@mutex.synchronize {
      design_doc = CouchRest::Design.new
      design_doc.name = "#{self.to_s}_#{user_id}_Design"
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

  #bufs_base_node calls this (through glue)
  def self.generate_model_key(namespace, node_key)
    "#{namespace}::#{node_key}"
  end

  def self.set_attach_class(db_root_location, attach_class_name)
    dyn_attach_class_def = "class #{attach_class_name} < CouchrestAttachment
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
        puts "Document Conflict in the Database,"\
        " record exists or there is database corruption. "\
        " Will attempt to continue with pre-existing record."\
	      #" Error Code was 409. Need to ensure current revs are maintained/current"\
	      #"\nAdditonal Data: model params: #{model_save_params.inspect}"\
	      #"\n                model data: #{model_data.inspect}"\
	      #"\n                all data: #{data.inspect}"
	#TODO: Update the below to the new class scheme
        existing_doc = db.get(model_data['_id'])
        rev = existing_doc['_rev']
        data_with_rev = model_data.merge({'_rev' => rev})
        res = db.save_doc(data_with_rev)
      else
	raise "Request Failed -- Response: #{res.inspect} Error:#{e}"\
	      "\nAdditonal Data: model params: #{model_save_params.inspect}"\
	      "\n                model data: #{model_data.inspect}"\
	      "\n                all data: #{data.inspect}"
      end
    end
  end

  #TODO: Test in spec that attachments are being deleted
  def self.destroy_node(node)
    #att_doc = node.my_GlueEnv.attachClass.get(node.attachment_doc_id) if node.respond_to?(:attachment_doc_id)
    att_doc = node.my_GlueEnv.attachClass.get(node.my_GlueEnv.attachClass.uniq_att_doc_id(node._model_metadata[:_id]))
    #raise "Destroying Attachment #{att_doc.inspect} from #{node._model_metadata[:_id].inspect}"
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
