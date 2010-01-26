#ANSpecProjectLocation = '/media-ec2/ec2a/projects/bufs/'
#TestDirBaseLocation = ProjectLocation + 'sandbox_for_specs/'
#ModelDir = TestDirBaseLocation + 'view_builder/model_dir'
#ViewDir = TestDirBaseLocation + 'view_builder/view_dir/'
require 'couchrest'
#doc_db_name = "http://bufs.younghawk.org:5984/bufs_test_spec/"
#CouchDB = CouchRest.database!(doc_db_name)
#CouchDB.compact!

require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'
CouchDB = BufsFixtures::CouchDB

module AbsNodeSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
  FileModelDir = File.dirname(__FILE__) + '/../sandbox_for_specs/abs_node_spec/model'
end


require AbsNodeSpec::LibDir + 'abstract_node'
#BufsInfoDoc.set_name_space(CouchDB)
#ANS_NS = ANSpecProjectLocation + 'sandbox_for_specs/file_system_specs/raw_data_model_spec'
#BufsFileSystem.set_name_space(AbsNodeSpec::FileModelDir)


describe AbstractNode do
  before(:all) do
    BufsInfoDoc.set_name_space(CouchDB)
    BufsFileSystem.set_name_space(AbsNodeSpec::FileModelDir)
    @test_files = BufsFixtures.test_files
    @required_fields1 = {:my_category => 'test_an1', :parent_categories => ['dad','mom']}
    @optional_fields1 = {:description => 'a lovely shade of indigo'}
    @initial_fields1 = @required_fields1.merge(@optional_fields1) #or should this be the other way?
    @baseline_fields1 = @initial_fields1.dup #needed because of couchrest weirdness
    @bufs_info_doc = BufsInfoDoc.new(@initial_fields1)
    #@bufs_info_doc.add_data_file(@test_files['binary_data3_pptx'])
    @bid_db_size = BufsInfoDoc.all.size

    @required_fields2 = {:my_category => 'test_an1', :parent_categories => ['mom','dad']}
    @optional_fields2 = {:description => 'a lovely shade of muave'}
    @initial_fields2 = @required_fields2.merge(@optional_fields2) #or should this be the other way?
    @baseline_fields2 = @initial_fields2.dup #needed because of couchrest weirdness
    @bufs_file_system = BufsFileSystem.new(@initial_fields2)
    #@bufs_file_system.add_data_file(@test_files['binary_data3_pptx'])
    @bfs_db_size = BufsFileSystem.all.size

    @required_fields_x1 = {:my_category => 'test_x1', :parent_categories => ['dad','mom']}
    @optional_fields_x1 = {:description => 'a lovely shade of indigo'}
    @initial_fields_x1 = @required_fields_x1.merge(@optional_fields_x1) #or should this be the other way?
    @baseline_fields_x1 = @initial_fields_x1.dup #needed because of couchrest weirdness
    @bufs_info_doc_x1 = BufsInfoDoc.new(@initial_fields_x1)

  end

  it "should create nodes of the proper class" do
    bids = BufsInfoDoc.all
    bids.size.should > 0
    bids.size.should == @bid_db_size
    puts "Number of BufsInfoDoc records: #{bids.size}"
    bids.each do |bid|
      an = AbstractNode.create(bid)
      an.class.should == DBDocNode
      an.my_category.should == bid.my_category
      an.parent_categories.should == bid.parent_categories
      an.description.should == bid.description      
    end

    bfs = BufsFileSystem.all
    puts "Number of BufsFileSystem records: #{bfs.size}"
    bfs.each do |bf|
      an = AbstractNode.create(bf)
      an.class.should == FileSystemDocNode
      an.my_category.should == bf.my_category
      an.parent_categories.should == bf.parent_categories
      an.description.should == bf.description
    end
  end

  it "should be able to determine equivalent node references" do
    an1 = AbstractNode.create(@bufs_info_doc)
    an2 = AbstractNode.create(@bufs_file_system)
    an_x = AbstractNode.create(@bufs_info_doc_x1)
    an1.same_node_reference(an2).should == true
    an2.same_node_reference(an1).should == true
    an1.same_node_reference(an_x).should == false
    an2.same_node_reference(an_x).should == false
    an_x.same_node_reference(an1).should == false
  end

  it "should be able to determine equivalent nodes" do
    an1 = AbstractNode.create(@bufs_info_doc)
    an2 = AbstractNode.create(@bufs_file_system)
    bid2 = @bufs_info_doc.dup
    an_x = AbstractNode.create(@bufs_info_doc_x1)
    an1.should == an2
    an2.should == an1
    an1.should_not == an_x
    an_x.should_not == an1
  

    _bufs = BufsInfoDoc.by_my_category(:key => @bufs_info_doc.my_category)  #eliminate from the database if it exists
    _bufs.first.destroy if _bufs && _bufs.first 

    @bufs_info_doc.save
    saved_doc = BufsInfoDoc.get(@bufs_info_doc['_id'])
    an1.should == AbstractNode.create(saved_doc)
    an2.should == AbstractNode.create(saved_doc)
    saved_doc.add_data_file(@test_files['binary_data3_pptx'])
    saved_doc_w_att = BufsInfoDoc.get(saved_doc['_id'])
    an1s = AbstractNode.create(saved_doc_w_att)
    an1s.should_not == an2
  
    @bufs_file_system.save
    @bufs_file_system.add_data_file(@test_files['binary_data3_pptx'])
    an2f = AbstractNode.create(@bufs_file_system)
    #puts "an1s hash: #{an1s.hash}"
    #puts "an2f hash: #{an2f.hash}"
    an1s.should == an2f
    #puts "done with node"

  end

  it "should be able to return all nodes from all attached models" do
    all_node_list = AbstractNode.all
    all_node_list.size.should > 0
    #all_node_list.each {|n| p n}
    all_my_categories = all_node_list.map {|n| n[0]} 
    all_nodes = all_node_list.map {|n| n[1]}
    bids = BufsInfoDoc.all
    bids.each do |bid|
      bid_node = AbstractNode.create(bid)
      all_nodes.should include bid_node if bids.size > 0
      all_my_categories.should include bid.my_category if bids.size > 0
    end
    bfs = BufsFileSystem.all
    bfs.each do |bf|
      bf_node = AbstractNode.create(bf)
      all_nodes.should include bf_node if bfs.size > 0
      all_my_categories.should include bf.my_category if bfs.size > 0
    end
  end

  it "should be able to synchronize a doc node to an empty file node" do
    #set up nodes
    required_fields = {:my_category => 'sync_test_doc_to_empty_file', :parent_categories => ['mom','dad']}
    optional_fields = {:description => 'a lovely shade of muave'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    node_data1 = initial_fields.dup #needed because of couchrest weirdness
    bufs_info_doc1 = BufsInfoDoc.new(initial_fields)
    bufs_info_doc1.save
    bufs_info_doc1.add_data_file(@test_files['simple_text_file'])
    bufs_info_doc1.save
    bufs_info_doc1 = BufsInfoDoc.get(bufs_info_doc1['_id'])
    #clear any file node
    _dummy = BufsFileSystem.new(initial_fields)
    _dummy.destroy if _dummy.my_category
    _dummy = nil
    #make sure nodes are not synchronized
    empty_fss = BufsFileSystem.by_my_category(bufs_info_doc1.my_category)
    empty_fs = empty_fss.first if empty_fss
    abs_doc_node = AbstractNode.create(bufs_info_doc1)
    #empty_file_node = AbstractNode.create(empty_fs) if empty_fs
    #abs_doc_node.should_not == empty_file_node if abs_doc_node && empty_file_node
    #synchronize nodes
    AbstractNode.sync([abs_doc_node, _dummy])
    new_fs = BufsFileSystem.by_my_category(bufs_info_doc1.my_category).first
    abs_file_node = AbstractNode.create(new_fs)
    abs_doc_node.should == abs_file_node
  end

  it "should be able to synchronize a file system node to an empty doc node" do
    required_fields = {:my_category => 'sync_test_file_to_empty_doc', :parent_categories => ['mom','dad']}
    optional_fields = {:description => 'a lovely shade of vermillion'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    node_data2 = initial_fields.dup #needed because of couchrest weirdness
    bufs_file_sys2 = BufsFileSystem.new(initial_fields)
    bufs_file_sys2.save
    bufs_file_sys2.add_data_file(@test_files['simple_text_file2'])
    bufs_file_sys2.save
    bufs_file_sys2s = BufsFileSystem.by_my_category(bufs_file_sys2.my_category)
    bufs_file_sys2s.size.should == 1
    bufs_file_sys2 = bufs_file_sys2s.first
  
    puts "BufFS: #{bufs_file_sys2.inspect}"
    puts "My Cat: #{bufs_file_sys2.my_category}"
    #check for any db entries, fail if there are
    lambda {BufsInfoDoc.by_my_category(bufs_file_sys2.my_category) }.should raise_error(TypeError)
    _dummy = nil
    abs_file_node = AbstractNode.create(bufs_file_sys2)
    AbstractNode.sync([abs_file_node, _dummy])
    new_bid = BufsInfoDoc.by_my_category(:key => bufs_file_sys2.my_category).first
    abs_doc_node = AbstractNode.create(new_bid)
    abs_file_node.should == abs_file_node
  end

  it "should be able to synchronize a fresh doc node to a stale file system node" do

    #need to automate destruction of old data so as not to interfere with the test

    required_fields = {:my_category => 'sync_fresh_doc_to_stale_file', :parent_categories => ['mom','dad']}
    optional_fields = {:description => 'a lovely shade of fresh ochre'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    node_data1 = initial_fields.dup #needed because of couchrest weirdness
    bufs_info_doc3 = BufsInfoDoc.new(initial_fields)
    bufs_info_doc3.save
    bufs_info_doc3.add_data_file(@test_files['stale_file'])
    bufs_info_doc3.save
    bufs_info_doc3 = BufsInfoDoc.get(bufs_info_doc3['_id'])
    required_fields = {:my_category => 'sync_fresh_doc_to_stale_file', :parent_categories => ['mom','dad']}
    optional_fields = {:description => 'a lovely shade of stale ochre'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    node_data2 = initial_fields.dup #needed because of couchrest weirdness
    bufs_file_sys3 = BufsFileSystem.new(initial_fields)
    bufs_file_sys3.save
    bufs_file_sys3.add_data_file(@test_files['stale_file'])
    bufs_file_sys3.save
    bufs_file_sys3s = BufsFileSystem.by_my_category(bufs_file_sys3.my_category)
    bufs_file_sys3s.size.should == 1
    bufs_file_sys3 = bufs_file_sys3s.first

    now_check = Time.now
    db_doc = BufsInfoAttachment.get(bufs_info_doc3.my_attachment_doc_id)
    db_md_name = File.basename(@test_files['stale_file'])
    db_old_time = Time.parse( db_doc['md_attachments'][db_md_name]['file_modified'] )
    puts "old time: #{db_old_time}"
    puts "now time: #{now_check}"
    puts "5 seconds before now: #{now_check - 5}"
    db_old_time.should <= now_check
    db_old_time.should > now_check - 5 

    file_loc = AbsNodeSpec::FileModelDir + '/' + bufs_file_sys3.my_category + '/' + db_md_name
    file_old_time = File.mtime(file_loc)
    file_old_time <= now_check
    file_old_time > now_check 

    #update fresh file - DB
    #making_fresh = BufsInfoAttachment.get(bufs_info_doc3.my_attachment_doc_id)
    #md_name = File.basename(@test_files['stale_file'])
    #sleep 2 #to give time for files to stale
    #making_fresh['md_attachments'][md_name]['file_modified'] =  Time.now.to_s
    #making_fresh.save

    puts "Old BFS.file_metadata: #{bufs_file_sys3.file_metadata.inspect}"

    #update fresh file - File
    making_fresh = file_loc
    delay = 4
    sleep delay
    now = Time.now
    puts "Current file time: #{File.mtime(making_fresh)}"
    puts "Updating file time to: #{now}"
    File.utime(now, now, making_fresh)
    puts "Updated file time: #{File.mtime(making_fresh)}"
    puts "File location updating: #{making_fresh.inspect}"

    #reload the updated file
    bufs_file_sys3s = BufsFileSystem.by_my_category(bufs_file_sys3.my_category)
    bufs_file_sys3s.size.should == 1
    bufs_file_sys3 = bufs_file_sys3s.first
   puts "New BFS.file_metadata: #{bufs_file_sys3.file_metadata.inspect}"


    #Here is where we finally run the CUT
    abs_doc_node = AbstractNode.create(bufs_info_doc3)
    abs_file_node = AbstractNode.create(bufs_file_sys3)

    db_doc = BufsInfoAttachment.get(bufs_info_doc3.my_attachment_doc_id)
    db_md_name = File.basename(@test_files['stale_file'])
    db_old_time = Time.parse( db_doc['md_attachments'][db_md_name]['file_modified'] )

    puts "Old DB modified time:#{db_old_time}"
    db_doc = nil
    puts "-- Metadata"
    p abs_file_node.file_metadata
    p abs_doc_node.file_metadata
    AbstractNode.sync([abs_file_node, abs_doc_node])
   
    db_doc = BufsInfoAttachment.get(bufs_info_doc3.my_attachment_doc_id)
    db_md_name = File.basename(@test_files['stale_file'])
    db_new_time = Time.parse( db_doc['md_attachments'][db_md_name]['file_modified'] )

    puts "New DB modified time: #{db_new_time}"

    db_new_time.should > db_old_time + delay - 6 #waffle time
    
    file_new_time = File.mtime(file_loc)
    file_new_time.should_not == file_old_time
    
    file_new_time.should > file_old_time + delay - 6

    # new_bid = BufsInfoDoc.by_my_category(:key => bufs_file_sys2.my_category).first
    #abs_doc_node = AbstractNode.create(new_bid)
  end

  it "should handle multiple file content"

end
