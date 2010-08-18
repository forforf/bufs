#TODO: Find a way to automate spec generation to allow new ones to be easily added
module NodeElementOperationsSpec
  LibDir = File.dirname(__FILE__) + '/../lib/'
end

require NodeElementOperationsSpec::LibDir + 'node_element_operations'

describe NodeElementOperations, "MyCategory, Add Operations" do
  include NodeElementOperations
  #MyCategory can't be modified (so why put in operations at all?)
  #TODO: remove operations (here just to help testing)
  
  it "should work with nil, nil" do
    this = nil
    other = nil
    data = MyCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == this
    other.should == nil
    this.should == nil
  end

  it "should work with nil, data" do
    this = nil
    other = "other category"
    data = MyCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == this
    other.should == "other category"
    this.should == nil
  end

  it "should work with data, nil" do 
    this = "this category"
    other = nil
    data = MyCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == this
    other.should == nil
    this.should == "this category"
  end
    
  it "should work with data, data" do
    this = "this category"
    other = "other category"
    data = MyCategoryAddOp.call(this, other)
    result = data[:update_this]
    result.should == this
    other.should == "other category"
    this.should == "this category" 
  end
end

describe NodeElementOperations, "MyCategory, Add Operations" do
  include NodeElementOperations
  #MyCategory can't be modified (so why put in operations at all?)
  #TODO: remove operations (here just to help testing)

  it "should work with nil, nil" do
    this = nil
    other = nil
    data = MyCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == this
    other.should == nil
    this.should == nil
  end

  it "should work with nil, data" do
    this = nil
    other = "other category"
    data = MyCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == this
    other.should == "other category"
    this.should == nil
  end

  it "should work with data, nil" do
    this = "this category"
    other = nil
    data = MyCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == this
    other.should == nil
    this.should == "this category"
  end

  it "should work with data,data" do
    this = "this category"
    other = "other category"
    data = MyCategoryAddOp.call(this, other)
    result = data[:update_this]
    result.should == this
    other.should == "other category"
    this.should == "this category"
  end    
end

describe NodeElementOperations, "ParentCategories, Add Operation" do
  include NodeElementOperations

  it "should work with nil, nil" do
    #check nil operations
    this = nil
    other = nil
    data = ParentCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == []
    other.should == nil
    this.should == nil
  end

  it "should work with nil, data" do
    this = nil
    other = "other category"
    data = ParentCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == [other]
    other.should == "other category"
    this.should == nil
  end

  it "should work with data, nil" do    
    this = ["this category"]
    other = nil
    data = ParentCategoryAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == this
    other.should == nil
    this.should == ["this category"]
  end

  it "shold work with data, data" do
    this = ["this category"]
    other = "other category"
    data = ParentCategoryAddOp.call(this, other)
    result = data[:update_this]
    result.should == this + [other]
    other.should == "other category"
    this.should == ["this category"]
  end
end

describe NodeElementOperations, "ParentCategories, Subtract Operation" do
  include NodeElementOperations

  it "should work with nil, nil" do
    this = nil
    other = nil
    data = ParentCategorySubtractOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == []
    other.should == nil
    this.should == nil
  end

  it "should work with nil, data" do
    this = nil
    other = "other category"
    data = ParentCategorySubtractOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == []
    other.should == "other category"
    this.should == nil
  end

  it "should work with data, nil" do
    this = ["this category"]
    other = nil
    data = ParentCategorySubtractOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == this
    other.should == nil
    this.should == ["this category"]
  end

  it "should work with data, data" do
    this = ["this category", "other category"]
    other = "other category"
    data = ParentCategorySubtractOp.call(this, other)
    result = data[:update_this]
    result.should == ["this category"]
    other.should == "other category"
    this.should == ["this category", "other category"]
  end

  it "should work with datas, datas" do
    this = ["this one", "this two", "other one", "other two"]
    other = ["other one", "other two"]
    data = ParentCategorySubtractOp.call(this, other)
    result = data[:update_this]
    result.should == ["this one", "this two"]
    other.should == ["other one", "other two"]
    this.should == ["this one", "this two", "other one", "other two"] 
  end

end

