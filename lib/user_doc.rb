require 'couchrest'
#=begin
require 'cgi' #Can replace with url_escape if performance is an issue

require File.dirname(__FILE__) + '/bufs_info_attachment'
#TODO keep the classes in separate files? 

#This class is the primary interface into CouchDB BUFS documents
class BufsInfoDoc < CouchRest::ExtendedDocument
  #include BufsCommon

  #class << self; attr_accessor  :attachment_base_id, end
  #name_space is the CouchDB database to use

  #All attachment documents have a specific name postfixed to the main BufsInfoDoc id
  #@attachment_base_id = '_attachments'
  #use_database @name_space

  #If a document has an attachment it gets this accessor set (needs testing!! not sure it works in all cases)
  attr_accessor :attachment_doc

  #Methods that act on the BufsInfoDoc collection (i.e. all BufsInfoDoc objects) 
  
  #Find documents with matching parent categories
  view_by :parent_categories,
    :map =>
    "function(doc) {
        if (doc['couchrest-type'] == 'BufsInfoDoc' && doc.parent_categories) {
          doc.parent_categories.forEach(function(cat){
            emit(cat, 1);
          });
        }
      }",
    :reduce =>
    "function(keys, values, rereduce) {
        return sum(values);
      }"

  #Find documents that have attachments. Important future feature!!
  view_by :attachment,
    :map =>
    "function(doc) {
         if (doc._attachments) {
             emit(null, doc._attachments);
         }
      }"


  #Find documents by their category
  view_by :my_category

  #Define document parameters
  property :name_space    #all categories within the name space must be unique
  property :parent_categories
  property :my_category
  property :description
  property :file_metadata
  property :attachment_doc_id

  timestamps!

  #validate parent categories exist  - should this be deprecated?
  #set_callback :save, :before, :method_name 
  #save_callback :before do |almost_a_doc|
  set_callback :save, :before, do |almost_a_doc|
    if almost_a_doc.parent_categories.nil? || almost_a_doc.parent_categories.empty?
      raise ArgumentError, "Requires at least one parent category to be set (can be set to top node category)"
    end
  end

#class methods
  #Setter for setting the name space, which is the CouchDB database in this case
=begin
  def self.set_name_space(name_space)
    @name_space = name_space
    use_database @name_space
    #TODO: Is there a better place to set Attachment name space, this approach is a bit dangerous
    #since I'm doing dynamic assignment to what's assumed by the class to be static
    #TODO: Actually, dynamically setting name space is dangerous in general
    #what if the name space is reset to some other value at some random point?
    #What's needed is a class factory that creates a class on the fly maybe?
    BufsInfoAttachment.set_name_space(@name_space) unless BufsInfoAttachment.name_space
  end
