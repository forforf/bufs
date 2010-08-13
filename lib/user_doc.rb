#require 'couchrest'

#bufs model
require File.dirname(__FILE__) + '/bufs_info_doc'

class UserDB
  class << self; attr_accessor :docClasses, :user_to_docClass, :docClass_users; end
  UserDB.docClasses = []
  UserDB.user_to_docClass = {}
  UserDB.docClass_users = {}

  attr_reader :docClass, :namespace

  #create the bufs model class to handle specific users 
  def initialize(couchdb, user_id)
    @user_id = user_id #TODO Remove when not needed for testing
    @namespace = couchdb
    #TODO: Make setting the environment thread safe
    @user_environment = { :bufs_info_doc_env => {:host => couchdb.host,
                                                 :path => couchdb.uri,
                                                 :user_id => user_id}
                        }
    @user_doc_class_name = "UserDoc#{user_id}"
    @user_attach_class_name = "UserAttach#{user_id}"
    @user_link_class_name = "UserLink#{user_id}"

    #Security TODO: remove spaces and other 

    #initialize Class and add constant for the User namespace
    #---- Dynamic Class Definitions ----
    dyn_user_class_def = "class #{@user_doc_class_name} < BufsInfoDoc
      #use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")
      class << self; attr_accessor :user_attachClass, :user_linkClass; end

      #Find documents by their category
      #view_by :my_category

      #def self.namespace
      #  CouchRest.database!(\"http://#{@namespace.to_s}/\")
      #end
    end"

    dyn_attach_class_def = "class #{@user_attach_class_name} < BufsInfoAttachment
      use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")

      def self.namespace
        CouchRest.database!(\"http://#{@namespace.to_s}/\")
      end
    end"

    dyn_link_class_def = "class #{@user_link_class_name} < BufsInfoLink
      use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")

      def self.namespace
        CouchRest.database!(\"http://#{@namespace.to_s}/\")
      end
    end"
    #----------------------------------
    #puts "Dynamic Class Def:\n #{dyn_class_def}"

    UserDB.class_eval(dyn_user_class_def)
    UserDB.class_eval(dyn_attach_class_def)
    UserDB.class_eval(dyn_link_class_def)

    @docClass = UserDB.const_get(@user_doc_class_name)
    @attachClass = UserDB.const_get(@user_attach_class_name)
    @linkClass = UserDB.const_get(@user_link_class_name)
    puts "Setting Environment for #{@user_id}"
    puts "Class: #{@docClass.to_s}  Env: #{@user_environment.inspect}"
    @docClass.set_environment(@user_environment)
    @docClass.user_attachClass = @attachClass
    @docClass.user_linkClass = @linkClass

    #Perform user <=> CouchDB Document bindings
    #Add to List of docClasses
    UserDB.docClasses << @docClass
    UserDB.docClasses.uniq!
    #Assign user CouchDB Document (for looking up user's docClass)
    UserDB.user_to_docClass[user_id] = @docClass
    #Assign users to a CouchDB Extended Document Class (allows shared db for multiple users)
    if UserDB.docClass_users[@docClass.name]
      UserDB.docClass_users[@docClass.name]  << user_id
    else
      UserDB.docClass_users[@docClass.name] = [user_id]
    end
    UserDB.docClass_users[@docClass.name].uniq!  

  end
end 
  
