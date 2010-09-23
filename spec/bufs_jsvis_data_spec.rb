require File.join(File.dirname(__FILE__) , 'helpers/bufs_sample_dataset')
require File.join(File.dirname(__FILE__), '../lib/bufs_jsvis_data')


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
      p user_class.name
      vis_data.graph.size.should == 14 #includes root
      p vis_data.graph.vertices.map{|v| v.node_name}
      no_parents = vis_data.graph_data[:no_parents]
      no_parents.size.should == 2
      no_parents.first.class.name.should =~ /^BufsNodeFactory::Bufs/
      
    end
  end
  
  it "should provide nodes to a certain depth" do
    @user_classes.each do |user_class|
      node_list = user_class.all
      vis_data = BufsJsvisData.new(user_class.name, node_list)
      vis_data.json_vis(user_class.name, 4)
    end
  end
end

