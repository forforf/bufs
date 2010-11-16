require File.join(File.dirname(__FILE__) , 'helpers/bufs_sample_dataset')
require File.join(File.dirname(__FILE__), '../lib/grapher')

describe Borg do
  before(:all) do
    sample_data = PopulatePersistenceModels::Sample1::DataSet
    ppm = PopulatePersistenceModels
    @user_classes = ppm.add_data_set_to_model(sample_data)
    @keys = {:node_id_key => :my_category, :parent_key => :parent_categories}
  end
  
  before(:each) do
  end

  it "should initialize properly" do
    @user_classes.each do |user_class|
      node_list = user_class.all
      borg = Borg.new(node_list, @keys)
    end
    #verify results
    #nothing here yet
    #ok if it doesn't crash on initialization
    #the borg object may have attributes in the future
  end

  it "should borg.ify all descendant data" do
    require 'pp'
    #initial conditions
    borged_nodes_files = {} # {user_class => {node => node borg data, node =>}
    borged_nodes_links = {} # {node => node borg data}
    @user_classes.each do |user_class|
      node_list = user_class.all
      borg= Borg.new(node_list, @keys)
      borg_list_links = {} #{main_node => borg data}
      borg_list_files = {} #{main_node => borg data}
      id_key = @keys[:node_id_key]
      node_list.each do |main_node|
        main_node_id = main_node.__send__(id_key.to_sym)
        #testing
        borg_list_links[main_node_id] =  borg.ify(main_node, :links)
        if main_node_id == 'bc'
          #pp borg_list_links[main_node_id]
        end
        borg_list_files[main_node_id] = borg.ify(main_node, :attached_files)
        #-------
      end
      borged_nodes_links[user_class] = borg_list_links
      borged_nodes_files[user_class] = borg_list_files
    end
    #verify
    links_data = {}
    @user_classes.each do |user_class|
    #This is dependent upon the sample dataset structure (I don't think there's a way around this)
      links_data[:bc] = borged_nodes_links[user_class]['bc'].map{|d| d.values}.flatten.compact
      links_data[:bc].should == [{"http:\\www.metafilter.com"=>["MeFi"]}]
      links_data[:bbb] = borged_nodes_links[user_class]['bbb'].map{|d| d.values}.flatten.compact
      links_data[:bbb].should == links_data[:bc]
      links_data[:bb] = borged_nodes_links[user_class]['bb'].map{|d| d.values}.flatten.compact
      links_data[:bb].should == [{"http://www.yahoo.com"=>"yahoo2",
                                            "http://www.google.com"=>"google"},
                                            {"http:\\www.metafilter.com"=>["MeFi"]}]
                                           # [{"http:\\www.google.com"=>"google2"}]
      links_data[:c] = borged_nodes_links[user_class]['c'].map{|d| d.values}.flatten.compact
      links_data[:c].should == [{"http:\\www.google.com"=>"google2"}]
      pp borged_nodes_links[user_class]['c'].map{|d| d.rekey{|k| k.node_name}}.flatten.compact

    end
  end
end
