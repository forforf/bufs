require 'fileutils'  


FilesOfChildrenDirName = "__bfs_Children"
  def view_of_files_from_subdirs(dir)
    just_files = {}
    all_entries = Dir.glob("#{dir}/**/*")
    working_entries = all_entries.delete_if {|s| s =~ /#{FilesOfChildrenDirName}/}
    working_entries.each do |f|
      if File.stat(f).file?
        base_name = File.basename(f)
        ext = File.extname(f)
        base_no_ext = File.basename(f, ext)
        parent_dir = File.basename(File.dirname(f))
        link_name = "#{base_no_ext}_#{parent_dir}#{ext}"
        just_files[f] = link_name
      end
    end
    #puts "Making Dir: #{FilesOfChildrenDirName.inspect}"
    main_child_dir = "#{dir}/#{FilesOfChildrenDirName}"
    FileUtils.mkdir(main_child_dir) unless File.exist?(main_child_dir)
    child_dir = dir + '/' + FilesOfChildrenDirName
    puts Dir.glob("#{child_dir}/*").join("\n")
    FileUtils.rm Dir.glob("#{child_dir}/*")
    just_files.each do |file_name, link_name|
      FileUtils.ln_s(file_name, "#{child_dir}/#{link_name}")
    end
  end

view_of_files_from_subdirs(Dir.pwd)
