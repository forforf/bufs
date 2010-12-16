#require helper for cleaner require statements
require File.join(File.expand_path(File.dirname(__FILE__)), '/../lib/helpers/require_helper')

require Bufs.midas 'node_element_operations'

module NodeElementOperationsSpecHelpers
  def execute_operations(neo_obj, operand_values={}, initial_field_values={}, op_names=:all)
    field_ops = neo_obj.field_op_defs
    final_field_values = {}
    record_fields = field_ops.keys
    
    record_fields.each do |field|
      operations = field_ops[field].keys
      operations.each do |op_label|
        if (op_names == :all || op_names.include?(op_label))
          init_val = initial_field_values[field]
          op_val = operand_values[field]
        
          result = execute_single_operation(neo_obj, field, op_label, init_val, op_val)

          final_field_values[field] = final_field_values[field]||{}
          final_field_values[field][op_label] = result
        else
          next
        end
      end
    end
    final_field_values
  end
  
  def execute_single_operation(neo_obj, field, op_label, init_val, op_val)
    field_ops =  neo_obj.field_op_defs
    ops = field_ops[field]
    op_proc = ops[op_label] if ops
    result = op_proc.call(init_val, op_val) if op_proc
  end
  
  def check_field_results(results, field, operation)
    #puts "Results for Field: #{field} / #{operation}"
    results[field][operation][:update_this]
  end
end

describe NodeElementOperations, "Defaults" do
  include NodeElementOperationsSpecHelpers
  
  before(:each) do
    @default_fields = [:id, :data, :name, :tags]#, :kvlist]
    @default_operations = [:add, :subtract]
    #@key_fields = {:required_keys => [:id], :primary_key => :id}}
  end
  
  it "should initialize to default when no parameters are used" do
    neo_set = NodeElementOperations.new
    neo_set.field_op_defs.keys.should == @default_fields
  end
  
  it "should have a default set of fields and operations" do
    #initial conditions
    neo_set = NodeElementOperations.new
    #the default field to operation assignmen:  {:id => :static_ops, :data => :replace_ops}
    
    #change the existing values of the fields to these with the default operations
    operand_values = {:id => "should not be able to change default",
                              :data => ['new data', 'more new data']}
                              
    #test
    results = execute_operations(neo_set, operand_values)
    #verify results
    init_vals = {} #default_init_field_values
    neo_set.field_op_set_sym.each do |field, op_label|
      #puts "Checking Field #{field}, Op Label: #{op_label}"
      case op_label
        when :static_ops
          #check results set
          @default_operations.each do |op|
            results[field].keys.should include op
            results[field][op].keys.should include :update_this
          end
          #check results value
          check_field_results(results, field, :add).should == init_vals[field]
          check_field_results(results, field, :subtract).should == init_vals[field]
          
        when :replace_ops
          #check results set
          @default_operations.each do |op|
            results[field].keys.should include op
            results[field][op].keys.should include :update_this
          end
          #check results value          
          check_field_results(results, field, :add).should == operand_values[field]
          check_field_results(results, field, :subtract).should == nil  #nil - anything = nil
        
        when :list_ops
          #check results set
          @default_operations.each do |op|
            results[field].keys.should include op
            results[field][op].keys.should include :update_this
          end
          #more complete tests are later
          check_field_results(results, field, :add).should == []
          check_field_results(results, field, :add).should == []

        when :key_list_ops
          #check results set
          @default_operations.each do |op|
            results[field].keys.should include op
            results[field][op].keys.should include :update_this
          end
          #more complete tests are later
          check_field_results(results, field, :add).should == {}
          check_field_results(results, field, :add).should == {}

        else
          raise "Invalid Operation Label #{op_label} for field: #{field}"
      end
    end
  end
  
  it "should work as expected with populated initial values" do
  end
end

