#= bufs_info_attachment.rb - Support for handling CouchDB attachments in the 'BUFS' (Bottom Up File System) Format
#
#Copyright (C) 2010  David Martin
#
#David Martin mailto:dmarti21@gmail.com
  

#require 'mime/types'
#require 'cgi'
require 'uri'

require File.dirname(__FILE__) + '/bufs_escape'
require 'couchrest'

class BufsInfoLink < CouchRest::ExtendedDocument

  property :uris


  def self.create_unsaved(bufs_info_doc)
    raise "No document provided for links" unless bufs_info_doc
    raise "No ID found for the document" unless bufs_info_doc['_id']
    uniq_id = bufs_info_doc['_id'] + bufs_info_doc.class.link_base_id
    link_doc = bufs_info_doc.class.user_linkClass.get(uniq_id)
    raise IndexError, "Can't create new link document for #{self}. Document already exists in Database" if link_doc
    link_doc = bufs_info_doc.class.user_linkClass.new('_id' => uniq_id)
  end

  def self.create(bufs_info_doc, links=nil)
    link_doc = create_unsaved(bufs_info_doc)
    raise "Unable to create link doc for #{bufs_info_doc.inspect}" unless link_doc
    links = [links].flatten.compact
    link_doc.uris = links
    bufs_info_doc.class.namespace.save_doc(link_doc)
    #link_doc.save
    #raise "ID: #{link_doc['_id']}"
    #bufs_info_doc.get(link_doc['_id'])
    bufs_info_doc.class.user_linkClass.get(link_doc['_id'])
  end

  def self.add_links(user_doc, uri_list)
    uri_list = [uri_list].flatten
    uri_list.each do |uri_string|
      URI.parse(uri_string) #validates uri
    end
    link_id = user_doc.links_doc_id #user_doc['_id'] + user_doc.class.link_base_id
    link_doc = nil
    if user_doc.class.user_linkClass.get(link_id)
      link_doc = user_doc.class.user_linkClass.get(link_id)
    else
      link_doc = user_doc.class.user_linkClass.create(user_doc)
    end
    #link_doc = BufsInfoLink.get(link_id)||BufsInfoLink.create(bufs_info_doc)
    raise "Unable to find existing links db doc or create new one for #{user_doc} Link ID: #{link_id}" unless link_doc
    link_doc.uris += uri_list
    link_doc.uris.compact!
    #raise link_doc.inspect
    link_doc.save
    link_doc.class.get(link_doc['_id'])
  end

  #NEEDS INTEGRATION AND TESTING
  def self.remove_links(user_doc, remove_these_uris)
    remove_these_uris = [remove_these_uris].flatten
    link_id = user_doc.links_doc_id
    link_doc = user_doc.class.user_linkClass.get(link_id)
    link_doc.uris = link_doc.uris - remove_these_uris
    puts "NEW LIST: #{link_doc.uris.inspect}"
    link_doc.save
    link_doc.class.get(link_doc['_id'])
  end
      
end
=begin
#This class will include the Office 2007 extension types when looking up MIME types.
#  TODO: Create this as its own class and include other MIME types that might have to be added
class MimeNew

  #Returns the mime type of a file
  #  MimeNew.for_ofc_x('a_new_word_doc.docx') 
  #  #=>  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  def self.for_ofc_x(fname)
    cont_type = nil
    old_ext = File.extname(fname)
    cont_type =case old_ext
      #New Office Formats
    when '.docx'
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    when '.dotx'
      "application/vnd.openxmlformats-officedocument.wordprocessingml.template"
    when '.pptx'
      "application/vnd.openxmlformats-officedocument.presentationml.presentation"
    when '.ppsx'
      "application/vnd.openxmlformats-officedocument.presentationml.slideshow"
    when '.potx'
      "application/vnd.openxmlformats-officedocument.presentationml.template"
    when '.xlsx'
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    when '.xltx'
      "application/vnd.openxmlformats-officedocument.spreadsheetml.template"
    else
      MIME::Types.type_for(fname).first.content_type
    end
  end
end
=end

#Module of helper functions for BufsInfoAttachment that performs manipulations on the
#file attachment structures and metadata

