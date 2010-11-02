#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../lib/helpers/require_helper')

require Bufs.spec_helpers 'bufs_sample_dataset'

describe PopulatePersistenceModels do

  it "should add data to the models" do
    user_classes = PopulatePersistenceModels.add_data_set_to_model(PopulatePersistenceModels::Sample1::DataSet)
    puts "User Classes to Be used: #{user_classes.map{|uc| uc.name} }"
    data_set = PopulatePersistenceModels::Sample1::DataSet
    my_cats = data_set.map{ |id, data| data[:my_category] }
    my_cats.each do |my_cat|
      user_classes.each do |user_class|
        #puts "Calling View for User Class #{user_class.name} with cat: #{my_cat.inspect}"
        persisted_node = user_class.call_view(:my_category, my_cat).first
        my_cat.should == persisted_node.my_category
      end
    end
      
  end
end
