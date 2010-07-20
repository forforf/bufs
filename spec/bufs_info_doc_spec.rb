
require File.dirname(__FILE__) + '/../bufs_fixtures/bufs_fixtures'


require 'couchrest'
#doc_db_name = "http://bufs.younghawk.org:5984/bufs_test_spec/"
CouchDB = BufsFixtures::CouchDB #CouchRest.database!(doc_db_name)
CouchDB.compact!
#CouchDB2 = BufsFixtures::CouchDB2
#CouchDB2.compact!


require File.dirname(__FILE__) + '/../lib/bufs_info_doc'

#BufsInfoDoc.set_name_space(CouchDB)

module BufsInfoDocSpecHelpers
  DefaultDocParams = {:my_category => 'default',
                      :parent_categories => ['default_parent'],
                      :description => 'default description'}

  def get_default_params
    DefaultDocParams.dup #to avoid a couchrest weirdness don't use the params directly
  end
  
  def make_doc_no_attachment(override_defaults={})
    #default_params = {:my_category => 'default', 
    #                  :parent_categories => ['default_parent'],
    #		      :description => 'default description'}
    init_params = get_default_params.merge(override_defaults)
    return BufsInfoDoc.new(init_params)
  end
end

describe BufsInfoDoc, "Basic Document Operations (no attachments)" do
  BufsInfoDoc.use_database CouchDB
  include BufsInfoDocSpecHelpers

  before(:each) do
    all_docs = BufsInfoDoc.all
    all_docs.each do |doc|
      doc.destroy
    end
    #CouchDB = BufsFixtures::CouchDB
    #BufsInfoDoc.set_name_space(CouchDB)
  end


  it "should initialize correctly" do
    #check initial conditions
    BufsInfoDoc.all.size.should == 0
    #test
    default_bid = BufsInfoDoc.new(get_default_params)
    #check results
    default_bid.my_category.should == get_default_params[:my_category]
    default_bid.parent_categories.should == get_default_params[:parent_categories]
    default_bid.description.should == get_default_params[:description]
    #we haven't saved it to the database yet
    BufsInfoDoc.all.size.should == 0
  end

  it "should not save if required fields don't exist" do
    #set initial condition
    orig_db_size = BufsInfoDoc.all.size
    bad_bufs_info_doc1 = BufsInfoDoc.new(:parent_categories => ['no_my_category'],
                                          :description => 'some description',
                                          :file_metadata => {})
    bad_bufs_info_doc2 = BufsInfoDoc.new(:my_category => 'no_parent_categories',
                                          :description => 'some description',
                                          :file_metadata => {})
                                      
    #test
    lambda { bad_bufs_info_doc1.save }.should raise_error(ArgumentError)
    #removed validation check for parent categories, not clear this is an issue
    #lambda { bad_bufs_info_doc2.save }.should raise_error(ArgumentError)

    #check results    
    BufsInfoDoc.all.size.should == orig_db_size
  end


  it "should save (not testing ScoutInfoDoc really)" do
    #set initial conditions
    orig_db_size = BufsInfoDoc.all.size
    doc_params = get_default_params.merge({:my_category => 'save_test'})
    doc_to_save = make_doc_no_attachment(doc_params.dup)

    #test
    doc_to_save.save
    
    #check results
    doc_params.keys.each do |param|
      db_param = CouchDB.get(doc_to_save['_id'])[param]
      doc_to_save[param].should == db_param
      #test accessor method
      doc_to_save.__send__(param).should == db_param
    end
    BufsInfoDoc.all.size.should == orig_db_size + 1
  end

