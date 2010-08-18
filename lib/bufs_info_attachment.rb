#= bufs_info_attachment.rb - Support for handling CouchDB attachments in the 'BUFS' (Bottom Up File System) Format
#
#Copyright (C) 2010  David Martin
#
#David Martin mailto:dmarti21@gmail.com
  

#require 'mime/types'
require 'cgi'

require File.dirname(__FILE__) + '/bufs_escape'
require File.dirname(__FILE__) + '/helpers/mime_types_new'
require 'couchrest'

#Module of helper functions for BufsInfoAttachment that performs manipulations on the
#file attachment structures and metadata

module BufsInfoAttachmentHelpers

  #Attachment data format: attachment_name => attachment info
  #attachment info format: { 'data' => attachment data, 'md' => attachment metadata }
  #attachment data is sorted into the data and metadata CouchDB attachments can handle natively
  #and the additional metadata that CouchDB attachments do not handle (boo, hiss)
  # 
  # Usage Example:
  #   BufsInfoAttachmentHelpers.sort_attachment_data(attachments)
  #   #=> { 'data_by_name' => { attachment_1 => raw_attachment_data1,
  #                           attachment_2 => raw_attachment_data2 }.
  #       'att_md_by_name' => { attachment_1 => CouchDB metadata fields1,
  #                             attachment_2 => CouchDB metadata fields2}
  #       'cust_md_by_name' => { attachment_1 => Custom metadata fields1,
  #                             attachment_2 => Custom metadata fields2}
  #      }
  def self.sort_attachment_data(attachments)
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
          obj_params = split_metadata['cust_md']
        end
      end
      all_couch_attach_params[esc_att_name] = att_params
      all_custom_attach_params[esc_att_name] = obj_params
      all_attach_data[esc_att_name] = attach_data
    end
    sorted =  {'data_by_name' => all_attach_data,
      'att_md_by_name' => all_couch_attach_params,
      'cust_md_by_name' => all_custom_attach_params}
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
    split_metadata = {'cust_md' => {}, 'att_md' => {}}
    combined_metadata.each do |param, param_value|
      if BufsInfoAttachment::CouchDBAttachParams.include? param
        split_metadata['att_md'][param] = param_value
      else
        split_metadata['cust_md'][param] = param_value
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
  
  #CouchDB attachment metadata parameters supported by BufsInfoAttachment
  CouchDBAttachParams = ['content_type', 'stub']
  AttachmentID = "_attachments"

  #create the attachment document id to be used
  def self.uniq_att_doc_id(bufs_info_doc)
    uniq_id = bufs_info_doc.model_metadata['_id'] + bufs_info_doc.class.attachment_base_id 
  end

  def self.add_attachment_package(bufs_info_doc, attachments)
    raise "No document provided for attachments" unless bufs_info_doc
    raise "No id found for the document" unless bufs_info_doc.model_metadata['_id']
    raise "No attachments provided for attaching" unless attachments
    att_doc_id = self.uniq_att_doc_id(bufs_info_doc)
    att_doc = bufs_info_doc.class.user_attachClass.get(att_doc_id)
    rtn = if att_doc
      #TODO: This call should be able to be simplified in the new architecture
      bufs_info_doc.class.user_attachClass.update_attachment_package(att_doc, attachments)
    else
      #TODO: simplify call
      bufs_info_doc.class.user_attachClass.create_attachment_package(att_doc_id, bufs_info_doc, attachments)
    end
    return rtn
  end

   #Create an attachment for a particular BUFS document
  #TODO: See if bufs_info_doc can be factored out of this method call
  def self.create_attachment_package(att_doc_id, bufs_info_doc, attachments)
    #raise "No document provided for attachments" unless bufs_info_doc
    #raise "No id found for the document" unless bufs_info_doc.model_metadata['_id']
    #raise "No attachments provided for attaching" unless attachments
    #separate attachment data from custom attachment metadata
    #this is necessary since couchdb can't put custom metadata with its attachments
    sorted_attachments = BufsInfoAttachmentHelpers.sort_attachment_data(attachments)
    #att_doc_id  = self.uniq_att_doc_id(bufs_info_doc)
    custom_metadata_doc_params = {'_id' => att_doc_id, 'md_attachments' => sorted_attachments['cust_md_by_name']}
    att_doc = bufs_info_doc.class.user_attachClass.get(att_doc_id)
    raise IndexError, "Can't create new attachment document for #{self}. Document already exists in Database" if att_doc
    att_doc = bufs_info_doc.class.user_attachClass.new(custom_metadata_doc_params)
    att_doc.save
    sorted_attachments['att_md_by_name'].each do |att_name, params|
      esc_att_name = BufsEscape.escape(att_name)
      att_doc.put_attachment(esc_att_name, sorted_attachments['data_by_name'][esc_att_name],params)
    end
    #returns the updated document from the database
    return bufs_info_doc.class.user_attachClass.get(att_doc_id)
  end

  #Update the attachment data of the attachment document
  #Note: The attachment is decoupled from the associated bufs document, requiring the bufs document
  #to explicitly be provided.
  def update_attachment_package(bufs_doc, new_attachments)
    bufs_doc.class.user_attachClass.update_attachment_package(self, new_attachments)
  end


  #Update the attachment data for a particular BUFS document
  #  Important Note: Currently existing data is only updated if new data has been modified more recently than the existing data.
  def self.update_attachment_package(att_doc, new_attachments)
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
            working_doc['md_attachments'] = working_doc['md_attachments'].merge(sorted_attachments['cust_md_by_name'])
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
          working_doc['md_attachments'] = working_doc['md_attachments'].merge(sorted_attachments['cust_md_by_name'])
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

  #retrieves document attachments for a particular document 
  def self.get_attachments(att_doc)
    return nil unless att_doc
    custom_md = att_doc['md_attachments']
    esc_couch_md = att_doc['_attachments']
    couch_md = BufsInfoAttachmentHelpers.unescape_names_in_attachments(esc_couch_md)
    raise "data integrity error, attachment metadata inconsistency" if custom_md.keys.sort != couch_md.keys.sort
    (attachment_data = custom_md.dup).merge(couch_md) {|k,v_custom, v_couch| v_custom.merge(v_couch)}
  end

  #retrieves document attachments for this document
  def get_attachments
    self.class.get_attachments(self) #BufsInfoAttachment.get_attachments(self)
  end

  def remove_attachment(attachment_names)
    attachment_names = [attachment_names].flatten
    attachment_names.each do |att_name|
      att_name = BufsEscape.escape(att_name)    
      self.delete_attachment(att_name)
      self['md_attachments'].delete(att_name)
    end
    resp = self.save
    raise "Remove Attachment Operation Failed with response: #{resp.inspect}" unless resp == true
    self
  end

  private

  def self.find_most_recent_attachment(attachment_data1, attachment_data2)
    #puts "Finding most recent attachment"
    most_recent_attachment_data = nil
    if attachment_data1 && attachment_data2
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

  def delete_attachments(attachment_name)
  end
end