=end
  #Create the document in the BUFS node format from an existing node.  A BUFS node is an object that has the following properties:
  #  my_category
  #  parent_categories
  #  description
  #  attachments in the form of data files
  #
  #TODO: Verify this method is useful and being used (AbstractNode may have superseded this method)
  def self.create_from_node(node_obj)
    init_params = {}
    init_params['my_category'] = node_obj.my_category
    init_params['description'] = node_obj.description if node_obj.description
    new_sid = self.new(init_params)
    new_sid.add_parent_categories(node_obj.parent_categories)
    new_sid.save
    new_sid.add_data_file(node_obj.files) if node_obj.files
    return new_sid.class.get(new_sid['_id'])
  end

  def self.attachment_base_id
    "_attachments"
  end

  #Initialize the document with no attachments and then initialize as a CouchRest::ExtendedDocument
  def initialize(*args)
    @attachment_doc = nil
    super(*args)
  end

  #Adds parent categories, it can accept a single category or an array of categories
  def add_parent_categories(new_cats)
    current_cats = orig_cats = self['parent_categories']||[]
    new_cats = [new_cats].flatten
    current_cats += new_cats
    current_cats.uniq!
    current_cats.compact!
    if current_cats.size > orig_cats.size
      self['parent_categories'] = current_cats
      self.save
    end
  end
  #Can accept a single category or an array of categories
  def remove_parent_categories(cats_to_remove)
    cats_to_remove = [cats_to_remove].flatten
    cats_to_remove.each do |remove_cat|
      self['parent_categories'].delete(remove_cat)
    end
    self.save(:deletions)
    raise "temp error due to no parent categories existing" if self.parent_categories.empty?
  end  

  #Returns the attachment id associated with this document.  Note that this does not depend upon there being an attachment.
  def my_attachment_doc_id
    if self['_id']
      return self['_id'] + BufsInfoDoc.attachment_base_id
    else
      raise "Can't attach to a document that has not been saved to the db"
    end
  end

  #Get attachment metadata.  This does not return the actual data.
  def get_file_data(attach_file_name)
    return CouchDB.fetch_attachment(BufsInfoAttachment.get(my_attachment_doc_id), attach_file_name)
  end

  #Get attachment data.  Note that the data is read in as a complete block, this may be something that needs optimized.
  def add_raw_data(attach_name, content_type, raw_data, file_modified_at = nil)
    file_metadata = {}
    if file_modified_at
      file_metadata['file_modified'] = file_modified_at
    else
      file_metadata['file_modified'] = Time.now.to_s
    end
    file_metadata['content_type'] = content_type #|| 'application/x-unknown'
    attachment_package = {}
    unesc_attach_name = CGI.unescape(attach_name)
    attachment_package[unesc_attach_name] = {'data' => raw_data, 'md' => file_metadata}
    
    #puts "My Attach ID: #{ self.my_attachment_doc_id}"
    #puts "My Attach Package: #{attachment_package.inspect}"

    bia = self.class.user_attachClass.get(self.my_attachment_doc_id)
    #p my_attachment_doc_id
    #puts "SIA found: #{bia.inspect}"
    if bia
      #puts "Updating Attachment"
      bia.update_attachment_package(self, attachment_package)
    else
      #puts "Creating new Attachment"
      bia = self.class.user_attachClass.create_attachment_package(self, attachment_package)
      #bia = BufsInfoAttachment.create_attachment_package(self['_id'], attachment_package)
      #puts "BIA created: #{bia.inspect}"
    end

    #puts "Current ID #{self['_id']}"
    current_node_doc = self.class.get(self['_id'])
    current_node_doc.attachment_doc_id = bia['_id']
    current_node_attach = self.class.user_attachClass.get(current_node_doc.attachment_doc_id)
    current_node_attach.save
    #puts "New Attach: #{current_node_attach.inspect}"
  end

  #Add an attachment to the BufsInfoDoc object from a file
  def add_data_file(attachment_filenames)

    attachment_package = {}
    attachment_filenames = [attachment_filenames].flatten
    attachment_filenames.each do |at_f|
      #puts "Filename to attach: #{at_f.inspect}"
      at_basename = File.basename(at_f)
      #basename can't contain '+', replace with space
      at_basename.gsub!('+', ' ')
      #sc_at_basename = CGI::escape(at_basename)
      #p at_basename
      file_metadata = {}
      file_metadata['file_modified'] = File.mtime(at_f).to_s
      file_metadata['content_type'] = MimeNew.for_ofc_x(at_basename)
      file_data = File.open(at_f, "rb"){|f| f.read}
      ##{at_basename => {:file_modified => File.mtime(at_f)}}
      #Unescaping '+' to space  because CouchDB will escape it leading to space -> + -> %2b
      unesc_at_basename = CGI.unescape(at_basename)
      attachment_package[unesc_at_basename] = {'data' => file_data, 'md' => file_metadata}
    end
    #puts "getting attachment doc id"
    #p my_attachment_doc_id
    attachment_record = self.class.user_attachClass.get(my_attachment_doc_id)
    #p my_attachment_doc_id
    # puts "SIA found: #{sia.inspect}"
    if attachment_record
      puts "Updating Attachment"
      attachment_record.update_attachment_package(self, attachment_package)
    else
      puts "Creating new Attachment"
      attachment_record = self.class.user_attachClass.create_attachment_package(self, attachment_package)
      #puts "SIA created: #{sia.inspect}"
    end

    #puts "Current ID #{self['_id']}"
    current_node_doc = self.class.get(self['_id'])
    current_node_doc.attachment_doc_id = attachment_record['_id']
    current_node_doc.save
    current_node_attach = self.class.user_attachClass.get(current_node_doc.attachment_doc_id)
    current_node_attach.save
  end

  #Save the object to the CouchDB database
  #  save_type can be either :additions or :deletions
  #  :additions will merge parent categories with any categories in the database
  #  :deletions will replace any existing parent categories with those of the object
  def save(save_type = :additions)
    puts "Entered save method"
    #save_type :additions or :deletions
    #refers to whether parent category information is merged or deleted
    #I'll probably have to change this when dealing with files too
    raise ArgumentError, "Requires my_category to be set before saving" unless self.my_category
    self['_id'] = self.class.namespace.to_s + '_' + self.class.to_s + '_' + self.my_category
    #self['_id'] = BufsInfoDoc.name_space.to_s + '_' + self.class.to_s + '_' + self.my_category
    existing_doc = BufsInfoDoc.get(self['_id'])
    begin
      #before_self = self.parent_categories
      #super
      puts self.class.inspect
      puts self.class.name_space.inspect
      self.class.namespace.save_doc(self) #saving using database method, not ExtendedDoc method (didn't work for some reason)
      #BufsInfoDoc.name_space.save_doc(self) #saving using database method, not ExtendedDoc method (didn't work for some reason) 
      #raise "Self: #{before_self}, Before: #{existing_doc.parent_categories.inspect}, after: #{BufsInfoDoc.get(self['_id']).parent_categories.inspect}" #if save_type == :deletions
    rescue RestClient::RequestFailed => e
      if e.http_code == 409
        puts "Found existing doc while trying to save ... using it instead"
	case save_type
	when :additions
          existing_doc.parent_categories = (existing_doc.parent_categories + self.parent_categories).uniq
	when :deletions
	  existing_doc.parent_categories = self.parent_categories
	else
	  raise "save type parameter of #{save_type} not understood"
	end
        existing_doc.description = self.description if self.description
        existing_doc['_attachments'] = existing_doc['attachments'].merge(self['_attachments']) if self['_attachments']
        existing_doc['file_metadata'] = existing_doc['file_metadata'].merge(self['file_metadata']) if self['file_metadata']
        existing_doc.save
        return existing_doc
      else
        raise e
      end
    end
    return self
  end

  #Deletes the object and its CouchDB entry
  def destroy_node
    att_doc = self.class.get(self.attachment_doc_id)
    att_doc.destroy if att_doc
    begin
      self.destroy
    rescue ArgumentError => e
      puts "Rescued Error: #{e} while trying to destroy #{self.my_category} node"
      me = self.class.get(self['_id'])
      me.destroy
    end
  end

