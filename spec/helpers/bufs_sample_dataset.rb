SampleDataSpec = File.dirname(__FILE__)
require File.join(SampleDataSpec, 'bufs_test_environments')

node_db_name = "http://127.0.0.1:5984/sample_data/"
SampleCouchDB = CouchRest.database!(node_db_name)
SampleCouchDB.compact!

FileSystem = "/home/bufs/bufs/sandbox_for_specs/sample_data"


module MakeUserClasses
    @user1_id = "SampleCouchUser001"
    @user2_id = "SampleCouchUser002"
    @user3_id = "SampleFileSysUser003"
    @user4_id = "SampleFileSysUser004"
    node_class_id1 = "BufsInfoNode#{@user1_id}"
    node_class_id2 = "BufsInfoNode#{@user2_id}"
    node_class_id3 = "BufsFile#{@user3_id}"
    node_class_id4 = "BufsFile#{@user4_id}"
    couchpath = SampleCouchDB.uri
    couchhost = SampleCouchDB.host
    node_env1 = NodeHelper.env_builder("couchrest", node_class_id1, @user1_id, couchpath, couchhost)
    node_env2 = NodeHelper.env_builder("couchrest", node_class_id2, @user2_id, couchpath, couchhost)
    node_env3 = NodeHelper.env_builder("filesystem", node_class_id3, @user3_id, FileSystem)
    node_env4 = NodeHelper.env_builder("filesystem", node_class_id4, @user4_id, FileSystem)
    User1Class =  BufsNodeFactory.make(node_env1)
    User2Class =  BufsNodeFactory.make(node_env2)
    User3Class =  BufsNodeFactory.make(node_env3)
    User4Class =  BufsNodeFactory.make(node_env4)
end


#file list
#---------------------------------
#- Test Filenames and References -
#---------------------------------
#binary_data_pptx                  ->  test_files/spec_test1.pptx
#binary_data_spaces_in_fname_pptx  ->  test_files/spec test2 v1.3.pptx
#binary_data2_docx                 ->  test_files/spec test2.docx
#binary_data3_pptx                 ->  test_files/spec_test3.pptx
#fresh_file                        ->  test_files/test_modified_time_fresh.txt
#simple_text_file                  ->  test_files/simple_text_file1.txt
#simple_text_file2                 ->  test_files/simple text file 2.txt
#simple_text_file3                 ->  test_files/simple text file 3.txt
#simple_text_file4                 ->  test_files/simple text file 4.txt
#stale_file                        ->  test_files/test_modified_time_stale.txt
#strange_characters_in_file_name   ->  test_files/Test%_+- .,^^,. -+_%.txt

module SampleDataSets
  module Sample1
    data_set = {}
    keys = [:a, :aa, :ab, :ac, :aaa, :b, :ba, :bb, :bc, :bbb, :bcc, :c, :cc]
    keys.each {|key| data_set[key] ={} }  #set all to hash
    
    data_set[:a][:my_category] = 'a'
    data_set[:a][:parent_categories] = ['aa']
    
    data_set[:aa][:my_category] = 'aa'
    data_set[:aa][:parent_categories] = ['a']
    data_set[:aa][:files] = ['simple_text_file', 'binary_data_pptx']
    
    data_set[:ab][:my_category] = 'ab'
    data_set[:ab][:parent_categories] = ['a', 'aaa', 'bb', 'just_a_label2']
    
    data_set[:ac][:my_category] = 'ac'
    data_set[:ac][:parent_categories] = ['a']
    data_set[:ac][:files] = ['binary_data_spaces_in_fname_pptx']
    data_set[:ac][:links] = [['google', 'http://www.google.com']]
    
    data_set[:aaa][:my_category] = 'aaa'
    data_set[:aaa][:parent_categories] = ['aa', 'just_a_label']
    
    data_set[:b][:my_category] = 'b'
    data_set[:b][:parent_categories] = ['just_a_label']
    data_set[:b][:files] = ['simple_text_file2', 'simple_text_file3']
    data_set[:b][:links] = [['yahoo', 'http://www.yahoo.com'], ['google', 'http://www.google.com']]
    
    data_set[:ba][:my_category] = 'ba'
    data_set[:ba][:parent_categories] = ['b', 'ab']
    data_set[:ba][:files] = ['simple_text_file']
    data_set[:ba][:links] = [['yahoo2', 'http://www.yahoo.com'], ['google', 'http://www.google.com']]
    
    data_set[:bb][:my_category] = 'bb'
    data_set[:bb][:parent_categories] = ['b']
    data_set[:bb][:files] = ['strange_characters_in_file_name']
    
    data_set[:bc][:my_category] = 'bc'
    data_set[:bc][:parent_categories] = ['b', 'bbb', 'just_a_label2']
    
    data_set[:bbb][:my_category] = 'bbb'
    data_set[:bbb][:parent_categories] = ['bb', 'aaa']
    
    data_set[:bcc][:my_category] = 'bcc'
    data_set[:bcc][:parent_categories] = ['bc']
    data_set[:bcc][:links] = [[['MeFi'], 'http:\\www.metafilter.com']]
    
    data_set[:c][:my_category] = 'c'
    data_set[:c][:parent_categories] = []
    data_set[:cc][:my_category] = 'cc'
    data_set[:cc][:parent_categories] = ['c']
    data_set[:cc][:files] = ['simple_text_file']
    data_set[:cc][:links] = [['google2', 'http:\\www.google.com']]

    DataSet = data_set
  end
end

module PopulatePersistenceModels
include MakeUserClasses
include SampleDataSets
include NodeHelpers

  @user_classes = [User1Class, User2Class, User3Class, User4Class]
  @test_files = BufsFixtures.test_files
  
  #stupid hack so I don't have to go change existing stuff
  class Dummy
    include NodeHelpers
  end

  def self.convert_links_to_hash(links)
    link_hash = {}
    return unless links
    links.each do |link_pair|
      link_hash[link_pair[1]] = link_pair[0]
    end
    link_hash
  end
  
  def self.add_data_set_to_model(data_set = Sample1::DataSet)
    data_set.each do |node, node_data|
      params = { :my_category => node_data[:my_category],
                       :parent_categories => node_data[:parent_categories],
                       :links => self.convert_links_to_hash(node_data[:links]),
                       :description => "test"}
      raise "Params Issue with :my_category #{params.inspect}" unless node_data[:my_category]
      raise "Params Issue with :parent_categories #{params.inspect}" unless node_data[:parent_categories]
      @user_classes.each do |user_class|
        node = Dummy.new.make_doc_no_attachment(user_class, params)
        node.description = "from: #{node.my_GlueEnv.user_id}"
        
        #add files to node
        if node_data[:files]
          file_references = node_data[:files]
          file_data = file_references.map{|ref| {:src_filename => @test_files[ref]}}
          node.files_add(file_data)
        end
        
        #Another Hack to be able to find the user as root in a tree
        user_id = user_class.myGlueEnv.user_id
        if node.my_category == 'a'|| node.my_category == 'b'|| node.my_category == 'c'
          node.parent_categories_add(user_id)
        end
        node.__save
      end
    end
    @user_classes
  end

end
