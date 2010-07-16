require File.dirname(__FILE__) + '/../lib/bind_user_file_system'


describe BindUserFileSystem do
  before(:all) do 
    @test_users = [] 
  end

  after(:all) do
    if @test_users.size > 0
      @test_users.each do |test_user|
        BindUserFileSystem.remove_user_from_system(test_user)
      end
    end
  end

  it "should return false if user doesn't exist" do
    BindUserFileSystem.user_exists?("test3").should == false
  end

  it "should add a user account to the system" do
    user = "test3"
    @test_users << user
    BindUserFileSystem.user_exists?(user).should == false
    BindUserFileSystem.add_user_to_system(user, "1234")
    BindUserFileSystem.user_exists?(user).should == true
  end

  it "should remove a user account from the system" do
    user = @test_users.first
    BindUserFileSystem.user_exists?(user).should == true
    BindUserFileSystem.remove_user_from_system(user)
    BindUserFileSystem.user_exists?(user).should == false
  end

  it "should add a user (if they dont exist) and return the users File Node Class" do
    @test_users = ["test3", "test4"]
    user_a = @test_users.first
    user_b = @test_users.last
    user_nodes = []
    BindUserFileSystem.add_user_to_system(user_a, "1234")
    BindUserFileSystem.user_exists?(user_a).should == true
    @test_users.each do |user|
      user_nodes << BindUserFileSystem.get_user_node(user, "1234")
    end
    user_nodes.each do |user_node|
      #TODO: Create test to check a class of the right type is returned
      p user_node
    end
  end
end