end

#=end

class UserDoc

  def initialize(init_params = {})
    init_params.each do |attr_name, attr_value|
      iv_set(attr_name, attr_value)
    end
    @my_dir = BufsFileSystem.name_space + '/' + self.my_category + '/' if self.my_category
    @attached_files = []
  end

  def iv_set(attr_var, attr_value)
    instance_variable_set("@#{attr_var}", attr_value)
  end

end

class UserDB
  #attr_accessor :namespace
  class << self; attr_accessor :user_to_docClass, :docClass_users, :docClasses; end
  UserDB.docClasses = []
  UserDB.user_to_docClass = {}
  UserDB.docClass_users = {}

  attr_reader :docClass, :namespace
  def initialize(couchdb, user_id)
    @namespace = couchdb
    @user_doc_class_name = "UserDoc#{user_id}"
    @user_attach_class_name = "UserAttach#{user_id}"

    #Security TODO: remove spaces and other 

    #initialize Class and add constant for the User namespace
    #---- Dynamic Class Definitions ----
    dyn_user_class_def = "class #{@user_doc_class_name} < BufsInfoDoc
      use_database CouchRest.database!(\"http://#{@namespace.to_s}/\")
      class << self; attr_accessor :user_attachClass; end

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

    #----------------------------------
    #puts "Dynamic Class Def:\n #{dyn_class_def}"

    UserDB.class_eval(dyn_user_class_def)
    UserDB.class_eval(dyn_attach_class_def)
    #puts "Database: #{UserDB.const_get(@user_doc_class_name).use_database.inspect}"

    @docClass = UserDB.const_get(@user_doc_class_name)
    @attachClass = UserDB.const_get(@user_attach_class_name)
    @docClass.user_attachClass = @attachClass

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
  
  #@@database_table = {}
  ##monkey patches
  #def  self.use_database(db)
  #  @@database_table[self.object_id] = db
  #end

  #def self.database
  #  @@database_table[self.object_id]
  #end
  #doc_db_name_2 = "http://127.0.0.1:5984/bufs_test_spec_2/"
  #CouchDB2 = CouchRest.database!(doc_db_name_2)
  #CouchDB2.compact!
  #use_database CouchDB2
  #class << self; attr_accessor :name_space, :attachment_base_id end
 
  #def self.set_name_space(name_space)
   # @name_space = name_space
   # use_database CouchDB2
  #end
