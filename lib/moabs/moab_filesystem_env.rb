#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')

require 'cgi'
require 'time'
require 'json'
require 'monitor'

require Bufs.helpers 'mime_types_new'
#require Bufs.moabs 'files_manager_base' #Not implemented yet

#File Node Helpers
class Dir  #monkey patch  (duck punching?)
  def self.working_entries(dir=Dir.pwd)
    ignore_list = ['thumbs.db','all_child_files']
    all_entries = if File.exists?(dir)
      Dir.entries(dir)
    else
      nil
    end
    wgk_entries = nil
    wkg_entries = all_entries.delete_if {|x| x[0] == '.'} if all_entries
    wkg_entries = wkg_entries.delete_if {|x| ignore_list.include?(x.downcase)} if wkg_entries
    return wkg_entries
  end

  #TODO: this duplicates working_entries is it needed?
  def self.file_data_entries(dir=Dir.pwd)
    ignore_list = ['parent_categories.txt', 'description.txt']
    wkg_entries = Dir.working_entries(dir)
    file_data_entries = wkg_entries.delete_if {|x| ignore_list.include?(x.downcase)}
    return file_data_entries
  end
end

module FileSystemEnv
  ##Uncomment all mutexs and monitors for thread safety for this module (untested)
  #TODO Test for thread safety
  @@mutex = Mutex.new
  @@monitor = Monitor.new

  ModelKey = :_id  #not used
  VersionKey = :_rev #to have timestapm
  NamespaceKey = :files_namespace
  BaseMetadataKeys = [ModelKey, VersionKey, NamespaceKey]

  #The file handling is bound to the model, and can't be abstracted away. This means files can't be handled
  #via the dynamic methods used for other data structures.
  #models that will handle data files (whether filesystem files or attachments)
  #must provide a method called _files_mgr that provides an object that can add from a file, add from raw data
  #and subtract (i.e.) delete the file from the model. These functions must be implemented
  #by the following named methods.
      # .add_file(add_file_hashes)      -> adds file data from a file on the local file system (to this program)
      # .add_raw_data(raw_data_hashes)  -> creates a file in the model from the raw data provided
      # .subtract(filename_keys)        -> removes the file and metadata associated with the model_filename matching file
      # .list_files
      # .get_file(filename_key)

      # add_file_hash = { :model_filename => filename stored in model, (defaults to src_filename's basename)
      #                   :src_filename => source filename,  (either src_filename or raw_data must be provided)
      #                   :content_type => :mime content type for the file (derived from file extension defaults to TBD i
      #                 }

      # raw_data_hash = { :model_filename => filename stored in model, (required)
      #                   :src_data => source data, (the data to be stored in the file,
      #                   :content_type => :mime content type for the file (required)
      #                 }
      #
      # filename_key = model_filenames to delete


  #TODO Make thread safe
  class FilesMgrInterface
    attr_accessor :attachment_location, :attachment_packages

    def self.get_att_doc(node)
      root_path = node.my_GlueEnv.user_datastore_selector
      #my_cat dependency
      node_loc  = node._user_data[node.my_GlueEnv.node_key]
      node_path = File.join(root_path, node_loc)
      model_basenames = Dir.working_entries(node_path)
      filenames = model_basenames.map{|b| File.join(node_path, BufsEscape.escape(b))}
    end

    def initialize(node_env, node_key)
      #for bufs node_key is the value of :my_category
      @attachment_location = File.join(node_env.user_datastore_selector, node_key)
    end

    #TODO: Is passing node in methods duplicative now that the moab FileMgr is bound to an env at initialization?
    
    def add_files(node, file_datas)
      filenames = []
      file_datas.each do |file_data|
        #TODO Validate file data before saving
        filenames << file_data[:src_filename]
      end
      filenames.each do |filename|
        my_dest_basename = BufsEscape.escape(File.basename(filename))
        node_dir = @attachment_location
         #File.join(node.my_GlueEnv.user_datastore_selector, node.my_category)  #TODO: this should be node id, not my cat
        my_dest = File.join(node_dir, my_dest_basename)
        #FIXME: obj.attached_files is broken, list_attached_files should work
        #@attached_files << my_dest
        same_file = filename if filename == my_dest
        puts "File model attachments:"
        puts "Copy #{filename} to #{my_dest} if #{same_file.nil?}"
        #was breaking if the dest path didn't exist
        FileUtils.mkdir_p(File.dirname(my_dest)) unless File.exist?(File.dirname(my_dest))
        FileUtils.cp(filename, my_dest, :preserve => true, :verbose => false ) unless same_file
        #self.file_metadata = {filename => {'file_modified' => File.mtime(filename).to_s}}
      end
      filenames.map {|f| BufsEscape.escape(File.basename(f))} #return basenames
    end

    def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
      raise "No Data provided for file" unless raw_data
      #bia_class = @model_actor[:attachment_actor_class]
      file_metadata = {}
      if file_modified_at
        file_metadata['file_modified'] = file_modified_at
      else
        file_metadata['file_modified'] = Time.now.to_s
      end
      file_metadata['content_type'] = content_type #TODO: is unknown content handled gracefully?
      attachment_package = {}
      esc_attach_name = BufsEscape.escape(attach_name)
      root_path = node.my_GlueEnv.user_datastore_selector
      node_loc  = node._user_data[node.my_GlueEnv.node_key]
      node_path = File.join(root_path, node_loc)
      FileUtils.mkdir_p(node_path) unless File.exist?(node_path)
      raw_data_filename = File.join(node_path, esc_attach_name)
      File.open(raw_data_filename, 'wb'){|f| f.write(raw_data)}
      if file_modified_at
        File.utime(Time.parse(file_modified_at), Time.parse(file_modified_at), raw_data_filename)
      else
        file_modified_at = File.mtime(raw_data_filename).to_s     
      end
      #@file_metadata = {'file_modified' => file_modified_at}
      #@attached_files << raw_data_filename

      #attachment_package[unesc_attach_name] = {'data' => raw_data, 'md' => file_metadata}
      #bia = bia_class.get(node.my_attachment_doc_id)
      #record = bia_class.add_attachment_package(node, attachment_package)
      #@record_ref = record['_id']
      #add raw data only supports a single file, but returns it as an array so that the return
      #type is consisentent with other methods that ad files.
      [esc_attach_name]
    end

    #TODO  Document the :all shortcut somewhere
    def subtract_files(node, model_basenames)
      #bia_class = @model_actor[:attachment_actor_class]
      if model_basenames == :all
        subtract_all(node)
      else
        subtract_some(node, model_basenames)
      end
    end

    def get_raw_data(node, model_basename)
      node_dir = @attachment_location
      filename = File.join(node_dir, model_basename)
      File.open(filename, "r"){|f| f.read}
    end

    def get_attachments_metadata(node)
      att_md = {}
      node_dir = @attachment_location
      att_basenames = Dir.working_entries(node_dir)
      att_basenames.each do |att|
        file_md = {}
        filename = File.join(node_dir, att)
        file_md[:file_modified] = File.mtime(filename).to_s
        file_md[:content_type] = MimeNew.for_ofc_x(filename)
        att_md[att.to_sym] = file_md
      end
      att_md
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
    def subtract_some(node, model_basenames)
      if node.attached_files
        #TODO: replace the duplicative namespaces with path to the node dir
        root_path = node.my_GlueEnv.user_datastore_selector
        node_loc  = node._user_data[node.my_GlueEnv.node_key]
        node_path = File.join(root_path, node_loc)
        filenames = model_basenames.map{|b| File.join(node_path, BufsEscape.escape(b))}
        #raise filenames.inspect
        FileUtils.rm_f(filenames)
        #subtract_all(node) if rem_atts.empty?
      end
    end
    #TODO: make private
    def subtract_all(node)
      root_path = node.my_GlueEnv.user_datastore_selector
      node_loc  = node._user_data[node.my_GlueEnv.node_key]
      node_path = File.join(root_path, node_loc)
      attached_entries = Dir.working_entries(node_path)
      #alternate approach would be to use node.files_attached
      #FIXME: What is the e for in the File.join? is it needed?
      attached_filenames = attached_entries.map{|e| File.join(node_path, e)}
      FileUtils.rm(attached_filenames)
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


  def self.set_user_datastore_selector(fs_name_path, fs_user_id)
    @@mutex.synchronize {
      File.join(fs_name_path, fs_user_id, self.model_dir_name)
    }
  end

  def self.set_user_datastore_id(fs_name_path, fs_user_id)
    @@mutex.synchronize {
      File.join(fs_name_path, fs_user_id, self.model_dir_name)
    }
  end

  #model namespace
  def self.set_namespace(fs_name_path, fs_user_id)
    @@mutex.synchronize {
      namespace = File.join(fs_name_path, fs_user_id)
    }
  end

  def self.set_fs_metadata_keys #(collection_namespace)
    metadata_keys = BaseMetadataKeys 
  end

  def self.set_data_file_name
    ".node_data.json"
  end
  
  def self.model_dir_name
    ".model"
  end

  #Node Actions
    
    #collection_namespace corresponds to the namespace that is used to distinguish between unique
    #data sets (i.e., users) within the model
    def self.generate_model_key(collection_namespace, node_key)
      "#{collection_namespace}::#{node_key}"
      #File.join(collection_namespace,node_key)
    end  

    def self.save(model_save_params, data)
      #TODO: Figure out how to separate node_id and my_category, still munged currently
      parent_path = model_save_params[:nodes_save_path]
      #model_dir = self.model_dir_name
      #TODO, should the node_path come from some other data type (i.e., datastore_selector?)
      #TODO Fix filename dependency with :my_category
      node_path = File.join(parent_path, data[:my_category])
      file_name = model_save_params[:data_file]
      save_path = File.join(node_path, file_name)  
      #raise "Path not found to save data: #{parent_path}" unless File.exist?(parent_path)
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
      #end
    end

    #TODO: This method is never reached since the glue env handles it.  That is probably the wrong approach.
    def self.destroy_node(node)
      att_doc = node.class.user_attachClass.get(node.attachment_doc_id) if node.respond_to?(:attachment_doc_id)
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
      node.class.class_env.db.delete_doc('_id' => node._model_metadata[ModelKey], '_rev' => node._model_metadata[VersionKey])
    end

end

