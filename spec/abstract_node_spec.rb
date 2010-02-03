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

module AbstractNodeSyncHelpers
    def create_db_doc(init_data, data_file=nil)
      init_data_dup = init_data.dup #for couchrest weirdness
      bid = BufsInfoDoc.new(init_data_dup)
      bid.save
      if data_file
        bid.add_data_file(data_file)
        bid.save
      end
      return_bid = BufsInfoDoc.get(bid['_id'])
    end

    def create_file_model(init_data, data_file=nil)
      bfs = BufsFileSystem.new(init_data)
      bfs.save
      if data_file
        bfs.add_data_file(data_file)
        bfs.save
      end
      return_bfss = BufsFileSystem.by_my_category(bfs.my_category)
      raise "Multiple File Model Directories with same category name #{bfs.my_category}" if return_bfss.size > 1
      raise "No File Model found for #{bfs.my_category}" if return_bfss.size == 0
      return_bfs = return_bfss.first
    end

    def set_db_attachment_time(db_doc ,att_name, time)
      att = BufsInfoAttachment.get(db_doc.my_attachment_doc_id)
      att['md_attachments'][att_name]['file_modified'] = time
      att.save
      return_att = BufsInfoAttachment.get(db_doc.my_attachment_doc_id)
    end

    def get_db_attachment_time(db_doc, att_name)
      att = BufsInfoAttachment.get(db_doc.my_attachment_doc_id)
      att_time = Time.parse(att['md_attachments'][att_name]['file_modified'])
    end

    def set_file_model_file_time(file_model, full_file_name, time)
      puts "Current file time: #{File.mtime(full_file_name)}"
      puts "Updating file time to: #{time}"
      File.utime(time, time, full_file_name)
      puts "Updated file time: #{File.mtime(full_file_name)}"
      puts "File location updating: #{full_file_name.inspect}"

      #reload the updated file
      return_bfss = BufsFileSystem.by_my_category(file_model.my_category)
      raise "Multiple File Model Directories with same category name #{bfs.my_category}" if return_bf
      raise "No File Model found for #{bfs.my_category}" if return_bfss.size == 0
      return_bfs = return_bfss.first
    end

    def refresh_file_model_node(file_node, full_file_name, new_data)
      #TODO add capability of replacing with new data
      #update fresh file - File
      #making_fresh = file_loc
      #delay = 4
      #sleep delay
      now = Time.now
      puts "Current file time: #{File.mtime(full_file_name)}"
      puts "Updating file time to: #{now}"
      File.utime(now, now, full_file_name)
      puts "Updated file time: #{File.mtime(full_file_name)}"
      puts "File location updating: #{full_file_name.inspect}"

      #reload the updated file
      refreshed_file_nodes = BufsFileSystem.by_my_category(file_node.my_category)
      refreshed_file_nodes.size.should == 1
      refreshed_file_node = refreshed_file_nodes.first
    end
  
  class TestReadOnlyNode < ReadOnlyNode
    def initialize
      @test_file = "imaginary_read_only_node_file_location"
    end
    def my_category
      'read_only_node_test'
    end
    def parent_categories
      ['read only orphan']
    end
    def file_metadata
      test_file_basename = @test_file
      esc_basename = CGI.escape(test_file_basename)
      {esc_basename => {"file_modified" => Time.now.to_s}}
    end

    def get_file_data(file_name)
      "So fresh it hasn't even made it to the file yet"
    end
  end
end

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
end