#adding categories
  it  "should add a single category (and add the property :parent_categories) for an initial category setting for a new doc" do
    #set initial conditions
    orig_parent_cats = ['old parent cat']
    doc_params = get_default_params.merge({:my_category => 'cat_test1', :parent_categories => orig_parent_cats})
    doc_with_new_parent_cat = make_doc_no_attachment(doc_params)
    new_cat = 'new parent cat'
    #test
    doc_with_new_parent_cat.add_parent_categories(new_cat)
    #check results
    #check doc in memory
    doc_with_new_parent_cat.parent_categories.should include new_cat
    #check database
    doc_params.keys.each do |param|
      db_param = CouchDB.get(doc_with_new_parent_cat['_id'])[param]
      doc_with_new_parent_cat[param].should == db_param
      #test accessor method
      doc_with_new_parent_cat.__send__(param).should == db_param
    end
  end

  it "should add categories to existing categories and existing doc" do
    #set initial conditions
    orig_parent_cats = ['orig_cat1', 'orig_cat2']
    doc_params = get_default_params.merge({:my_category => 'cat_test2', :parent_categories => orig_parent_cats})
    doc_existing_new_parent_cat = make_doc_no_attachment(doc_params)
    doc_existing_new_parent_cat.save
    #verify initial conditions
    doc_params.keys.each do |param|
      db_param = CouchDB.get(doc_existing_new_parent_cat['_id'])[param]
      doc_existing_new_parent_cat[param].should == db_param
      #test accessor method
      doc_existing_new_parent_cat.__send__(param).should == db_param
    end
    #continue with initial conditions
    new_cats = ['new_cat1', 'new cat2', 'orig_cat2']
    #test
    doc_existing_new_parent_cat.add_parent_categories(new_cats)
    #check results
    #check doc in memory
    new_cats.each do |new_cat|
      doc_existing_new_parent_cat.parent_categories.should include new_cat
    end
    #check database
    parent_cats = CouchDB.get(doc_existing_new_parent_cat['_id'])[:parent_categories]
    new_cats.each do |cat|
      parent_cats.should include cat
    end
    #check all cats are there and are unique
    parent_cats.sort.should == (orig_parent_cats + new_cats).uniq.sort
  end

  it "should be able to remove parent categories" do
    #set initial conditions
    orig_parent_cats = ['orig_cat3', 'orig_cat4', 'del_this_cat1', 'del_this_cat2']
    doc_params = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats})
    doc_remove_parent_cat = make_doc_no_attachment(doc_params)
    doc_remove_parent_cat.save
    #verify initial conditions
    doc_params.keys.each do |param|
      db_param = CouchDB.get(doc_remove_parent_cat['_id'])[param]
      doc_remove_parent_cat[param].should == db_param
      #test accessor method
      doc_remove_parent_cat.__send__(param).should == db_param
    end
    #continue with initial conditions
    remove_multi_cats = ['del_this_cat1', 'del_this_cat2']
    remove_multi_cats.each do |cat|
      doc_remove_parent_cat.parent_categories.should include cat
    end

    #test
    doc_remove_parent_cat.remove_parent_categories(remove_multi_cats)

    #verify results
    remove_multi_cats.each do |cat|
      doc_remove_parent_cat.parent_categories.should_not include cat
    end
    cats_in_db = CouchDB.get(doc_remove_parent_cat['_id'])['parent_categories']
    remove_multi_cats.each do |removed_cat|
      cats_in_db.should_not include removed_cat
    end
  end
 
  it "should only have unique categories" do
    #verify initial state
    BufsInfoDoc.all.size.should == 0
    #set initial conditions
    orig_parent_cats = ['dup cat1', 'dup cat2', 'uniq cat1']
    doc_params = get_default_params.merge({:my_category => 'cat_test3', :parent_categories => orig_parent_cats})
    doc_uniq_parent_cat = make_doc_no_attachment(doc_params)
    doc_uniq_parent_cat.save
    orig_size = doc_uniq_parent_cat.parent_categories.size
    new_cats = ['dup cat1', 'dup cat2', 'uniq_cat2']
    expected_size = orig_size + 1 #uniq_cat2
    #test
    doc_uniq_parent_cat.add_parent_categories(new_cats)
    #verify results
    expected_size.should == doc_uniq_parent_cat.parent_categories.size
    CouchDB.get(doc_uniq_parent_cat['_id'])['parent_categories'].sort.should == doc_uniq_parent_cat.parent_categories.sort
    records = BufsInfoDoc.by_my_category(:key => doc_uniq_parent_cat.my_category)
    records.size.should == 1
  end
end

