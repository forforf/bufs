
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
require 'json'

module BufsFileModelBuilderSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end
  

require BufsFileModelBuilderSpec::LibDir + 'bufs_file_model_builder'
require BufsFileModelBuilderSpec::LibDir + 'bufs_file_view_reader'


StaticViewDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_file_model_builder_spec/view_static/'
CreatedModelDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_file_model_builder_spec/model_created'
StaticModelDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_file_model_builder_spec/model_static'
#StaticViewDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_view_builder2_spec/view_static'
#BufsFileSystem.use_directory FSModelDir

describe BufsFileModelBuilder do
  before(:each) do
    FileUtils.rm_rf(CreatedModelDir)
    @view_tree = BufsFileViewReader.new(StaticViewDir).tree
  end

  it "should do something" do
    builder = BufsFileModelBuilder.new
    to_model_dir = CreatedModelDir
    builder.build_from(@view_tree, to_model_dir)

    #verify results

    Dir.chdir(CreatedModelDir)
    created_dir = Dir.glob("**/*")
    #p created_dir
    Dir.chdir(StaticModelDir)
    static_dir = Dir.glob("**/*")


    created_dir.sort.should == static_dir.sort
  end
end

=begin
module ModelTreeHelper
  def self.model_nodes_to_tree_nodes(model_hash)
    flat_tree = Tree::TreeNode.new("flat_root")
    model_hash.each do |node_name, node_content|
      tree_node = Tree::TreeNode.new(node_name, node_content)
      flat_tree << tree_node
    end
    flat_tree
  end
end


describe Tree::TreeNode do
  it "should find nodes" do
    root = Tree::TreeNode.new("root")
    root.find_nodes("root").size.should == 1
    root.find_nodes("root").first.should == root
    root.find_nodes("not here").size.should == 0

    achild = Tree::TreeNode.new("a")
    bchild = Tree::TreeNode.new("b")
    root << achild
    root << bchild
    root.find_nodes("a").first.should == achild
    root.find_nodes("b").first.should == bchild
    achild2 = Tree::TreeNode.new("a")
    bchild << achild2
    root.find_nodes("a").size.should == 2
    root.find_nodes("a").first.should == achild
    root.find_nodes("a").last.should == achild2
  end
end

describe BufsFileViewReader do
  include ModelTreeHelper

  before(:all) do
    #TODO: add unwanted files to test directory to ensure filtering
    model_json = File.open(StaticModelFile){|f| f.read}
    @model = JSON.parse(model_json)
    @tree_model = ModelTreeHelper.model_nodes_to_tree_nodes(@model)
  end

  it "should read the view and create a tree" do
    #initial conditions already set
    #test
    tree_view = BufsFileViewReader.new(ViewDir).tree
    #check results
    tree_view.printTree
    #TODO: THis doesn't validate that all parent_categories relationships exist, only that it's a valid one
    tree_view.each do |node|
        
        #puts "===="
        #puts "Tree View"  
        node_content_to_model_format = {"node_data" => {"my_category" => node.name,
                                                        "parent" => (node.parent.name if node.parent && !node.parent.isRoot?),
                                                        "description" => "#{node.name} description"} }
       # 
       # puts "#{node.name} -> content: #{node_content_to_model_format}"
       # puts "Tree Model"
       # if @tree_model[node.name]
       # 
       #   puts "-> #{@tree_model[node.name].name} #Content: #{@tree_model[node.name].content.inspect}"
       # else
       #   puts "missing from tree model!!!"
       # end
       # puts "===="
        unless node.isRoot?
          node_cat = node_content_to_model_format["node_data"]["my_category"]
          node_parent = node_content_to_model_format["node_data"]["parent"]
          node_desc = node_content_to_model_format["node_data"]["description"]
        end
        #TODO: Very brittle testing any better way?
        @tree_model.size > 3
        node.size > 3
        model_cat = nil
        model_parents = nil
        model_desc = nil
        if  @tree_model[node.name] && !@tree_model[node.name].isRoot?
          model_cat = @tree_model[node.name].content["node_data"]["my_category"]
          model_parents = @tree_model[node.name].content["node_data"]["parent_categories"]
          model_desc = @tree_model[node.name].content["node_data"]["description"]
        end
        if model_cat && model_parents && model_desc && node_cat && node_parent && node_desc
          model_cat.should == node_cat
          model_parents.should include node_parent if model_parents && node_parent
          model_desc.should == node_desc
        else
          tree_model_name = nil
          tree_model_name = @tree_model[node.name].name if @tree_model[node.name]
          puts "Skipped comparing node: #{node.name} to model #{tree_model_name}"
          puts "likely because the parent node is a root node (need to fix)"
        end
    end
  end

  it "should have node_path capability for a root node" do
    bvr = BufsFileViewReader.new(ViewDir)
    root = Tree::TreeNode.new("root")
    bvr.tree_node_path(root).should == '/'
    anode =  Tree::TreeNode.new("a")
    root << anode
    bnode =  Tree::TreeNode.new("b")
    root << bnode
    bvr.tree_node_path(root["a"]).should == '/a/'
    bvr.tree_node_path(root["b"]).should == '/b/'
    aanode = Tree::TreeNode.new("aa")
    anode << aanode
    bvr.tree_node_path(root["a"]["aa"]).should == '/a/aa/'
    bvr.tree_node_path(root.find_nodes('aa').first).should == '/a/aa/'
    #bvr.tree.find_nodes('bcc').each do |node|
    #  p bvr.tree_node_path(node).inspect
    #end
  end


  it "should provide a list of all files contained in the lineage" do
    bfvr = BufsFileViewReader.new(ViewDir)
    puts "Troublesmoe paths"
    bfvr.tree.find_nodes('ab').each do |node|
      puts "#{node.name}: #{node.content}"
    end
    #test
    #TODO: Figure out automated test for file_list
    root_file_list = bfvr.file_list
    root_file_list.each do |src, lnks|
     puts "#{src}"
     lnks.each do |lnk|
       puts "   <- #{lnk.gsub('/media-ec2/ec2a/projects/bufs/bufs_fixtures/','')}"
     end
    end
    #verify results
  end

  it "should provide a list of all links contained in the lineage" do
    bfvr = BufsFileViewReader.new(ViewDir)
    puts "Troublesmoe paths"
    bfvr.tree.find_nodes('ba').each do |node|
      puts "#{node.name}: #{node.content}"
    end
    #test
    #TODO: Figure out automated test for file_list
    root_html_link_list = bfvr.html_link_list
    root_html_link_list.each do |view_path, lnks|
     puts "#{view_path}"
     lnks.each do |lnk|
       puts lnk.inspect#"   <- #{lnk.gsub('/media-ec2/ec2a/projects/bufs/bufs_fixtures/','')}"
     end
    end
    #verify results
  end

end
=end