describe AbstractNode, "synchronization" do
  include AbstractNodeSyncHelpers
  before(:all) do
    BufsInfoDoc.set_name_space(CouchDB)
    BufsFileSystem.set_name_space(AbsNodeSpec::FileModelDir)
    @test_files = BufsFixtures.test_files
  end

  it "should be able to synchronize a doc node to an empty file node" do
    #set up nodes
    required_fields = {:my_category => 'sync_test_doc_to_empty_file', :parent_categories => ['mom','dad']}
    optional_fields = {:description => 'a lovely shade of muave'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    #node_data1 = initial_fields.dup #needed because of couchrest weirdness
    #bufs_info_doc1 = BufsInfoDoc.new(initial_fields)
    #bufs_info_doc1.save
    #bufs_info_doc1.add_data_file(@test_files['simple_text_file'])
    #bufs_info_doc1.save
    #bufs_info_doc1 = BufsInfoDoc.get(bufs_info_doc1['_id'])
    #clear any file node
    bufs_info_doc1 = create_db_doc(initial_fields, @test_files['simple_text_file'])
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
    AbstractNode.sync([abs_doc_node]) #, _dummy])
    
    new_fs = BufsFileSystem.by_my_category(bufs_info_doc1.my_category).first
    puts "SPEC new_fs: #{new_fs.inspect}"
    abs_file_node = AbstractNode.create(new_fs)
    puts "SPEC abs_file_node: #{abs_file_node.inspect}"
    abs_doc_node.should == abs_file_node
  end

  it "should be able to synchronize a file system node to an empty doc node" do
    required_fields = {:my_category => 'sync_test_file_to_empty_doc', :parent_categories => ['mom','dad']}
    optional_fields = {:description => 'a lovely shade of vermillion'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    #node_data2 = initial_fields.dup #needed because of couchrest weirdness
    #bufs_file_sys2 = BufsFileSystem.new(initial_fields)
    #bufs_file_sys2.save
    #bufs_file_sys2.add_data_file(@test_files['simple_text_file2'])
    #bufs_file_sys2.save
    #bufs_file_sys2s = BufsFileSystem.by_my_category(bufs_file_sys2.my_category)
    #bufs_file_sys2s.size.should == 1
    #bufs_file_sys2 = bufs_file_sys2s.first
    bufs_file_sys2 = create_file_model(initial_fields, @test_files['simple_text_file2'])
  
    puts "BufFS: #{bufs_file_sys2.inspect}"
    puts "My Cat: #{bufs_file_sys2.my_category}"
    #check for any db entries, fail if there are
    lambda {BufsInfoDoc.by_my_category(bufs_file_sys2.my_category) }.should raise_error #(TypeError)
    _dummy = nil
    abs_file_node = AbstractNode.create(bufs_file_sys2)
    AbstractNode.sync([abs_file_node]) #, _dummy])
    new_bid = BufsInfoDoc.by_my_category(:key => bufs_file_sys2.my_category).first
    abs_doc_node = AbstractNode.create(new_bid)
    abs_file_node.should == abs_file_node
  end

  it "should be able to synchronize a fresh db doc node to a stale file system node" do

    #create stale database file (BufsInfoDoc)
    required_fields = {:my_category => 'sync_fresh_db_to_stale_file', :parent_categories => ['mom','dad']}
    optional_fields = {:description => 'a lovely shade of fresh ochre'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    stale_db1 = create_db_doc(initial_fields, @test_files['stale_file'])

    #create stale filesystem file (BufsFileSystem)
    required_fields = {:my_category => 'sync_fresh_db_to_stale_file', :parent_categories => ['mom','dad']}
    optional_fields = {:description => 'a lovely shade of stale ochre'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    stale_file1 = create_file_model(initial_fields, @test_files['stale_file'])

    #run some sanity checks on the times (making sure thins were setup properly)
    now_check = Time.now
    #db_doc = BufsInfoAttachment.get(stale_db1.my_attachment_doc_id)
    db_md_name = File.basename(@test_files['stale_file'])
    #db_old_time = Time.parse( db_doc['md_attachments'][db_md_name]['file_modified'] )
    db_old_time = get_db_attachment_time(stale_db1, db_md_name)
    puts "old time: #{db_old_time}"
    puts "now time: #{now_check}"
    puts "5 seconds before now: #{now_check - 5}"
    db_old_time.should <= now_check
    db_old_time.should > now_check - 5 

    file_loc = AbsNodeSpec::FileModelDir + '/' + stale_file1.my_category + '/' + db_md_name
    file_old_time = File.mtime(file_loc)
    file_old_time <= now_check
    file_old_time > now_check 

    #update fresh file - DB
    #making_fresh = BufsInfoAttachment.get(stale_db1.my_attachment_doc_id)
    #md_name = File.basename(@test_files['stale_file'])
    #sleep 2 #to give time for files to stale
    #making_fresh['md_attachments'][md_name]['file_modified'] =  Time.now.to_s
    #making_fresh.save

    puts "Old BFS.file_metadata: #{stale_file1.file_metadata.inspect}"

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
    stale_file1s = BufsFileSystem.by_my_category(stale_file1.my_category)
    stale_file1s.size.should == 1
    stale_file1 = stale_file1s.first
   puts "New BFS.file_metadata: #{stale_file1.file_metadata.inspect}"


    #Here is where we finally run the CUT
    abs_doc_node = AbstractNode.create(stale_db1)
    abs_file_node = AbstractNode.create(stale_file1)

    db_doc = BufsInfoAttachment.get(stale_db1.my_attachment_doc_id)
    db_md_name = File.basename(@test_files['stale_file'])
    db_old_time = Time.parse( db_doc['md_attachments'][db_md_name]['file_modified'] )

    puts "Old DB modified time:#{db_old_time}"
    db_doc = nil
    puts "-- Metadata"
    p abs_file_node.file_metadata
    p abs_doc_node.file_metadata
    AbstractNode.sync([abs_file_node, abs_doc_node])
   
    db_doc = BufsInfoAttachment.get(stale_db1.my_attachment_doc_id)
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

  it "should be able to synchronize a fresh file system node to a stale db doc node" do

    #create stale database file (BufsInfoDoc)
    required_fields = {:my_category => 'sync_fresh_file_to_stale_db', :parent_categories => ['mommy','daddy']}
    optional_fields = {:description => 'a lovely shade of fresh scarlet'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    stale_db1 = create_db_doc(initial_fields, @test_files['stale_file'])

    #create stale filesystem file (BufsFileSystem)
    required_fields = {:my_category => 'sync_fresh_file_to_stale_db', :parent_categories => ['mommy','daddy']}
    optional_fields = {:description => 'a lovely shade of stale scarlet'}
    initial_fields = required_fields.merge(optional_fields) #or should this be the other way?
    stale_file1 = create_file_model(initial_fields, @test_files['stale_file'])
  
    #run some sanity checks on the times (making sure thins were setup properly)
    now_check = Time.now
    file_basename = File.basename(@test_files['stale_file'])
    db_old_time = get_db_attachment_time(stale_db1, file_basename)
    puts "old time: #{db_old_time}"
    puts "now time: #{now_check}"
    puts "15 seconds before now: #{now_check - 15}"
    db_old_time.should <= now_check
    db_old_time.should > now_check - 15
    #so now we're assured the database time will be stale if we change the file system's time from this point onward

    #just checking to make sure the file time makes sense before we change it
    file_loc = AbsNodeSpec::FileModelDir + '/' + stale_file1.my_category + '/' + file_basename
    file_old_time = File.mtime(file_loc)
    file_old_time.should <= now_check
    file_old_time.should > now_check - 15
    

    puts "Old BFS.file_metadata: #{stale_file1.file_metadata.inspect}"
 
    delay = 4
    sleep delay
    fresh_file1 = refresh_file_model_node(stale_file1, file_loc, "New Data (not implemented yet)")
    puts "New BFS.file_metadata: #{fresh_file1.file_metadata.inspect}"

    #Here is where we finally run the CUT
    abs_doc_node = AbstractNode.create(stale_db1)
    abs_file_node = AbstractNode.create(fresh_file1)

    db_doc = BufsInfoAttachment.get(stale_db1.my_attachment_doc_id)
    file_basename = File.basename(@test_files['stale_file'])
    db_old_time = Time.parse( db_doc['md_attachments'][file_basename]['file_modified'] )

    puts "Old DB modified time:#{db_old_time}"
    db_doc = nil
    puts "-- Metadata"
    p abs_file_node.file_metadata
    p abs_doc_node.file_metadata
    AbstractNode.sync([abs_file_node, abs_doc_node])

    db_doc = BufsInfoAttachment.get(stale_db1.my_attachment_doc_id)
    file_basename = File.basename(@test_files['stale_file'])
    db_new_time = Time.parse( db_doc['md_attachments'][file_basename]['file_modified'] )

    puts "New DB modified time: #{db_new_time}"

    db_new_time.should > db_old_time + delay - 6 #waffle time

    file_new_time = File.mtime(file_loc)
    file_new_time.should_not == file_old_time

    file_new_time.should > file_old_time + delay - 6

    # new_bid = BufsInfoDoc.by_my_category(:key => bufs_file_sys2.my_category).first
    #abs_doc_node = AbstractNode.create(new_bid)

  end

  it "should be able to update empty nodes from read only nodes" do
    read_only_node = TestReadOnlyNode.new
    AbstractNode.sync([read_only_node])
    
    #check bufs doc
    bufs_doc = BufsInfoDoc.by_my_category(:key => read_only_node.my_category).first
    read_only_node.my_category.should == bufs_doc.my_category

    #check file system
    bufs_fs = BufsFileSystem.by_my_category(read_only_node.my_category).first
    read_only_node.my_category.should == bufs_fs.my_category
  end

  it "needs to test read only node types"
  it "should handle multiple file content"

end
