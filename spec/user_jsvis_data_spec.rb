
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'


module BufsVizDataSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end

require 'pp'  

require BufsVizDataSpec::LibDir + 'bufs_jsvis_data'
require BufsVizDataSpec::LibDir + 'user_doc'

#FSModelDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_view_builder_spec/model/'
#CreatedViewDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_view_builder_spec/view_created'
#StaticViewDir = BufsFixtures::ProjectLocation  + 'sandbox_for_specs/bufs_view_builder_spec/view_static'
#BufsFileSystem.name_space = FSModelDir

describe BufsJsvisData do 

  before(:each) do
    @user1_id = "JsvisDataUser01"
  end

  it "should return JSON structure of arbitrary depth from the data model" do
    CouchDB = CouchRest.database!('http://127.0.0.1:5984/bufs_integration_test_spec')
    #BufsInfoDoc.set_name_space(CouchDB)
    user1_db = UserDB.new(CouchDB, @user1_id)
    user1_docClass = UserDB.user_to_docClass[@user1_id]
    #nodes = BufsInfoDoc.all
    nodes = user1_docClass.all
    jvis = BufsJsvisData.new(nodes)
    top_cat= 'view' #top category
    depth = 4
    jvis_data = jvis.json_vis(top_cat, depth)   
    #jvis_data.each do |k,v|
    #  puts "Level: #{k}:"
    #  v.each do |n|
    #    p n.my_category
    #  end
    #end
    #p [].to_json
    puts "----"
    puts jvis_data
    default_json = '{"id":"dummy_view","name":"view","data":{},"children":[]}'
    #JSON.parse(jvis_data)
    jvis_data.should == default_json
  end

  #Build View
  #Compare View
end
