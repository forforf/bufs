#bufs model
require File.dirname(__FILE__) + '/bufs_file_system'
require File.dirname(__FILE__) + '/bufs_view_builder'


class UserFileNode
  class << self; attr_accessor :nodeClasses, :user_to_nodeClass, :nodeClass_users, :model_dir; end #:user_to_docClass, :docClass_users, :docClasses; end
  UserFileNode.nodeClasses = []
  UserFileNode.user_to_nodeClass = {}
  UserFileNode.nodeClass_users = {}
  #TODO: Modify model dir to be settable on a per user basis
  UserFileNode.model_dir = "model"
 

  attr_reader :nodeClass, :namespace

  #create the bufs model class to handle specific users
  def initialize(filesys, user_id)
    #TODO: Check for appropriate / 
    @namespace = filesys + UserFileNode.model_dir
    @user_node_class_name = "UserFN#{user_id}"
    #@user_attach_class_name = "UserAttach#{user_id}"
    #@user_link_class_name = "UserLink#{user_id}"

    #Security TODO: remove spaces and other things that might lead to unintended execution

    #initialize Class and add constant for the User namespace
    #---- Dynamic Class Definitions ----
    dyn_user_class_def = "class #{@user_node_class_name} < BufsFileSystem
      use_directory \"#{@namespace}\"
      class << self; attr_accessor :user_attachClass, :user_linkClass; end

      #Find documents by their category
      #view_by :my_category

      #def self.namespace
      #  \"#{@namespace}\"
      #end
    end"

    #dyn_attach_class_def = "class #{@user_attach_class_name} < BufsInfoAttachment
    #  use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")

    #  def self.namespace
    #    CouchRest.database!(\"http://#{@namespace.to_s}/\")
    #  end
    #end"

    #dyn_link_class_def = "class #{@user_link_class_name} < BufsInfoLink
    #  use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")

    #  def self.namespace
    #    CouchRest.database!(\"http://#{@namespace.to_s}/\")
    #  end
    #end"
    ##----------------------------------
    ##puts "Dynamic Class Def:\n #{dyn_class_def}"

    UserFileNode.class_eval(dyn_user_class_def)
    #UserDB.class_eval(dyn_attach_class_def)
    #UserDB.class_eval(dyn_link_class_def)
    #puts "Database: #{UserDB.const_get(@user_doc_class_name).use_database.inspect}"

    @nodeClass = UserFileNode.const_get(@user_node_class_name)
    #@attachClass = UserDB.const_get(@user_attach_class_name)
    #@linkClass = UserDB.const_get(@user_link_class_name)
    #@docClass.user_attachClass = @attachClass
    #@docClass.user_linkClass = @linkClass

    ##Perform user <=> File System bindings
    ##Add to List of docClasses
    UserFileNode.nodeClasses << @nodeClass
    UserFileNode.nodeClasses.uniq!
    #Assign user CouchDB Document (for looking up user's docClass)
    UserFileNode.user_to_nodeClass[user_id] = @nodeClass
    #Assign users to a CouchDB Extended Document Class (allows shared db for multiple users)
    if UserFileNode.nodeClass_users[@nodeClass.name]
      UserFileNode.nodeClass_users[@nodeClass.name]  << user_id
    else
      UserFileNode.nodeClass_users[@nodeClass.name] = [user_id]
    end
    UserFileNode.nodeClass_users[@nodeClass.name].uniq!  

  end
end 
