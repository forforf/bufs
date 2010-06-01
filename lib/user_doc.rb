require 'couchrest'

require File.dirname(__FILE__) + '/bufs_info_doc'

class UserDB
  #attr_accessor :namespace
  class << self; attr_accessor :user_to_docClass, :docClass_users, :docClasses; end
  UserDB.docClasses = []
  UserDB.user_to_docClass = {}
  UserDB.docClass_users = {}

  attr_reader :docClass, :namespace #, :user_attach_class_name
  def initialize(couchdb, user_id)
    @namespace = couchdb
    @user_doc_class_name = "UserDoc#{user_id}"
    @user_attach_class_name = "UserAttach#{user_id}"
    @user_link_class_name = "UserLink#{user_id}"

    #Security TODO: remove spaces and other 

    #initialize Class and add constant for the User namespace
    #---- Dynamic Class Definitions ----
    dyn_user_class_def = "class #{@user_doc_class_name} < BufsInfoDoc
      use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")
      class << self; attr_accessor :user_attachClass, :user_linkClass; end

      #Find documents by their category
      view_by :my_category

      def self.namespace
        CouchRest.database!(\"http://#{@namespace.to_s}/\")
      end
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
    #puts "Database: #{UserDB.const_get(@user_doc_class_name).use_database.inspect}"

    @docClass = UserDB.const_get(@user_doc_class_name)
    @attachClass = UserDB.const_get(@user_attach_class_name)
    @linkClass = UserDB.const_get(@user_link_class_name)
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
  
