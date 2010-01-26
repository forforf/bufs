#ProjectLocation = '/media-ec2/ec2a/projects/bufs/'


#FSSrcLocation = ProjectLocation + 'lib/'


require 'cgi'
#require FSSrcLocation + 'scout_info_node'


#TODO This constant should be set by the calling context
#ModelDir = 'C:\Documents and Settings\dmartin\My Documents\tmp\raw_data_model_spec'


#JSON Hack
require 'json'

class Dir  #monkey patch  (duck punching?)
  def self.working_entries(dir=Dir.pwd)
    ignore_list = ['thumbs.db','all_child_files']
    all_entries = Dir.entries(dir)
    wkg_entries = all_entries.delete_if {|x| x[0] == '.'}
    wkg_entries = wkg_entries.delete_if {|x| ignore_list.include?(x.downcase)}
    return wkg_entries
  end
end


class BufsFileSystem
  class << self 
    attr_accessor :name_space, :parent_categories_file_basename,
      :description_file_basename, :win_dir, :linux_dir
  end
  @name_space = nil
  @win_dir = 'windows_format'
  @linux_dir = 'mac_linux_format'
  @parent_categories_file_basename = 'parent_categories.txt'
  @description_file_basename = 'description.txt'

  attr_accessor :parent_categories, :my_category, :description, :file_metadata, :filename

  def self.set_name_space(model_dir)
     FileUtils.mkdir_p(File.expand_path(model_dir))
     BufsFileSystem.name_space = model_dir
  end


  def self.all
    unless File.exists?(BufsFileSystem.name_space)
      raise "The File System Directory to work from does not exist: #{BufsFileSystem.name_space}"
    end
    all_nodes = []
    my_dir = BufsFileSystem.name_space + '/'
    all_entries = Dir.working_entries(my_dir)
    all_entries.each do |cat_entry|
      wkg_dir = my_dir + cat_entry + '/'
      cat_name = cat_entry
      parent_cats = JSON.parse(File.open(wkg_dir + BufsFileSystem.parent_categories_file_basename){|f| f.read})
      desc = File.open(wkg_dir + BufsFileSystem.description_file_basename){|f| f.read}
      file_mod_time = File.mtime(wkg_dir + cat_entry) if File.exists?(wkg_dir + cat_entry)
      f_metadata = {'file_modified' => file_mod_time.to_s} if file_mod_time
      all_nodes << BufsFileSystem.new(:parent_categories => parent_cats,
                                           :my_category => cat_name,
                                           :description => desc,
                                           :file_metadata => f_metadata)

    end
    all_nodes
  end

  #TODO add to spec
  def self.by_my_category(my_cat)
    my_dir = BufsFileSystem.name_space + '/'
    my_cat_dir = my_cat
    wkg_dir = my_dir + my_cat_dir + '/'
    if File.exists?(wkg_dir)
      cat_files = Dir.working_entries(wkg_dir)
      #TODO This is brittle, tie the meta categories names to the assignment at creation
      cat_files.delete('parent_categories.txt')
      cat_files.delete('description.txt')
      bfss = []
      cat_files.each do |cat_file_name|
        parent_cats = JSON.parse(File.open(wkg_dir + BufsFileSystem.parent_categories_file_basename){|f| f.read})
        desc = File.open(wkg_dir + BufsFileSystem.description_file_basename){|f| f.read}
        puts "BFS.by_my_category location for attachment file: #{wkg_dir + cat_file_name.inspect}"
        file_mod_time = File.mtime(wkg_dir + cat_file_name) if File.exists?(wkg_dir + cat_file_name)
        f_metadata = {'file_modified' => file_mod_time.to_s} if file_mod_time
        puts "BFS.by_my_category file md: #{f_metadata.inspect}"
        bfs = BufsFileSystem.new(:parent_categories => parent_cats,
                                         :my_category => my_cat,
                                         :description => desc,
                                         :file_metadata => f_metadata)
        bfs.filename = cat_file_name
        bfss << bfs
        end
      return bfss
    else
      return nil
    end
  end

  def initialize(init_params = {})
    init_params.each do |attr_name, attr_value|
      iv_set(attr_name, attr_value)
    end
    @my_dir = BufsFileSystem.name_space + '/' + self.my_category + '/' if self.my_category
  end

  def iv_set(attr_var, attr_value)
    instance_variable_set("@#{attr_var}", attr_value)
  end

  def save

    unless self.my_category
      raise ArgumentError, "Requires my_category to be set before saving"
    end
    if self.parent_categories.nil? || self.parent_categories.empty?
      raise ArgumentError, "Requires at least one parent category to be set before saving"
    end
    #make model directory
    my_dir = BufsFileSystem.name_space + '/' + self.my_category + '/'
    FileUtils.mkdir_p(my_dir)
    cat_file = my_dir + BufsFileSystem.parent_categories_file_basename


    #p parent_categories.to_json.inspect
    File.open(cat_file, 'w') {|f| f.write(self.parent_categories.to_json)} if self.parent_categories
    desc_file = my_dir + BufsFileSystem.description_file_basename
    self.description = 'This description was automatically generated on #{Time.now}' unless self.description
    File.open(desc_file, 'w') { |f| f.write(self.description.to_s)} if self.description
    #file metadata is part of the data file itself (if it exists)
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

  def add_raw_data(file_name, my_cat, raw_data, file_modified_at = nil)
    #content type is lost when data is saved into the file model.
    esc_filename = CGI.escape(file_name)
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
    @filename = esc_filename
  end

  #TODO: Currently this only allows a single file stored in the node
  #this is ok for my purposes, but I need to fix this to be consistent with
  #other node types for future compatibility.  Same issue for get file
  def add_data_file(filename)
    #my_dir = BufsInfoFileSystem.name_space + '/' + self.my_category + '/'
    my_dest_basename = CGI.escape(File.basename(filename))
    @filename = my_dest_basename
    @my_dir #+ my_dest_basename
    FileUtils.mkdir_p(@my_dir) unless File.exist?(@my_dir) #TODO Throw error if its a file
    my_dest = @my_dir + '/' + @filename
    FileUtils.cp(filename, my_dest, :preserve => true, :verbose => true )
    self.file_metadata = {'file_modified' => File.mtime(filename).to_s}
  end

  def get_file_data
    my_dest = @my_dir + @filename
    return  File.open(my_dest, 'rb'){|f| f.read}
  end

  #TODO Add to spec
  def destroy
    if self.my_category
      my_dir = BufsFileSystem.name_space + '/' + self.my_category + '/'
      #rm_f(Dir.glob(my_dir + '*'))
      FileUtils.remove_dir(my_dir, :force => true)
      #how to set self to nil?
    else
      raise "Cannot destroy node, cannot determine its category, has it been saved?"
    end
  end



  #def == (other)
  #  my_node = [self.parent_categories.sort, self.my_category, self.description, self.file_metadata]
  #  other_node = [other.parent_categories.sort, other.my_category, other.description, other.file_metadata]
  #  if my_node == other_node
  #    return true
  #  else
  #    p my_node
  #    p other_node
  #    return false
  #  end
  #end

end