=begin
module BufsInfoAttachmentHelpers

  def self.sort_attachment_data(attachments)
    #-- 
    #TODO: Refactor obj_md to be called custom_md
    #++
    all_couch_attach_params = {}
    all_custom_attach_params = {}
    all_attach_data = {}
    attachments.each do |att_name, att_info|
      #att_info: 'data' => att data, 'md' => att metadata
      esc_att_name = BufsEscape.escape(att_name)
      att_params = {}
      obj_params = {}
      attach_data = nil
      att_info.each do |info, info_value|
        if info == 'data'
          attach_data = info_value
        elsif info == 'md'
          #md holds all file metadata (both couch and custom)
          split_metadata = self.split_attachment_metadata(info_value)
          att_params = split_metadata['att_md']
          obj_params = split_metadata['obj_md']
        end
      end
      all_couch_attach_params[esc_att_name] = att_params
      all_custom_attach_params[esc_att_name] = obj_params
      all_attach_data[esc_att_name] = attach_data
    end
    sorted =  {'data_by_name' => all_attach_data,
      'att_md_by_name' => all_couch_attach_params,
      'obj_md_by_name' => all_custom_attach_params}
    return sorted
  end

  #Escapes attachment names in a CouchDB compatible way
  def self.escape_names_in_attachments(unesc_attachments)
    escaped_attachments = {}
    unesc_attachments.each do |unesc_key, val|
      esc_key = BufsEscape.escape(unesc_key)
      escaped_attachments[esc_key] = val
    end
    return escaped_attachments
  end

  #Unescapes attachment names in a CouchDb compatible way
  def self.unescape_names_in_attachments(esc_attachments)
    unescaped_attachments = {}
    esc_attachments.each do |esc_key, val|
      unesc_key = CGI.unescape(esc_key)
      unescaped_attachments[unesc_key] = val
    end
    return unescaped_attachments
  end

  private

  #Takes the abstracted attachment data and splits it into
  #the data used by this class and the underlying CouchDB format
  def self.split_attachment_metadata(combined_metadata)
    split_metadata = {'obj_md' => {}, 'att_md' => {}}
    combined_metadata.each do |param, param_value|
      if BufsInfoAttachment::CouchDBAttachParams.include? param
        split_metadata['att_md'][param] = param_value
      else
        split_metadata['obj_md'][param] = param_value
      end
    end
    return split_metadata
  end

end


  #Converts from BufsInfoDoc attachment format to closer to the metal
  #couchrest/CouchDB attachment format.  The reason this is needed is because
  #CouchDB cannot
  #support custom metadata for attachments.  So custom metadata is held
  #in the BufsInfoAttachment document.  This document will also hold the
  #attachments and its built in metadata (such as content-type and modified
  #times
  # Attachment structure:
  # attachments =>{ attachment_1 => { 'data1' => raw attachment data1,
  #                                   'md1' => combined attachment metadata1 },
  #                 attachment_2 => { 'data2' => raw attachment data2,
  #                                   'md2' => combined attachment metadata2 }
  # }
  #

class BufsInfoAttachment < CouchRest::ExtendedDocument
  class << self; attr_accessor :name_space end
  #Used for identifying the database to bind to
  #TODO:  This needs to move to be a normal instance variable
  #in order to support multi-user operations
  @name_space = nil
  
  #CouchDB attachment metadata parameters supported by BufsInfoAttachment
  CouchDBAttachParams = ['content_type', 'stub']
  AttachmentID = "_attachments"

  #Setter for setting the CoucDB database
  #Referred to name space because it defines the name space in which the 
  #BUFS document categories are unique
  def self.set_name_space(name_space)
    @name_space = name_space
    use_database @name_space #binds doc to database
  end

  #Create an attachment for a particular BUFS document
  #FIXME: Updated from BufsInfoAttachment to support UserDB stuff, but BufsInfoAttachment not updated
  def self.create_attachment_package(bufs_info_doc, attachments)
    raise "No document provided for attachments" unless bufs_info_doc
    raise "No id found for the document" unless bufs_info_doc['_id']
    raise "No attachments provided for attaching" unless attachments
    #seperate attachment data from custom attachment metadata
    #this is necessary since couchdb can't put custom metadata with its attachments
    sorted_attachments = BufsInfoAttachmentHelpers.sort_attachment_data(attachments)
    uniq_id = bufs_info_doc['_id'] + BufsInfoDoc.attachment_base_id #"_att_temp_id" #AttachmentID #bufs_info_doc.class.attachment_base_id
    custom_metadata_doc_params = {'_id' => uniq_id, 'md_attachments' => sorted_attachments['obj_md_by_name']}
    doc = bufs_info_doc.class.user_attachClass.get(uniq_id)
    #doc = BufsInfoAttachment.get(uniq_id)
    raise IndexError, "Can't create new attachment document for #{self}. Document already exists in Database" if doc
    #p bufs_info_doc.class.user_attachClass.new({})
    doc = bufs_info_doc.class.user_attachClass.new(custom_metadata_doc_params)
    #doc = BufsInfoAttachment.new(custom_metadata_doc_parms)
    doc.save
    sorted_attachments['att_md_by_name'].each do |att_name, params|
      esc_att_name = BufsEscape.escape(att_name)
      doc.put_attachment(esc_att_name, sorted_attachments['data_by_name'][esc_att_name],params)
    end
    #return BufsInfoAttachment.get(uniq_id)
    return bufs_info_doc.class.user_attachClass.get(uniq_id)

  end

  #Update this objects attachment data
  def update_attachment_package(doc, new_attachments)
    doc.class.user_attachClass.update_attachment_package(self, new_attachments)
  end