describe NodeElementOperations, "Validate Default Operation Behaviors" do
  include NodeElementOperationsSpecHelpers
  
  before(:each) do
    @default_behaviors = [:static_ops, :replace_ops, :list_ops, :key_list_ops]
    @field_op_set = {:test_id => :static_ops,
                          :test_label1 => :replace_ops,
                          :test_label2 => :replace_ops,
                          :test_list => :list_ops,
                          :test_kvlist => :key_list_ops }
                          
    @neo_set = NodeElementOperations.new(:field_op_set => @field_op_set)
  end

  it "should have field operations for all default operation behaviors" do
    all_behaviors = @default_behaviors.dup
    @field_op_set.each { |op_behav, op_set_sym| all_behaviors.delete(op_set_sym) }
    all_behaviors.size.should == 0  #empty
  end
  
  it "should return appropriate - add - operation results for default operation behaviors" do
    
    op_name = :add
    
    #initial conditions
    initial_operand_values = {:test_id => "Original ID",
                                       :test_label1 => "Original Label",
                                       :test_label2 => "Not Used",
                                       :test_list => ['item1', 'item2'],
                                       :test_kvlist => { :list1 => ['klist1-a', 'klist1-b'],
                                                               :list2 => ['klist2-a', 'klist2-b']} }
                                                               
    new_operand_values = {:test_id => "New ID",
                                     :test_label1 => "New Label",
                                     :test_label2 => "Not Used",
                                     :test_list => ['item3', 'item4'],
                                     :test_kvlist => { :list1 => ['klist1-c', 'klist1-d'],
                                                             :list2 => 'klist2-c',
                                                             :list3 => 'klist3-a',
                                                             :list4 => ['klist4-a', 'klist4-b']} }
    
    #test
    results = execute_operations(@neo_set, new_operand_values, initial_operand_values, [op_name])
    
    #verify
    verified_list = {}
    initial_operand_values.keys.should == new_operand_values.keys
    
    static_field_name = :test_id
    verified_list[static_field_name] = @field_op_set[static_field_name]
    results[static_field_name][op_name][:update_this].should == initial_operand_values[static_field_name]
    
    replace_field_name = :test_label1
    verified_list[replace_field_name] = @field_op_set[replace_field_name]
    results[replace_field_name][op_name][:update_this].should == new_operand_values[replace_field_name]
    
    list_field_name = :test_list
    verified_list[list_field_name] = @field_op_set[list_field_name]
    combined_values = initial_operand_values[list_field_name] + new_operand_values[list_field_name]
    results[list_field_name][op_name][:update_this].should == combined_values
    
    kvlist_field_name = :test_kvlist
    verified_list[kvlist_field_name] = @field_op_set[kvlist_field_name]
    init_v = initial_operand_values[kvlist_field_name]
    new_v = new_operand_values[kvlist_field_name]
    combined_v = {}
    combined_labels = (init_v.keys + new_v.keys).flatten
    combined_labels.uniq!
    combined_labels.each do |label|
      init_list = [init_v[label]].flatten
      new_list = [new_v[label]].flatten
      #puts "Init List: #{init_list.inspect}"
      #puts "New List: #{new_list.inspect}"
      #combined_list
      combined_v[label] = (init_list + new_list).flatten
      combined_v[label].compact!
      combined_v[label].uniq!
    end
    #what to do with verified list?
  end
  
  it "should return appropriate - subtract - operations results for default operation behaviors" do
    
    op_name = :subtract
    
    #initial conditions
    initial_operand_values = {:test_id => "Original ID",
                                       :test_label1 => "Original Label",
                                       :test_label2 => "Remove Me",
                                       :test_list => ['item1', 'item2'],
                                       :test_kvlist => { :list1 => ['klist1-a', 'klist1-d'],
                                                               :list2 => ['klist2-a', 'klist2-b'],
                                                               :list3 => 'klist3-a' } }
                                                               
    new_operand_values = {:test_id => "New ID",
                                     :test_label1 => "New Label",
                                     :test_label2 => "Remove Me",
                                     :test_list => ['item2', 'item4'],
                                     :test_kvlist => { :list1 => ['klist1-a', 'klist1-b'],
                                                             :list2 => 'klist2-b',
                                                             :list3 => 'klist3-a',
                                                             :list4 => ['klist4-a', 'klist4-b']} }
    
    #test
    results = execute_operations(@neo_set, new_operand_values, initial_operand_values, [op_name])
    
    #verify
    verified_list = {}
    initial_operand_values.keys.should == new_operand_values.keys
    
    static_field_name = :test_id
    verified_list[static_field_name] = @field_op_set[static_field_name]
    results[static_field_name][op_name][:update_this].should == initial_operand_values[static_field_name]
    
    replace_field_name = :test_label1
    verified_list[replace_field_name] = @field_op_set[replace_field_name]
    results[replace_field_name][op_name][:update_this].should == initial_operand_values[replace_field_name]
    
    replace_field_name = :test_label2
    verified_list[replace_field_name] = @field_op_set[replace_field_name]
    results[replace_field_name][op_name][:update_this].should == nil
    
    list_field_name = :test_list
    verified_list[list_field_name] = @field_op_set[list_field_name]
    subtracted_values = initial_operand_values[list_field_name] - new_operand_values[list_field_name]
    results[list_field_name][op_name][:update_this].should == subtracted_values
  end
end 

