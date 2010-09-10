require File.dirname(__FILE__) + '/bufs_base_node'

class BufsNodeFactory 
  def self.make(node_env)
    raise "No Node Environment provided" unless node_env
    raise "Empty Node Environment provided" if node_env.empty?
    raise "Malformed Node Environment" unless node_env.keys.size == 1
    node_class_name = node_env.keys.first
    reqs = node_env[node_class_name][:requires]
    reqs.each {|r| require r} if reqs
    @user_id = node_env[node_class_name][:user_id] #TODO Remove when not needed for testing
    #TODO: Make setting the environment thread safe
    @class_environment = node_env[node_class_name][:class_env]
    @user_doc_class_name = node_class_name #"UserNode#{user_id}"
    #@user_attach_class_name = "UserAttach#{user_id}"  TODO Figure out attachments

    #Security TODO: remove spaces and other 

    #initialize Class and add constant for the User namespace
    #Note, the include is to the base class! not the user class
    #BufsInfoDoc.__send__(:include, @user_doc_env_methods)
    #BufsBaseNode.__send__(:include, @user_doc_env_methods)
    #---- Dynamic Class Definitions ----
    dyn_user_class_def = "class #{@user_doc_class_name} < BufsBaseNode
      
      class << self; attr_accessor :user_attachClass end

      end"

#DYN ATTACH HAS TO MOVE TO SOMEWHERE? Bufs Info FilesMgr??

 #   dyn_attach_class_def = "class #{@user_attach_class_name} < BufsInfoAttachment
 #     use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")
 #
 #     def self.namespace
 #       CouchRest.database!(\"http://#{@namespace.to_s}/\")
 #     end
 #   end"

    #dyn_link_class_def = "class #{@user_link_class_name} < BufsInfoLink
    #  use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")

     # def self.namespace
     #   CouchRest.database!(\"http://#{@namespace.to_s}/\")
     # end
    #end"
    #----------------------------------
    #puts "Dynamic Class Def:\n #{dyn_class_def}"

    BufsNodeFactory.class_eval(dyn_user_class_def)
 #   UserNode.class_eval(dyn_attach_class_def)
    #UserNode.class_eval(dyn_link_class_def)

    @docClass = BufsNodeFactory.const_get(@user_doc_class_name)
 #   @attachClass = UserNode.const_get(@user_attach_class_name)
    #@linkClass = UserNode.const_get(@user_link_class_name)
    #@docClass.set_environment(@user_environment)
 #   @docClass.user_attachClass = @attachClass
    #@docClass.user_linkClass = @linkClass
    @docClass.set_environment(@class_environment)
    #Perform user <=> CouchDB Document bindings
    #Add to List of docClasses
    #UserNode.docClasses << @docClass
    #UserNode.docClasses.uniq!
    #Assign user CouchDB Document (for looking up user's docClass)
    #UserNode.user_to_docClass[user_id] = @docClass
    #Assign users to a CouchDB Extended Document Class (allows shared db for multiple users)
    #if UserNode.docClass_users[@docClass.name]
      #UserNode.docClass_users[@docClass.name]  << user_id
    #else
      #UserNode.docClass_users[@docClass.name] = [user_id]
    #end
    #UserNode.docClass_users[@docClass.name].uniq!  
    @docClass
  end
end 
  
