require 'time'
require 'json'

#Bufs directory organization defined in lib/helpers/require_helper
require Bufs.helpers 'mime_types_new'

#TODO: Move this into a MonkeyPatch named module (called by file glue)
# Bufs.monkey_patch punching_dir  or something
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

module FilesystemInterface
  class FilesMgr
    #Set Logger
    @@log = BufsLog.set(self.name)

    attr_accessor :attachment_location, :attachment_packages

    def self.get_att_doc(node)
      root_path = node.my_GlueEnv.user_datastore_location
      #my_cat dependency
      node_loc  = node._user_data[node.my_GlueEnv.node_key]
      node_path = File.join(root_path, node_loc)
      model_basenames = Dir.working_entries(node_path)
      filenames = model_basenames.map{|b| File.join(node_path, BufsEscape.escape(b))}
    end

    def initialize(node_env, node_key)
      #for bufs node_key is the value of :my_category
      @node_key = node_key
      @attachment_location = File.join(node_env.user_datastore_location, node_key)
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
        @@log.debug {"File model attachments:"} if @@log.debug?
        @@log.debug { "Copy #{filename} to #{my_dest} if #{same_file.nil?}"} if @@log.debug?
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
      root_path = node.my_GlueEnv.user_datastore_location
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
    
    #Not used and I don't think it will work anyway
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
     
    private 
    
    def subtract_some(node, model_basenames)
      if node.attached_files
        #TODO: replace the duplicative namespaces with path to the node dir
        root_path = node.my_GlueEnv.user_datastore_location
        node_loc  = node._user_data[node.my_GlueEnv.node_key]
        node_path = File.join(root_path, node_loc)
        filenames = model_basenames.map{|b| File.join(node_path, BufsEscape.escape(b))}
        #raise filenames.inspect
        FileUtils.rm_f(filenames)
        #subtract_all(node) if rem_atts.empty?
      end
    end
    
    def subtract_all(node)
      root_path = node.my_GlueEnv.user_datastore_location
      node_loc  = node._user_data[node.my_GlueEnv.node_key]
      node_path = File.join(root_path, node_loc)
      attached_entries = Dir.working_entries(node_path)
      #alternate approach would be to use node.files_attached
      #FIXME: What is the e for in the File.join? is it needed?
      attached_filenames = attached_entries.map{|e| File.join(node_path, e)}
      FileUtils.rm(attached_filenames)
    end
  end
end