require 'fileutils'
require 'tree'

#TODO This needs a spec (testing was manual)
module UniqName
  #when files have the same basename, it will rename new_fn to have a unique
  #name from any of the listed files by adding on parts of the path name
  #a piece at a time
  def self.make(fns, fn2)
    puts "Making Name"
    existing_basenames = fns.map {|fn| File.basename(fn)}
    current_basename = File.basename(fn2)
    return current_basename unless existing_basenames.include? current_basename
    path = File.dirname(fn2)
    new_name = current_basename
    while existing_basenames.include? new_name
      #get the parent dirname and drop it from the path
      cur_dirname = File.basename(path)
      path = File.dirname(path)
      ext = File.extname(new_name)
      just_base = File.basename(new_name, ext)
      new_name = "#{just_base}_#{cur_dirname}#{ext}"
    end 
    new_fname = File.join(path, new_name)
  end
end

class FileFinder
  include UniqName
  IgnoreList = [/^links\.html/, /^__bfs*/]
  Breadcrumb = ".breadcrumb"
  def initialize
    #@orig_dir = Dir.pwd
    @path_history = []
    @files_found = {} #orig_name => new_name
    @work_queue = []
    @check_later = [] #for symlinks
  end

  def in_ignore_list?(f)
    rtn = false
    IgnoreList.each do |regex|
      rtn = rtn||(File.basename(f) =~ regex)
    end
    rtn
  end

  def find_files(root_dir=Dir.pwd)
    root_tree = Tree::TreeNode.new(File.basename(root_dir))
    tree_data = {:dir => root_dir, :node => root_tree }
    #@orig_dir = Dir.pwd
    #Dir.chdir(root_dir)
    #Make sure there are no breadcrumbs before starting
    crumbs = Dir.glob(File.join(root_dir, "**/.breadcrumb"))
    crumbs.each do |breadcrumb|
      FileUtils.rm(breadcrumb)
    end
    find_one_level(tree_data)
    #puts "Saved for Later: #{@check_later.inspect}"
    #max_link_recursion = 10 #move to visible config, set via Constant
    #while @check_later.size > 0 && max_link_recursion > 0
    #  @check_later.each do |f|
    #    find_one_level(f)
    #  end
    #  max_link_recursion -= 1
    #end
    #puts "DONE!"
    #puts "Found: #{@files_found.values.inspect}" ##{final_found_files.inspect}"
    #@files_found
    crumbs = Dir.glob(File.join(root_dir, "**/.breadcrumb"))
    crumbs.each do |breadcrumb|
      FileUtils.rm(breadcrumb)
    end
    #Dir.chdir(@orig_dir)
    root_tree.each do |node|
      #FIXME: add support for duplicted filenames using renaming module
      @files_found[node.content] = File.basename(node.name) if node.content && node.name
    end
    #@files_found.compact!
    @files_found
  end

  def find_one_level(tree_data)
    return unless tree_data
    dir = tree_data[:dir] 
    current_node = tree_data[:node]  
    return unless dir
    current_level_files =  Dir.glob("#{dir}/*")
    current_level_files.delete_if {|f| in_ignore_list?(f)} #File.exist?(File.join(f, ".breadcrumb"))} #@path_history.include?(f)}
    #if File.exist?("#{dir}/#{Breadcrumb}")
     #FIXME: Ouch a coupling between classes, figure out how to get rid of it
    #  breadcrumb_files = Dir.glob("#{dir}/__bfs_AllFiles/*")
     # breadcrumb_files.each do |bf|
      #  add_file(bf)
      #end
    #end
    current_level_files.each do |cf|
      #puts "File: #{cf.inspect} File: #{File.stat(cf).file?.inspect}"
      #puts "File: #{cf.inspect} Dir: #{File.stat(cf).directory?.inspect}"
      add_file(cf, current_node) if File.stat(cf).file? #both links and normal
      check_directory(cf, current_node) if File.stat(cf).directory? #both links and normal
    end
    insert_breadcrumb(dir)
    #puts "Next Directory: #{@work_queue[0].inspect}"
    find_one_level(@work_queue.shift)
  end

  def add_file(f, current_node)
    puts "Adding #{f.inspect}"
    f = resolve_symlink(f) if File.symlink?(f)
    current_node.content = f
    #if @files_found.values.include?(File.basename(f))
    #  puts "Found duplicate basename of #{File.basename(f)}"
    #  existing_f = @files_found.key(File.basename(f))
    #  if FileUtils.identical?(f, existing_f)
    #    puts "But ignoring it because it's identical to existing one"
    #    #ignore new file
    #  else #not identical, need to rename
    #    puts "Renaming it because it's a different file"
    #    @files_found[f] = File.basename(UniqName.make(@files_found.values,f))
    #    puts "DUPE NAME!!(#{f.inspect}:Now:  #{ @files_found[f].inspect }"
    #  end
    #else #file is not already in found files
    #   puts "New file added to list"
    #   @files_found[f] = File.basename(f)
    #   puts "Added: #{f.inspect}"
    #end
  end

  def check_directory(f, current_node)
    #assumes directory names are unique
    final_f = resolve_symlink(f)  #need to DRY this up with the rest of the method
    parent_nodes = current_node.parentage || []
    parent_fnames = parent_nodes.map {|pn| pn.name}
    parent_basenames = parent_fnames.map {|fn| File.basename(fn)}
    return if parent_basenames.include? File.basename(final_f) #we've looped to a parent
    if File.symlink?(f)
       #puts "Dir Symlink #{f.inspect}"
       #@check_later << f
       linked_to = resolve_symlink(f)
       child_node = Tree::TreeNode.new(linked_to)
       current_node << child_node
       @work_queue << {:dir => linked_to, :node => child_node}
    else
       child_node = Tree::TreeNode.new(f)
       current_node << child_node
       @work_queue << {:dir => f, :node => child_node}
    end
  end

  def resolve_symlink(f)
    final_f = f
    while File.symlink?(final_f) 
      final_f = File.readlink(final_f)
    end
    return final_f
  end

  def remove_duplicated_symlinked_files(files)
    files.delete_if do |f|
      rtn = false
      if File.symlink?(f)
        wkg_list = files - [f]
        wkg_list.each do |wf|
          rtn = true if FileUtils.identical?(f, wf)
        end
      end
      rtn
    end
    files
  end

  def insert_breadcrumb(dir)
    #puts "Inserting in #{dir.inspect}"
    File.open(File.join(dir,".breadcrumb"), "w"){|f| f.write(Time.now)}
  end
end

