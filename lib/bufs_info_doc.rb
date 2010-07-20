#common libraries
require 'couchrest'

#bufs libraries
require File.dirname(__FILE__) + '/bufs_info_attachment'
require File.dirname(__FILE__) + '/bufs_info_link'
require File.dirname(__FILE__) + '/bufs_escape'

#This class is the primary interface into CouchDB BUFS documents
class BufsInfoDoc < CouchRest::ExtendedDocument
  #class configuration
  DummyNamespace = "BufsInfoDocDefault"
  AttachmentBaseID = "_attachments"
  LinkBaseID = "_links"

  #This should be defined in the dynamic class definition
  #The default value here is for teting basic functionality
  def self.namespace 
    DummyNamespace
  end

  #This should be defined in the dynamic class definition
  #The default value here is for teting basic functionality
  def self.user_attachClass
    BufsInfoAttachment #this should be overwritten
  end

  #This should be defined in the dynamic class definition
  #The default value here is for teting basic functionality
  def self.user_linkClass
    BufsInfoLink  #this should be overwritten
  end

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
  property :links_doc_id

  timestamps!


  #Create the document in the BUFS node format from an existing node.  A BUFS node is an object that has the following properties:
  #  my_category
  #  parent_categories
  #  description
  #  attachments in the form of data files
  #
  #TODO If this is handled in the base models then each base model should
  #have a common way of providing the collection of parameters
  #rather than this hard coded version.
  def self.create_from_file_node(node_obj)
    init_params = {}
    init_params['my_category'] = node_obj.my_category
    init_params['description'] = node_obj.description if node_obj.description
    new_bid = self.new(init_params)
    new_bid.add_parent_categories(node_obj.parent_categories)
    new_bid.save
    new_bid.add_data_file(node_obj.list_attached_files) if node_obj.list_attached_files
    return new_bid.class.get(new_bid['_id'])
  end

  #Returns the id that will be appended to the document ID to uniquely
  #identify attachment documents associated with the main document
  def self.attachment_base_id
    AttachmentBaseID 
  end

  #Returns the id that will be appended to the document ID to uniquely
  #identify link documents associated with the main document
  def self.link_base_id
    LinkBaseID 
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
      return self['_id'] + self.class.attachment_base_id
    else
      raise "Can't attach to a document that has not first been saved to the db"
    end
  end

  def get_attachment_names
    att_doc_id = self.class.get(self['_id']).attachment_doc_id
    att_doc = self.class.get(att_doc_id)||{}
    attachments = att_doc['_attachments']||{}
    att_names = attachments.keys
  end

  #Get attachment content.  Note that the data is read in as a complete block, this may be something that needs optimized.
  def add_raw_data(attach_name, content_type, raw_data, file_modified_at = nil)
    file_metadata = {}
    if file_modified_at
      file_metadata['file_modified'] = file_modified_at
    else
      file_metadata['file_modified'] = Time.now.to_s
    end
    file_metadata['content_type'] = content_type #TODO: is unknown content handled gracefully?
    attachment_package = {}
    unesc_attach_name = BufsEscape.unescape(attach_name)
    attachment_package[unesc_attach_name] = {'data' => raw_data, 'md' => file_metadata}
    bia = self.class.user_attachClass.get(self.my_attachment_doc_id)
    if bia
      bia.update_attachment_package(self, attachment_package)
    else
      bia = self.class.user_attachClass.create_attachment_package(self, attachment_package)
    end

    current_node_doc = self.class.get(self['_id'])
    current_node_doc.attachment_doc_id = bia['_id']
    current_node_attach = self.class.user_attachClass.get(current_node_doc.attachment_doc_id)
    current_node_attach.save
  end

  #Add an attachment to the BufsInfoDoc object from a file
  def add_data_file(attachment_filenames)

    attachment_package = {}
    attachment_filenames = [attachment_filenames].flatten
    attachment_filenames.each do |at_f|
      at_basename = File.basename(at_f)
      #basename can't contain '+', replace with space
      at_basename.gsub!('+', ' ')
      file_metadata = {}
      file_metadata['file_modified'] = File.mtime(at_f).to_s
      file_metadata['content_type'] = MimeNew.for_ofc_x(at_basename)
      file_data = File.open(at_f, "rb"){|f| f.read}
      ##{at_basename => {:file_modified => File.mtime(at_f)}}
      #Unescaping '+' to space  because CouchDB will escape it leading to space -> + -> %2b
      unesc_at_basename = BufsEscape.unescape(at_basename)
      attachment_package[unesc_at_basename] = {'data' => file_data, 'md' => file_metadata}
    end
    #getting attachment doc id
    attachment_record = self.class.user_attachClass.get(my_attachment_doc_id)
    if attachment_record
      #puts "Updating Attachment"
      attachment_record.update_attachment_package(self, attachment_package)
    else
      #puts "Creating new Attachment"
      attachment_record = self.class.user_attachClass.create_attachment_package(self, attachment_package)
    end

    current_node_doc = self.class.get(self['_id'])
    current_node_doc.attachment_doc_id = attachment_record['_id']
    current_node_doc.save
    current_node_attach = self.class.user_attachClass.get(current_node_doc.attachment_doc_id)
    current_node_attach.save
  end

  def remove_attachments  #Spec is in user_doc_spec
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc.delete('attachment_doc_id')
    current_node_doc.save
    current_node_attach = self.class.user_attachClass.get(att_doc_id)
    current_node_attach.destroy
  end


  def remove_attachment(attachment_name)
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc['attachment_doc_id']
    current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
    current_node_attachment_doc['md_attachments'].delete(attachment_name)
    current_node_attachment_doc.delete_attachment(attachment_name)
    current_node_attachment_doc.save
  end

