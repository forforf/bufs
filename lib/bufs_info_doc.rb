require 'couchrest'

require 'cgi' #Can replace with url_escape if performance is an issue

#require 'scout_info_node'
require File.dirname(__FILE__) + '/bufs_info_attachment'


class BufsInfoDoc < CouchRest::ExtendedDocument
  class << self; attr_accessor :name_space, :attachment_base_id end
  @name_space = nil #CouchDB
  @attachment_base_id = '_attach_doc_id'
  #use_database @name_space

  attr_accessor :attachment_doc

  #inter-model stuff
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

  view_by :attachment,
    :map =>
    "function(doc) {
         if (doc._attachments) {
             emit(null, doc._attachments);
         }
      }"

  view_by :title

  view_by :my_category
=begin
  ,
    :map =>
    "function(doc) {
         if (doc['couchrest-type'] == 'ScoutInfoDoc' && doc.my_category) {
             emit(doc.my_category, doc.my_category);
         }
      }"
=end
  #pure model stuff
  property :name_space    #all categories within the name space must be unique
  property :parent_categories
  property :my_category
  property :description
  property :file_metadata
  property :attachment_doc_id

  timestamps!

  save_callback :before do |almost_a_doc|
  
    if almost_a_doc.parent_categories.nil? || almost_a_doc.parent_categories.empty?
      raise ArgumentError, "Requires at least one parent category to be set (can be set to top node category)"
    end
  end

#class methods
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

    #A node is an object that responds to:
    # note: a category is a string that is unique to the name space)
    # #my_category with a category naming itself
    # #parent_categories with an array of categories for any parent relationships
    # #files nil or an array of filenames for data associated with that entry (currently only one is allowed)
    # #description nil or a string
  def self.create_from_node(node_obj)
    init_params = {}
    init_params['my_category'] = node_obj.my_category
    init_params['description'] = node_obj.description if node_obj.description
    new_sid = self.new(init_params)
    new_sid.add_parent_categories(node_obj.parent_categories)
    new_sid.save
    new_sid.add_data_file(node_obj.files) if node_obj.files
    return BufsInfoDoc.get(new_sid['_id'])
  end

  def initialize(*args)
    @attachment_doc = nil
    super(*args)
  end

  def add_parent_categories(new_cats)
    current_cats = orig_cats = self['parent_categories']||[]
    new_cats = [new_cats].flatten
    current_cats += new_cats
    current_cats.uniq!
    current_cats.compact!
    if current_cats.size > orig_cats.size
      #current_doc = ScoutInfoDoc.get(self['_id']) # unless self.new_document?
      #if current_doc
      #  current_doc['parent_categories'] = current_cats
      #  current_doc.save
      #else
      self['parent_categories'] = current_cats
      self.save
      #end
    end
  end
  alias :add_category :add_parent_categories
  alias :add_categories :add_parent_categories

  def my_attachment_doc_id
    if self['_id']
      return self['_id'] + BufsInfoDoc.attachment_base_id
    else
      raise "Can't attach to a document that has not been saved to the db"
    end
  end

  def get_file_data(file_name)
    return CouchDB.fetch_attachment(BufsInfoAttachment.get(my_attachment_doc_id), file_name)
  end

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

    bia = BufsInfoAttachment.get(self.my_attachment_doc_id)
    #p my_attachment_doc_id
    #puts "SIA found: #{bia.inspect}"
    if bia
      #puts "Updating Attachment"
      bia.update_attachment_package(attachment_package)
    else
      #puts "Creating new Attachment"
      bia = BufsInfoAttachment.create_attachment_package(self['_id'], attachment_package)
      #puts "BIA created: #{bia.inspect}"
    end

    #puts "Current ID #{self['_id']}"
    current_node_doc = BufsInfoDoc.get(self['_id'])
    current_node_doc.attachment_doc_id = bia['_id']
    current_node_attach = BufsInfoAttachment.get(current_node_doc.attachment_doc_id)
    current_node_attach.save
    #puts "New Attach: #{current_node_attach.inspect}"
  end

  def add_data_file(attachment_filenames)

    attachment_package = {}
    attachment_filenames = [attachment_filenames].flatten
    attachment_filenames.each do |at_f|
      #puts "Filename to attach: #{at_f.inspect}"
      at_basename = File.basename(at_f)
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
    sia = BufsInfoAttachment.get(my_attachment_doc_id)
    #p my_attachment_doc_id
    # puts "SIA found: #{sia.inspect}"
    if sia
      puts "Updating Attachment"
      sia.update_attachment_package(attachment_package)
    else
      puts "Creating new Attachment"
      sia = BufsInfoAttachment.create_attachment_package(self['_id'], attachment_package)
      #puts "SIA created: #{sia.inspect}"
    end

    #puts "Current ID #{self['_id']}"
    current_node_doc = BufsInfoDoc.get(self['_id'])
    current_node_doc.attachment_doc_id = sia['_id']
    current_node_doc.save
    current_node_attach = BufsInfoAttachment.get(current_node_doc.attachment_doc_id)
    current_node_attach.save

  end
  #alias :update_attachments :add_data_file

  def save
    raise ArgumentError, "Requires my_category to be set before saving" unless self.my_category
    self['_id'] = BufsInfoDoc.name_space.to_s + '_' + self.my_category
    existing_doc = BufsInfoDoc.get(self['_id'])
    begin
      super
    rescue RestClient::RequestFailed => e
      if e.http_code == 409
        puts "Found existing doc ... using it instead"
        existing_doc.parent_categories = (existing_doc.parent_categories + self.parent_categories).uniq
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

  #would prefer to do this in a superclass, but we're already subclassed
  #def == (other)
  #  my_node = [self.parent_categories.sort, self.my_category, self.description, self.file_metadata]
  #  other_node = [other.parent_categories.sort, other.my_category, other.description, other.file_metadata]
  #  my_node == other_node
  #end

end