#  def update_attachment_package(new_attachments)
#    BufsInfoAttachment.update_attachment_package(self['_id'], new_attachments)
#  end

  #Update the attachment data for a particular BUFS document
  #  Important Note: Currently existing data is only updated if new data has been modified more recently than the existing data.
  def self.update_attachment_package(att_doc, new_attachments)
    #att_doc = BufsInfoAttachment.get(att_doc_id)
    existing_attachments = att_doc.get_attachments
    most_recent_attachment = {}
    if existing_attachments
      new_attachments.each do |new_att_name, new_data|
	esc_new_att_name = BufsEscape.escape(new_att_name)
        working_doc = att_doc.class.get(att_doc['_id'])
        if existing_attachments.keys.include? esc_new_att_name
          #filename already exists as an attachment
	  fresh_attachment =self.find_most_recent_attachment(existing_attachments[esc_new_att_name], new_attachments[new_att_name]['md'])
          most_recent_attachment[esc_new_att_name] = fresh_attachment
          if most_recent_attachment[esc_new_att_name] != existing_attachments[esc_new_att_name]
            #update that file and metadata
            sorted_attachments = BufsInfoAttachmentHelpers.sort_attachment_data(esc_new_att_name => new_data)
            #update doc
            working_doc['md_attachments'] = working_doc['md_attachments'].merge(sorted_attachments['obj_md_by_name'])
            #update attachments
            working_doc.save
            #Add Couch attachment data
            att_data = sorted_attachments['data_by_name'][esc_new_att_name]
            att_md =  sorted_attachments['att_md_by_name'][esc_new_att_name]
            working_doc.put_attachment(esc_new_att_name, att_data,att_md)
            #puts "Database Version for that id(fnmame existed): #{BufsInfoAttachment.get(working_doc['_id']).inspect}"
          else
            #do anything here?
          end
        else #filename does not exist in attachment
          puts "Attachment Name not found in Attachment Document, adding #{esc_new_att_name}"
          sorted_attachments = BufsInfoAttachmentHelpers.sort_attachment_data(esc_new_att_name => new_data)
          #update doc
          working_doc['md_attachments'] = working_doc['md_attachments'].merge(sorted_attachments['obj_md_by_name'])
          #update attachments
          working_doc.save
          #Add Couch attachment data
          puts "Updating Native Attachments in Database"
          att_data = sorted_attachments['data_by_name'][esc_new_att_name]
          att_md =  sorted_attachments['att_md_by_name'][esc_new_att_name]
          working_doc.put_attachment(esc_new_att_name, att_data,att_md)
          #working_doc does not have attachment
          
        end
        #
      end
    end
    return att_doc.class.get(att_doc['_id'])
  end

  #retrieves document attachments for a particular document (given its id)
  def self.get_attachments(doc)
    #puts "Getting Attachments"
    #doc = BufsInfoAttachment.get(doc_id)
    #puts "BIA: #{doc.inspect}"
    return nil unless doc
    custom_md = doc['md_attachments']
    esc_couch_md = doc['_attachments']
    couch_md = BufsInfoAttachmentHelpers.unescape_names_in_attachments(esc_couch_md)
    #puts "Unescaped Couch Attachment: #{couch_md.inspect}"
    #puts "custom metadata: #{custom_md.inspect}"
    raise "data integrity error, attachment metadata inconsistency" if custom_md.keys.sort != couch_md.keys.sort
    (attachment_data = custom_md.dup).merge(couch_md) {|k,v_custom, v_couch| v_custom.merge(v_couch)}
  end

  #retrieves document attachments for this document
  def get_attachments
    BufsInfoAttachment.get_attachments(self)
  end


  private

  def self.find_most_recent_attachment(attachment_data1, attachment_data2)
    #puts "Finding most recent attachment"
    most_recent_attachment_data = nil
    if attachment_data1 && attachment_data2
      #puts "both attachmnents exist"
      #puts "attachments:"
      #p attachment_data1['file_modified']
      #p attachment_data2['file_modified']
      #p attachment_data2['file_modified']
      #p attachment_data2['file_modified']
      #p Time.parse(attachment_data1['file_modifed'])
      #p Time.parse(attachment_data2['file_modified'])
      if attachment_data1['file_modified'] >= attachment_data2['file_modified']
        #puts "attachment1 is the most recent: #{attachment_data1['file_modified']}"
        most_recent_attachment_data = attachment_data1
      else
        #puts "attachment2 is the most recent: #{attachment_data2['file_modified']}"
        most_recent_attachment_data = attachment_data2
      end
    else
      most_recent_attachment_data = attachment_data1 || attachment_data2
    end
    #puts "Returning most recent attachment"
    most_recent_attachment_data
  end

end
=end
