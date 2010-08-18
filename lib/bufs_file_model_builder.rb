require 'fileutils'

class BufsFileModelBuilder
IgnoreList =  [/^__bfs*/, /^__bufs*/]
DataFileName = '.node_data.json'

  def in_ignore_list?(f)
    rtn = false
    IgnoreList.each do |regex|
      rtn = rtn||(File.basename(f) =~ regex)
    end
    rtn
  end


  def build_from(file_view_tree, to_model_dir)
    FileUtils.mkdir_p(to_model_dir) unless File.exist?(to_model_dir)
    file_view_tree.each do |node|
      next if node.isRoot? || in_ignore_list?(node.name)
      #TODO Change node_dir to modeL_node or something to distinguish it from tree
      node_dir = File.join(to_model_dir, node.name)
      if File.exist?(node_dir)
        add_node_data(node, node_dir)
      else
        FileUtils.mkdir(node_dir)
        create_node_data(node, node_dir)
      end
      if node.content
        node_files = node.content["files"]
        node_html_links = node.content["html_links"]
        node_description = node.content["description"]
        add_files(node_dir, node_files) if node_files
        add_links(node_dir, node_html_links) if node_html_links
        add_description(node_dir, node_description) if node_description
      end
    end
  end

  def add_node_data(node, dir)
    data_file = File.join(dir, DataFileName)
    parent_dir = File.basename(File.dirname(dir))
    json_data = File.open(data_file, 'r'){|f| f.read}
    node_data = JSON.parse(json_data)
    node_data["parent_categories"] << parent_dir
    new_json_data = node_data.to_json
    File.open(data_file, 'w'){|f| f.write(new_json_data)}
  end

  def create_node_data(node, dir)
    data_file = File.join(dir, DataFileName)
    parent_dir = File.basename(File.dirname(dir))
    node_data = {"my_category" => node.name, "parent_categories" => [parent_dir]}
    json_data = node_data.to_json
    File.open(data_file, 'w'){|f| f.write(json_data)}
  end
  
  def add_files(dir, files)
    FileUtils.cp(files, dir)
  end

  def add_links(dir, links)
    link_file = File.join(dir,'.link_data.json')
    link_data = links.to_json
    File.open(link_file, 'a'){|f| f.write(link_data)}
  end

  def add_description(dir, description)
    data_file = File.join(dir, DataFileName)
    json_data = File.open(data_file, 'r') {|f| f.read}
    node_data = JSON.parse(json_data)
    unless node_data["description"] = description
      node_data["description"] += "\n" + description
      new_json_data = node_data.to_json
      File.open(data_file, 'w') {|f| f.write(new_json_data)}
    end
  end
end
