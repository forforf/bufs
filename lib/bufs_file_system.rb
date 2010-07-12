#common libraries
require 'cgi'
require 'time'
#JSON Hack
require 'json'

#bufs libraries
require File.dirname(__FILE__) + '/bufs_escape'   #need to insert this 

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


class BufsFileSystem
  #class << self 
    #attr_accessor :bfs_dir
      #:name_space, :parent_categories_file_basename,
      #:description_file_basename, :win_dir, :linux_dir
  #end

 #bind to directory model
  #must be set before it can be used
  #child classes should set this in their
  #class definitions
 #---
 def self.use_directory(bfs_dir)
    @bfs_dir = bfs_dir
    FileUtils.mkdir_p(File.expand_path(@bfs_dir))
  end

  def self.namespace
    @bfs_dir
  end

  def self.data_file_name
    ".node_data.json"
  end

  def self.link_file_name
    ".link_data.json"
  end

  #TODO: Remove the hard coding of data as filenames and use 
  #config file
  def parent_categories_file_basename
    "parent_categories.txt"
  end

 #---

  #overwrite these in the dynamic class definition
  #---
  #@base_dir = nil
  #@namespace = nil
  #create the operating directory for the class
  #@model_dir = "#{@base_dir}/#{@namespace}"
  #File.mkdir_p(File.expand_path(@model_dir))
  #---
  #@name_space = nil
  #@win_dir = 'windows_format'
  #@linux_dir = 'mac_linux_format'
  #@parent_categories_file_basename = 'parent_categories.txt'
  #@description_file_basename = 'description.txt'


  #TODO: Determine if there's a way for file_metadata and filename to be added dynamically
  attr_accessor :file_metadata, :filename, 
                :my_dir, :attached_files, :node_data_hash

  def self.model_dir
    "#{@base_dir}/#{self.class.namespace}"
  end
  #def self.set_name_space(model_dir)
  #   FileUtils.mkdir_p(File.expand_path(model_dir))
  #   BufsFileSystem.name_space = model_dir
  #   self.normalize
  #end

  #This method will go through the entire model directory and make sure
  #all file names have been normalized (remove strange characters)
  #DANGER: this will fail if there are files in the directory that reduce to the same normalized name
  def self.normalize
    unless File.exists?(BufsFileSystem.name_space)
      raise "Cannot normalize. The File System Directory to work from does not exist: #{BufsFileSystem.name_space}"
    end
    my_dir = self.class.name_space + '/'
    all_entries = Dir.working_entries(my_dir)
    all_entries.each do |cat_entry|
      wkg_dir = my_dir + cat_entry + '/'
      files = Dir.file_data_entries(wkg_dir)
      files.each do |f|
        esc_f = ::BufsEscape.escape(f)
        unless f == esc_f
          full_f = wkg_dir + f
          full_esc_f = wkg_dir + esc_f
          FileUtils.mv(full_f, full_esc_f)
        end
      end
    end
  end

  def self.all
    unless File.exists?(self.namespace)
      raise "Can't get all. The File System Directory to work from does not exist: #{self.name_space}"
    end
    all_nodes = []
    my_dir = self.namespace + '/'
    all_entries = Dir.working_entries(my_dir)
    all_entries.each do |cat_entry|
      wkg_dir = my_dir + cat_entry + '/'
      cat_name = cat_entry
      #parent_cat_fname = wkg_dir + BufsFileSystem.parent_categories_file_basename
      #parent_cats = []
      #if File.exists?(parent_cat_fname)
      #  parent_cats = JSON.parse(File.open(wkg_dir + parent_cat_fname){|f| f.read})
      #end
      #desc = ""
      #desc_fname = BufsFileSystem.description_file_basename
      #if File.exists?(desc_fname)
      #  desc = File.open(wkg_dir + BufsFileSystem.description_file_basename){|f| f.read}
      #end
      data_fname = self.data_file_name
      bfs = nil
      if File.exists?(wkg_dir + data_fname)
       bfs_data = JSON.parse(File.open(wkg_dir + data_fname) {|f| f.read})
        bfs = self.new(bfs_data)
        files = Dir.file_data_entries(wkg_dir)
        files.each do |f|
          full_filename = wkg_dir + '/' + f
          bfs.add_data_file(full_filename)
        end

      end
      #file_mod_time = File.mtime(wkg_dir + cat_entry) if File.exists?(wkg_dir + cat_entry)
      #f_metadata = {'file_modified' => file_mod_time.to_s} if file_mod_time
      #bfs =  BufsFileSystem.new(:parent_categories => parent_cats,
      #                                     :my_category => cat_name,
      #                                     :description => desc)#,
      #                                     #:file_metadata => f_metadata)
      #bfs = BufsFileSystem.new(bfs_data)
      #files = Dir.file_data_entries(wkg_dir)
      #files.each do |f|
      #  full_filename = wkg_dir + '/' + f
      #  bfs.add_data_file(full_filename)
      #end
      all_nodes << bfs if bfs

    end
    all_nodes
  end

  def self.by_my_category(my_cat)
    #raise "nt: #{nodetest.my_category.inspect}" if nodetest
    raise "No category provided for search" unless my_cat
    #puts "Searching for #{my_cat.inspect}"
    my_dir = self.namespace + '/'
    my_cat_dir = my_cat
    wkg_dir = my_dir + my_cat_dir + '/'
    if File.exists?(wkg_dir)
      #added 2/24 at 10:23 am due to spec failure in sync_node seems like BufsFileSystem bug fix
      node_data  = JSON.parse(File.open(wkg_dir + self.data_file_name){|f| f.read})
      bfs = self.new(node_data)
      #
      #cat_files = Dir.working_entries(wkg_dir)
      #puts "Files in #{wkg_dir.inspect}"
      #p cat_files
      #TODO This is brittle, tie the meta categories names to the assignment at creation
      #cat_files.delete('parent_categories.txt')
      #cat_files.delete('description.txt')
      bfss = []
      #if cat_files.size > 0
      #  cat_files.each do |cat_file_name|
      #    #parent_cats = JSON.parse(File.open(wkg_dir + BufsFileSystem.parent_categories_file_basename){|f| f.read})
      #    #desc = File.open(wkg_dir + BufsFileSystem.description_file_basename){|f| f.read}
      #    ##puts "BFS.by_my_category location for attachment file: #{wkg_dir + cat_file_name.inspect}"
      #    ##file_mod_time = File.mtime(wkg_dir + cat_file_name) if File.exists?(wkg_dir + cat_file_name)
      #    ##f_metadata = {'file_modified' => file_mod_time.to_s} if file_mod_time
      #    ##puts "BFS.by_my_category file md: #{f_metadata.inspect}"
      #    #bfs = BufsFileSystem.new(:parent_categories => parent_cats,
      #    #                               :my_category => my_cat,
      #    #                               :description => desc) #,
      #    #                               #:file_metadata => f_metadata)
      #    ##bfs.filename = cat_file_name
      #  ##check for files
      #    files = Dir.file_data_entries(wkg_dir)
	#  files.each do |f|
	#    full_filename = wkg_dir + '/' + f
	#    bfs.add_data_file(full_filename)
	#  end
        #  bfss << bfs
        # end
        #return bfss  removed 2/24 at 10:14am wrong place
      #else
        bfss << bfs 
      #end
      return bfss   #returned as an array for compatibility with other search and node types
    else
      puts "Warning: #{wkg_dir.inspect} was not found"
      return nil
    end
  end

  def initialize(init_params = {})
    raise "No parameters were passed to #{self.class} initialization" if (init_params.nil?||init_params.empty?)
    raise "No directory has been set for #{self}" unless self.class.namespace
    @node_data_hash = {}
    init_params.each do |attr_name, attr_value|
      iv_set(attr_name.to_sym, attr_value)
    end
    #Hack to get around the fact that if my_category hasn't been set
    #then there is no my_category method either
    #iv_set(:my_category, nil)
    #raise "NS: #{self.class.namespace.inspect} My Cat: #{self.my_category.inspect}"
    @my_dir = self.class.namespace + '/' + self.my_category + '/' if self.my_category

    @attached_files = []
  end


  #this method is basically to make it sort of act like a hash and struct
  #FIXME: IMPORTANT: This breaks under some circumstances of dynamic classing
  #When a new instance is created from the same class, these methods are
  #recreated and use the new instances hash?  At least I think that's what's
  #going on.  Need to isolate and test.  Work around is to use the hash to
  #access the data
  def iv_set(attr_var, attr_value)
    #update the data store
    @node_data_hash[attr_var] = attr_value
    #instance_variable_set("@#{attr_var}", attr_value)
    #dynamic method acting like an instance variable getter
    self.class.__send__(:define_method, "#{attr_var}".to_sym,
       lambda {@node_data_hash[attr_var]} )
    #dynamic method acting like an instance variable setter
    self.class.__send__(:define_method, "#{attr_var}=".to_sym, 
       lambda {|new_val| @node_data_hash[attr_var] = new_val} )
    #why not just use instance variables?
    #because instance variables don't have a callback method
    #that would allow me to update the data store (@node_data_hash)
    #the data store is needed to iterate over all values stored by 
    #the instance
  end
  
  #TODO: Add to spec
  def path_to_node_data
    raise "The category has not been set for #{self}" unless self.my_category
    self.class.namespace + '/' + self.my_category
  end

  def to_hash
    @node_data_hash
  end

  def save

    unless self.my_category
      raise ArgumentError, "Requires my_category to be set before saving"
    end
    #TODO: If parent categories are not mandatory the code raising an error can be removed
    #if self.parent_categories.nil? || self.parent_categories.empty?
    #  raise ArgumentError, "Requires at least one parent category to be set before saving"
    #end

    #make model directory
    my_dir = self.class.namespace + '/' + self.my_category + '/'
    FileUtils.mkdir_p(my_dir)

    node_data_file = my_dir + self.class.data_file_name
    node_data_hash = self.to_hash
    raise "No data found for #{self}" unless node_data_hash

    #desc_file = my_dir + BufsFileSystem.description_file_basename
    #self.description = 'This description was automatically generated on #{Time.now}' unless self.description
    #File.open(desc_file, 'w') { |f| f.write(self.description.to_s)} if self.description
    File.open(node_data_file, 'w') {|f| f.write(node_data_hash.to_json)}
    #file metadata is part of the data file itself (if it exists)
    #self  <-- Right thing to do, but need stability beofre changing (for testing)
  end

  def self.create_from_doc_node(node_obj)
    init_params = {}
    init_params['my_category'] = node_obj.my_category
    init_params['description'] = node_obj.description if node_obj.description
    new_bfs = self.new(init_params)
    new_bfs.add_parent_categories(node_obj.parent_categories)
    new_bfs.save
    if node_obj.get_attachment_names.nil? || node_obj.get_attachment_names.empty?
      #do nothing, easier to read like this
    else
      node_obj.get_attachment_names.each do |att_name|
        raw_data = node_obj.attachment_data(att_name)
        #att_file_name = self.namespace + '/' + new_bfs.my_category + '/' 
        new_bfs.add_raw_data(att_name, new_bfs.my_category, raw_data,
                             node_obj.file_metadata[att_name]) 
      end
    end
    return new_bfs.class.by_my_category(new_bfs.my_category).first
  end


  def add_parent_categories(new_cats)
    current_cats = orig_cats = self.parent_categories||[]
    new_cats = [new_cats].flatten
    current_cats += new_cats
    current_cats.uniq!
    current_cats.compact!
    if current_cats.size > orig_cats.size
      self.parent_categories = current_cats
      self.save
    end
  end
  alias :add_category :add_parent_categories
  alias :add_categories :add_parent_categories

  def remove_parent_categories(cats_to_remove)
    cats_to_remove = [cats_to_remove].flatten
    cats_to_remove.each do |remove_cat|
      self.parent_categories.delete(remove_cat)
    end
    self.save
    raise "temp error due to no parent categories existing" if self.parent_categories.empty?
  end

  #TODO: Rationalize with BufsInfoDoc
  #FIXME: my_cat not needed?
  def add_raw_data(file_name, my_cat, raw_data, file_modified_at = nil)
    #file_name = unescape(file_name)  #Hack to avoid escaping twice (and changing the name in the process)
    #content type is lost when data is saved into the file model.
    puts "Add Raw Data --- (Unesc) File Name: #{File.basename(file_name)}"
    esc_filename = ::BufsEscape.escape(file_name)
    puts "Add Raw Data --- (Esc) File Name: #{File.basename(esc_filename)}"
    raw_data_dir = @my_dir # + my_cat
    FileUtils.mkdir_p(raw_data_dir) unless File.exist?(raw_data_dir)
    raw_data_filename = raw_data_dir + '/' + esc_filename
    File.open(raw_data_filename, 'wb'){|f| f.write(raw_data)}
    puts "Model built at: #{raw_data_filename}"
    if file_modified_at
      File.utime(Time.parse(file_modified_at), Time.parse(file_modified_at), raw_data_filename)
    else
      file_modified_at = File.mtime(raw_data_filename).to_s     
    end
    @file_metadata = {'file_modified' => file_modified_at}
    @attached_files << raw_data_filename
    @filename = esc_filename
  end

  #TODO: Need to update spec to include multiple files 
  def add_data_file(filenames)
    filenames = [filenames].flatten
    filenames.each do |filename|
      my_dest_basename = ::BufsEscape.escape(File.basename(filename))
      #puts "Add Data File --- Basename (Esc) #{my_dest_basename}"
      @filename = my_dest_basename
      FileUtils.mkdir_p(@my_dir) unless File.exist?(@my_dir) #TODO Throw error if its a file
      my_dest = @my_dir + '/' + @filename
      @attached_files << my_dest
      same_file = filename == my_dest
      FileUtils.cp(filename, my_dest, :preserve => true, :verbose => true ) unless same_file
      self.file_metadata = {filename => {'file_modified' => File.mtime(filename).to_s}}
    end
  end

  def attached_files?
    #if @attached_files.size > 0
    #  return true
    #else
     
    #Its better to check the authorative model
    if Dir.file_data_entries(path_to_node_data).size > 0
      #raise "#{path_to_node_data.inspect}"
      #raise "#{Dir.file_data_entries(path_to_node_data).inspect}"
      return true
    else
      return false
    end
  end
  
  def list_attached_files
    #FIXME: Fix @attached_files to work or get rid of it and replace with this method
    Dir.file_data_entries(path_to_node_data)
  end

  def get_attachment_names
    list_attached_files.map {|fn| File.basename(fn)}
  end

  def remove_attached_files(att_basenames)
    att_basenames = [att_basenames].flatten
    att_esc_bn = att_basenames.collect {|bn| BufsEscape.escape(bn)}
    att_filenames = att_esc_bn.collect {|bn| path_to_node_data + '/' + bn}
    FileUtils.rm_f(att_filenames)
  end

  def get_file_data
    my_dest = @my_dir + '/' + @filename
    return  File.open(my_dest, 'rb'){|f| f.read}
  end

  #TODO: Which architecture for links? FileNode or InfoDoc/
  #TODO: Move links' methods to be part of data hash?
  

  def list_links
    node_link_file_name = path_to_node_data + '/' + self.class.link_file_name
    if File.exists?(node_link_file_name)
      return  JSON.parse(File.open(node_link_file_name) {|f| f.read})
    else
      return nil
    end
  end

  def add_links(links_to_add)
    links_to_add = [links_to_add].flatten
    updated_links = list_links||[] + links_to_add
    node_link_file_name = path_to_node_data + '/' + self.class.link_file_name
    File.open(node_link_file_name, 'w') {|f| f.write(updated_links.to_json)}
  end

  def remove_links(links_to_remove)
    links_to_remove = [links_to_remove].flatten
    if list_links
      updated_links = list_links - links_to_remove
      node_link_file_name = path_to_node_data + '/' + self.class.link_file_name
      File.open(node_link_file_name, 'w') {|f| f.write(updated_links.to_json)}
      return updated_links
    else
      return []
    end
  end

  def destroy_node
    if self.my_category
      #TODO: my_dir should be from path_to_node_data?
      my_dir = self.class.namespace + '/' + self.my_category + '/'
      p "Destroying: #{my_dir}"
      #rm_f(Dir.glob(my_dir + '*'))
      FileUtils.remove_dir(my_dir, :force => true)
      #how to set self to nil?
    else
      raise "Cannot destroy node, cannot determine its category, has it been saved?"
    end
    raise "Error, unable to delete file data: #{my_dir}" if File.exists?(my_dir)
  end
  alias destroy :destroy_node

end

