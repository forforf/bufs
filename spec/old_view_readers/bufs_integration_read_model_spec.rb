
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'


module BufsReadModelSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end

  

require BufsReadModelSpec::LibDir + 'bufs_view_builder'

FSModelDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_spec/model/'
FSViewDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_spec/view/'
BufsFileSystem.name_space = FSModelDir

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
    new_builder.build_view(FSViewDir, top_level_nodes, @file_nodes, FSModelDir)
    #test that it worked
    Dir.chdir(FSViewDir)
    puts "View Directory glob #{Dir.glob("**/*")}"
  end

  #Build View
  #Compare View
end
