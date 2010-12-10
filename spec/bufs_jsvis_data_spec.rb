#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '../lib/helpers/require_helper')

require Bufs.spec_helpers 'bufs_sample_dataset'
require Bufs.lib 'bufs_jsvis_data'


describe BufsJsvisData do
  before(:all) do
    sample_data = PopulatePersistenceModels::Sample1::DataSet
    ppm = PopulatePersistenceModels
    @user_classes = ppm.add_data_set_to_model(sample_data)
  end
 
  it "should initialize from data provided by the persistence models" do
    @user_classes.each do |user_class|
      #puts "User Class: #{user_class.name}"
      node_list = user_class.all
      #puts "Node List: #{node_list.size}"
      vis_data = BufsJsvisData.new(user_class.name, node_list)
      vis_data.graph.class.should == RGL::DirectedAdjacencyGraph
      vis_data.graph.acyclic?.should == false
      #p user_class.name
      vis_data.graph.size.should == 13
      #p vis_data.graph.vertices.map{|v| v.node_name}
      no_parents = vis_data.graph_data[:no_parents]
      #p no_parents.map{|n| n.my_category}.inspect
      no_parents.size.should == 3
      no_parents.first.class.name.should =~ /^BufsNodeFactory::Bufs/
      
    end
  end
  
  it "should provide nodes to a certain depth" do
    @user_classes.each do |user_class|
      top_node1 = user_class.call_view(:my_category, "a").first
      top_node2 = user_class.call_view(:my_category, "b").first
      top_node3 = user_class.call_view(:my_category, "c").first
      top_node1.parent_categories_add(user_class.name)
      top_node2.parent_categories_add(user_class.name)
      top_node3.parent_categories_add(user_class.name)
      top_node1.__save
      top_node2.__save
      top_node3.__save
      node_list = user_class.all
      #label top nodes
      
      vis_data = BufsJsvisData.new(user_class.name, node_list)
      jsvis_json = vis_data.json_vis_tree(user_class.name, 4)
      jsvis_json["id"].should == user_class.name
      jsvis_json["name"].should == user_class.name
      #TODO: Do better check of subdata
      jsvis_json["data"].should == jsvis_json["data"]  #tests for existence
      jsvis_json["children"].class.should == Array
      sorted_children = jsvis_json["children"].sort_by {|ch| ch["id"]}
      sorted_children.map{|c| c["id"]}.should ==["a", "b","c"]
      grandkids = {}
      sorted_children.each do |child_hash|
        id = child_hash["id"]
        grandkids[id] = child_hash["children"]
      end
      sort_gkidsa = grandkids["a"].sort_by{|ch| ch["id"]}
      sort_gkidsa.map{|gk| gk["id"]}.should == ["aa", "ab", "ac"]
      sort_gkidsb = grandkids["b"].sort_by{|ch| ch["id"]}
      sort_gkidsb.map{|gk| gk["id"]}.should == ["ba", "bb", "bc"]
      sort_gkidsb.map{|gk| gk["id"]}.should == ["ba", "bb", "bc"]
      sort_gkidsb = grandkids["c"].sort_by{|ch| ch["id"]}
      sort_gkidsb.map{|gk| gk["id"]}.should == ["cc"]
      sort_gkidsb.map{|gk| gk["id"]}.should == ["cc"]
      
      node_a = sort_gkidsa.first["children"].first
      node_a["id"].should == "a"
      node_aaa = sort_gkidsa.first["children"].last
      node_aaa["children"].first["id"].should == "ab"
      
      jsvis_json.first.should == ["id", user_class.name]
    end
  end
end