describe NodeElementOperations, "NodeElementOperation defined but not default key-value lists" do
  include NodeElementOperationsSpecHelpers
  
  before(:each) do
    @field_op = :kvlist
    @op_def = :key_list_ops
    @built_in_op_names = [:add, :subtract, :getkeys] 
    @neo_set = NodeElementOperations.new(:field_op_set => {@field_op => @op_def})
  end
  
  it "should merge in custom field operatoins with default field operations" do
    @neo_set.field_op_set_sym.keys.should include :id
    @neo_set.field_op_set_sym.keys.should include :tags
    @neo_set.field_op_set_sym.keys.should include  @field_op
  end
  
  it "should provide built-in operations to act on lists of lists" do
    @built_in_op_names.each do |op_name|
      @neo_set.lookup_op_proc(@op_def)[op_name].class.should == Proc
    end
  end
  
  it "should return appropriate - add - operation results for list of lists" do
    op_name = :add
    
    #initial conditions
    initial_operand_values = {:id => 'InitList',
                                       :kvlist => { :list1 => ['klist1-a', 'klist1-d'],
                                                               :list2 => ['klist2-a', 'klist2-b'],
                                                               :list3 => 'klist3-a' } }
                                                               
    new_operand_values  = {:kvlist => { :list1 => ['klist1-c', 'klist1-d'],
                                                               :list2 => 'klist2-c',
                                                               :list3 => 'klist3-a',
                                                               :list4 => ['klist4-a', 'klist4-b']} }

    kvlist_field_name = :kvlist
    #verified_list[kvlist_field_name] = @field_op_set[kvlist_field_name]
    init_v = initial_operand_values[kvlist_field_name]
    new_v = new_operand_values[kvlist_field_name]
    combined_v = {}
    combined_labels = (init_v.keys + new_v.keys).flatten
    combined_labels.uniq!
    combined_labels.each do |label|
      init_list = [init_v[label]].flatten
      new_list = [new_v[label]].flatten
      #puts "Init List: #{init_list.inspect}"
      #puts "New List: #{new_list.inspect}"
      #combined_list
      combined_v[label] = (init_list + new_list).flatten
      combined_v[label].compact!
      combined_v[label].uniq!
    end
    #combined_v is what we should get back from the operation
    
    result_to_update = execute_single_operation(@neo_set, kvlist_field_name, op_name, init_v, new_v)
    result = result_to_update[:update_this]
    result.should == combined_v
  end

  it "should return appropriate - subtract - operation results for list of lists" do
    op_name = :subtract
    
    #initial conditions
    initial_operand_values = {:id => 'InitList',
                                       :kvlist => { :list1 => ['klist1-a', 'klist1-d'],
                                                               :list2 => ['klist2-a', 'klist2-b'],
                                                               :list3 => 'klist3-a' } }
                                                               
    new_operand_values  = {:kvlist => { :list1 => ['klist1-c', 'klist1-d'],
                                                               :list2 => 'klist2-b',
                                                               :list3 => 'klist3-a',
                                                               :list4 => ['klist4-a', 'klist4-b']} }

    kvlist_field_name = :kvlist
    #verified_list[kvlist_field_name] = @field_op_set[kvlist_field_name]
    init_v = initial_operand_values[kvlist_field_name]
    new_v = new_operand_values[kvlist_field_name]
    combined_v = {}
    combined_labels = (init_v.keys).flatten
    combined_labels.uniq!
    combined_labels.each do |label|
      init_list = [init_v[label]].flatten
      new_list = [new_v[label]].flatten
      #puts "Init List: #{init_list.inspect}"
      #puts "New List: #{new_list.inspect}"
      #combined_list
      combined_v[label] = (init_list - new_list).flatten
      combined_v[label].compact!
      combined_v[label].uniq!
    end
    #combined_v is what we should get back from the operation
    
    result_to_update = execute_single_operation(@neo_set, kvlist_field_name, op_name, init_v, new_v)
    result = result_to_update[:update_this]
    result.should == combined_v
  end

  it "should return appropriate - getkeys - operations results for default operation behaviors" do
    
    op_name = :getkeys
    
    #initial conditions
    initial_operand_values = {:id => "Original ID",
                                       :kvlist => { :list1 => ['klist1-a', 'klist1-d'],
                                                               :list2 => ['klist2-a', 'klist2-b'],
                                                               :list3 => 'klist3-a' } }
                                                               
    lookup_values1 = {:kvlist => 'klist2-b'}
    lookup_values2 = {:kvlist => ['klist2-a', 'klist3-a']}
    
    kvlist_field_name = :kvlist
    #verified_list[kvlist_field_name] = @field_op_set[kvlist_field_name]
    init_v = initial_operand_values[kvlist_field_name]
    lookup_v1 = lookup_values1[kvlist_field_name]
    lookup_v2 = lookup_values2[kvlist_field_name]
    expected_return_value1 = []
    expected_return_value2 = []
    init_v.each do |label, list_items|
      expected_return_value1 << label if list_items.include? lookup_v1
    end
    init_v.each do |label, list_items|
      lookup_v2.each do |lookup|
        expected_return_value2 << label if list_items.include? lookup
      end
    end

    results1 = execute_single_operation(@neo_set, kvlist_field_name, op_name, init_v, lookup_v1)
    results2 = execute_single_operation(@neo_set, kvlist_field_name, op_name, init_v, lookup_v2)
    expected_return_value1.should == results1[:return_value]
    expected_return_value2.should == results2[:return_value]
    initial_operand_values[kvlist_field_name].should == results1[:update_this]
    initial_operand_values[kvlist_field_name].should == results2[:update_this]
   
  end
  
 
end

#complete non-default with proc from scratch