#TODO: Add to spec (currently not used)
  def attachment_url(attachment_name)
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc['attachment_doc_id']
    current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
    current_node_attachment_doc.attachment_url(attachment_name)
  end

  def attachment_data(attachment_name)
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc['attachment_doc_id']
    current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
    current_node_attachment_doc.read_attachment(attachment_name)
  end

  def get_attachment_metadata
    current_node_doc = self.class.get(self['_id'])
    att_doc_id = current_node_doc['attachment_doc_id']
    current_node_attachment_doc = self.class.user_attachClass.get(att_doc_id)
  end



  #Save the object to the CouchDB database
  #  save_type can be either :additions or :deletions
  #  :additions will merge parent categories with any categories in the database
  #  :deletions will replace any existing parent categories with those of the object
  def save(save_type = :additions)
    #save_type :additions or :deletions
    #refers to whether parent category information is merged or deleted
    #I'll probably have to change this when dealing with files too
    raise ArgumentError, "Requires my_category to be set before saving" unless self.my_category
    self['_id'] = self.class.namespace.to_s + '_' + self.class.to_s + '_' + self.my_category
    #self['_id'] = BufsInfoDoc.name_space.to_s + '_' + self.class.to_s + '_' + self.my_category
    existing_doc = BufsInfoDoc.get(self['_id'])
    begin
      self.database.save_doc(self)
    rescue RestClient::RequestFailed => e
      if e.http_code == 409
        puts "Found existing doc (id: #{self['_id']} while trying to save ... using it instead"
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

  def my_link_doc_id
    return self['_id'] + self.class.link_base_id
  end


  def add_links(links)
    self.links_doc_id = self.my_link_doc_id  
    self.save
    self.class.user_linkClass.add_links(self, links)
  end

  def remove_links(links_to_remove)
    self.links_doc_id = self.my_link_doc_id
    self.save
    self.class.user_linkClass.remove_links(self, links_to_remove)
  end

  def get_link_names
    link_doc_id = self.class.get(self['_id']).links_doc_id
    link_doc = self.class.get(link_doc_id)||{}
    links = link_doc['uris']||{}
    link_names = links
  end

  alias_method(:list_links, :get_link_names) #TODO: synchronize with bufs_file_system

  #Deletes the object and its CouchDB entry
  def destroy_node
    att_doc = self.class.get(self.attachment_doc_id)
    att_doc.destroy if att_doc
    link_doc = self.class.get(self.links_doc_id)
    link_doc.destroy if link_doc
    begin
      self.destroy
    rescue ArgumentError => e
      puts "Rescued Error: #{e} while trying to destroy #{self.my_category} node"
      me = self.class.get(self['_id'])
      me.destroy
    end
  end
end