describe NodeElementOperations, "Link, Add Operation" do
  include NodeElementOperations

  it "should work with nil, nil" do
    this = nil
    other = nil
    data = LinkAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {} 
    other.should == nil
    this.should == nil
  end

  it "should work with nil-nil, nil-data" do
    this = nil
    other = {nil => ["link"]}
    data = LinkAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {nil => ["link"]}
    other.should ==  {nil => ["link"]}
    this.should == nil
  end

  it "should work with nil-nil, data-nil" do
    this = nil
    other = {"src" => nil}
    data = LinkAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {"src" => []}
    other.should == {"src" => nil}
    this.should == nil
  end

  it "should work with nil-nil, data-data" do
    this = nil
    other = {"src" => ["link"]}
    data = LinkAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {"src" => ["link"]}
    other.should == {"src" => ["link"]}
    this.should == nil
  end

  
  it "should work with nil-data, nil-nil" do
    this = {nil => ["link"]}
    other = nil
    data = LinkAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {nil => ["link"]}
    other.should == nil
    this.should == {nil => ["link"]}
  end

  #skipped some
  it "should work with data-data, data-data" do
    this = {"src" => ["link"]}
    other = {"src2" => ["link2"]}
    data = LinkAddOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {"src" => ["link"], "src2" => ["link2"]}
    other.should == {"src2" => ["link2"]}
    #IMPORTANT:  Notice this is now updated within the Proc
    this.should == {"src" => ["link"], "src2" => ["link2"] }
  end

end

describe NodeElementOperations, "Link, Subtract Operation" do
  include NodeElementOperations

  it "should work with nil, nil" do
    this = nil
    other = nil
    data = LinkSubtractOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {}
    other.should == nil
    this.should == nil
  end

  #skipped a lot
  it "should work with unmatched data-data, data-data" do
    this = {"src" => ["link"]}
    other = {"src2" => ["link2"]}
    data = LinkSubtractOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {"src" => ["link"]}
    other.should == {"src2" => ["link2"]}
    #IMPORTANT:  Notice this is now updated within the Proc
    this.should == {"src" => ["link"] }
  end
  
  it "should work with mixed matched data-data, data-data" do
    this = {"src" => ["link", "link2"]}
    other = {"src2" => ["link2"]}
    data = LinkSubtractOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {"src" => ["link", "link2"]}
    other.should == {"src2" => ["link2"]}
    #IMPORTANT:  Notice this is now updated within the Proc
    this.should == {"src" => ["link", "link2"] }
  end

  it "should work with matched data-data, data-data" do
    this = {"src" => ["link", "link2"]}
    other = {"src2" => ["link2"], "src" => ["link2"]}
    data = LinkSubtractOp.call(this, other)
    data.keys.should == [:update_this]
    result = data[:update_this]
    result.should == {"src" => ["link"]}
    other.should == {"src2" => ["link2"], "src" => ["link2"]}
    #IMPORTANT:  Notice this is now updated within the Proc
    this.should == {"src" => ["link"] }
  end

end

describe NodeElementOperations, "Link, Get Operation" do
  include NodeElementOperations

  it "should work with nil" do
    this = {"src" => ["link", "link2"], "src2" => ["link2"]}
    other = nil
    data = LinkGetOp.call(this, other)
    data.keys.should == [:return_value, :update_this]
    this_result = data[:update_this]
    rtn_val = data[:return_value] 
    rtn_val.should == nil
    this_result.should == {"src" => ["link", "link2"], "src2" => ["link2"]}
    other.should == nil
    #IMPORTANT:  Notice this is now updated within the Proc
    this.should == {"src" => ["link", "link2"], "src2" => ["link2"]}
  end

  it "should work with nominal data" do
    this = {"src" => ["link", "link2"], "src2" => ["link2"]}
    other = "link" 
    data = LinkGetOp.call(this, other)
    data.keys.should == [:return_value, :update_this]
    this_result = data[:update_this]
    rtn_val = data[:return_value]
    rtn_val.should == "src"
    this_result.should == {"src" => ["link", "link2"], "src2" => ["link2"]}
    other.should == "link"
    #IMPORTANT:  Notice this is now updated within the Proc
    this.should == {"src" => ["link", "link2"], "src2" => ["link2"]}
  end


  #TODO: Add in the roll up constants
end
