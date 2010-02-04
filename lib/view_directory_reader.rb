#
require File.dirname(__FILE__) + '/abstract_node'

#duck punch Dir so that we can ignore useless entries
class Dir
  def self.working_entries(dir=Dir.pwd)
    ignore_list = ['thumbs.db','all_child_files']
    all_entries = Dir.entries(dir)
    wkg_entries = all_entries.delete_if {|x| x[0] == '.'}
    wkg_entries = wkg_entries.delete_if {|x| ignore_list.include?(x.downcase)}
    return wkg_entries
  end
end

class ReaderNode < ReadOnlyNode
  #ReadOnlyNode has some methods that must be overidden
  #my_category, parent_categories, file_metadata, get_file_data

  attr_accessor :my_category, :parent_categories, :file_metadata, :sub_entries 
              
  def get_file_data(file_name=nil)
    nil
  end

  def initialize(file_name)
    @file_name = file_name
    @my_category = File.basename(file_name)
    @parent_path = File.dirname(file_name)
    @parent_categories = [File.basename(@parent_path)]
    @sub_entries = []
    @file_metadata = nil
  end
end

class ReaderDirNode < ReaderNode
  def initialize(file_name)
    super(file_name)
    @sub_entries_basenames = Dir.working_entries(file_name)
    @sub_entries = @sub_entries_basenames.map{|entry| file_name +'/' + entry}
  end
end

class ReaderLinkNode < ReaderNode
  def initialize(file_name)
    super(file_name)
    #my_category for link and target should be identical
    @my_category.gsub!(".lnk","")
  end
end

class ReaderFileNode < ReaderNode
  def initialize(file_name)
    super(file_name)
    @file_metadata = make_file_metadata(file_name)
  end

  def make_file_metadata(data_file_name = @file_name)
    ptr = File.basename(data_file_name)
    file_mod_time = File.mtime(data_file_name).to_s
    {ptr => {"file_modified" => file_mod_time}}
  end

  #a file can only have one data source
  def get_file_data(file_basename=@my_category)
    file_basename = File.basename(file_basename) #only basenames are used in models
    data_file_name = @parent_path + '/' + file_basename
    File.open(data_file_name, 'rb') {|f| f.read}
  end

end

module ViewNodeFactory
  def self.make_reader_node(file_name)
    case File.ftype(file_name)
      when "link"
        return ReaderLinkNode.new(file_name)
      when "directory"
        return ReaderDirNode.new(file_name)
      when "file"
        return ReaderFileNode.new(file_name)
      else
        raise "unknown type #{File.ftype(file_name)}"
    end
  end
end


class ViewDirectoryReader

  def initialize(init_dir = Dir.pwd)
    @init_dir = init_dir
    @directory_entries_yet_to_be_read = []
    @bufs_nodes = []
  end

  def read_directory(dir = @init_dir)
    #dir = top level node and will the 'super parent'
    #TODO Expand path for dir?
    top_basename_entries = Dir.working_entries(dir)
    top_fullpath_entries = top_basename_entries.map {|entry| dir + entry}

    #there might be better way
    #the current structure is a bit confusing to follow
    #since its working on a list of entries in a directory, rather than
    #on the directory itself.
    entries_to_read = top_fullpath_entries
    while entries_to_read
      puts "Started Read Loop"
      read_one_level_of_entries(entries_to_read)

      #reading the entries will push yet to be read entries into the queue
      entries_to_read = @directory_entries_yet_to_be_read.shift
    end
    return @bufs_nodes
  end

  def read_one_level_of_entries(dir_entries)
    dir_entries.each do |entry|
      puts "-- Currently Reading: #{entry}"
      puts "--- Making Bufs Compatible Node with #{entry}"
      reader_node = ViewNodeFactory.make_reader_node(entry)
      if reader_node.sub_entries && reader_node.sub_entries.size > 0
	#used to recurse through directories
        @directory_entries_yet_to_be_read << reader_node.sub_entries
      end
      # determine what kind of entry it is
      # build or update a node from that entry
      # add node to array
      @bufs_nodes << reader_node
    end
    return @bufs_nodes
  end
end
#
# start at root

# collect root entries
# scrape root entries
#   add sub_entries to queueu
#   build nodes (my_cat, parent_cat, content typefile_meta, file)
#   add nodes to array
#   scrape again
