
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
require File.dirname(__FILE__) + '/../bufs_fixtures/model_fixtures/create_model_dir'


module BufsViewBuilderSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end


  

require BufsViewBuilderSpec::LibDir + 'bufs_view_builder'

FSModelDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_view_builder_spec/model/'
CreatedViewDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_view_builder_spec/view_created'
StaticViewDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_view_builder_spec/view_static'
BufsFileSystem.use_directory FSModelDir

describe BufsViewBuilder do
  before(:all) do
    @file_nodes = BufsFileSystem.all
  end

  it "should build a data view from the data model" do
    new_builder = BufsViewBuilder.new
    top_level_cats = ['a', 'b']
    top_level_nodes = []
    top_level_cats.each do |cat|
      top_level_nodes += @file_nodes.select {|n| n.my_category == cat}
    end
    puts "Building View with:"
    puts "Top Level Nodes: #{top_level_nodes.inspect}"
    puts "All Nodes size = #{@file_nodes.size}"
    new_builder.build_view(CreatedViewDir, top_level_nodes, @file_nodes, FSModelDir)
    #test that it worked
    Dir.chdir(CreatedViewDir)
    created_dir = Dir.glob("**/*")
    #p created_dir
    Dir.chdir(StaticViewDir)
    static_dir = Dir.glob("**/*")

    
    created_dir.sort.should == static_dir.sort
  end
  #Build View
  #Compare View
end

