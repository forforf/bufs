#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')

require 'couchrest'
require 'monitor'

require Bufs.moabs '/couchrest_attachment_handler'
#require Bufs.moabs 'files_manager_base'  #Not implemented yet

module CouchRestEnv
  include CouchRest::Mixins::Views::ClassMethods

  #ModelKey = :_id
  #VersionKey = :_rev
  #NamespaceKey = :bufs_namespace
  #BaseMetadataKeys = [ModelKey, VersionKey, NamespaceKey]

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

#------------------------- CouchRestEnv below this -----------------------------------------------------

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

=begin
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
=end
  #def self.destroy(node)
  #  node.my_GlueEnv.db.delete_doc('_id' => node._model_metadata[ModelKey], 
	#			  '_rev' => node._model_metadata[VersionKey])
  #end

end
