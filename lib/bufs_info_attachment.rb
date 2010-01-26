

require 'mime/types'
require 'cgi'

class MimeNew

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

module BufsInfoAttachmentHelpers
  def self.sort_attachment_data(attachments)
    #puts "Entered SIA Helpers Sort Attachment Data"
    #sorted_data = {att_name1 => data, 'att_md' => att_md, 'obj_md' => obj_md, att_name2 => ...}
    all_couch_attach_params = {}
    all_custom_attach_params = {}
    all_attach_data = {}
    attachments.each do |att_name, att_info|
      #att_info: 'data' => att data, 'md' => att metadata
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
      all_couch_attach_params[att_name] = att_params
      all_custom_attach_params[att_name] = obj_params
      all_attach_data[att_name] = attach_data
    end
    sorted =  {'data_by_name' => all_attach_data,
      'att_md_by_name' => all_couch_attach_params,
      'obj_md_by_name' => all_custom_attach_params}
    return sorted
  end

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

  def self.escape_names_in_attachments(unesc_attachments)
    escaped_attachments = {}
    unesc_attachments.each do |unesc_key, val|
      esc_key = CGI.escape(unesc_key)
      escaped_attachments[esc_key] = val
    end
    return escaped_attachments
  end

    def self.unescape_names_in_attachments(esc_attachments)
    unescaped_attachments = {}
    esc_attachments.each do |esc_key, val|
      unesc_key = CGI.unescape(esc_key)
      unescaped_attachments[unesc_key] = val
    end
    return unescaped_attachments
  end
end

class BufsInfoAttachment < CouchRest::ExtendedDocument
  class << self; attr_accessor :name_space end
  @name_space = nil #CouchDB

  #use_database CouchDB
  
  CouchDBAttachParams = ['content_type', 'stub']

  def self.set_name_space(name_space)
    @name_space = name_space
    use_database @name_space
  end

  #attachment id set in BufsInfoDoc
  #def self.get_attachment_id(doc_id)
  #  doc_id + BufsInfoDoc.attachment_base_id
  #end

  def self.create_attachment_package(bufs_info_doc_id, attachments)
    #attachments = unesc_attachments # BufsInfoAttachmentHelpers.escape_names_in_attachments(unesc_attachments)
    #puts "Entered BIA Create Attachment Package"
    #attachments = { attachment name => { 'data => attachment data, 'md' = > md_params }
    #seperate attachment data from db data
    #this is necessary since couchdb can't put custom metadata with its attachments
    sorted_attachments = BufsInfoAttachmentHelpers.sort_attachment_data(attachments)
    #attach_name_list = attachments.keys
    #uniq_id = attachments.keys.join #TODO: Use a hash function to get around escaping issues
    uniq_id = bufs_info_doc_id + BufsInfoDoc.attachment_base_id
    init_params = {'_id' => uniq_id, 'md_attachments' => sorted_attachments['obj_md_by_name']}
    doc = BufsInfoAttachment.get(uniq_id)
    raise IndexError, "Can't create #{self}. Document already exists in Database" if doc
    doc = BufsInfoAttachment.new(init_params)
    doc.save
    sorted_attachments['att_md_by_name'].each do |att_name, params|
      doc.put_attachment(att_name, sorted_attachments['data_by_name'][att_name],params)
    end
    return BufsInfoAttachment.get(uniq_id)
  end

  def update_attachment_package(new_attachments)
    #puts "update_attachment_package instance method"
    #p new_attachments
    #p self['_id']
    #puts"---"
    BufsInfoAttachment.update_attachment_package(self['_id'], new_attachments)
  end

  def self.update_attachment_package(att_doc_id, unesc_attachments)
    new_attachments = unesc_attachments #BufsInfoAttachmentHelpers.escape_names_in_attachments(unesc_attachments)
    #puts "update_attachment_package class method"
    #p att_doc_id
    #puts "New Attachments: #{new_attachments.inspect}"
    att_doc = BufsInfoAttachment.get(att_doc_id)

    existing_attachments = att_doc.get_attachments
    #puts "Got Existing Attachments"
    most_recent_attachment = {}
    #puts "Checking Existing Attachments"
    if existing_attachments
      #p new_attachments
      new_attachments.each do |new_att_name, new_data|
        working_doc = BufsInfoAttachment.get(att_doc_id)
        #puts "WORKING DOC FOR ATTACHMENT CHECKING: #{working_doc.inspect}"
        #puts "Checking to see if #{new_att_name} exists in Attachment Document"
        if existing_attachments.keys.include? new_att_name
          #puts "Attachment Name Found"
          #filename already exists as an attachment
          #puts "Compare Attachments for #{new_att_name}:"
          #p existing_attachments[new_att_name]
          #p new_attachments[new_att_name]
          most_recent_attachment[new_att_name] = self.find_most_recent_attachment(existing_attachments[new_att_name], new_attachments[new_att_name]['md'])
          if most_recent_attachment[new_att_name] != existing_attachments[new_att_name]
            #update that file and metadata
            sorted_attachments = BufsInfoAttachmentHelpers.sort_attachment_data(new_att_name => new_data)
            #update doc
            working_doc['md_attachments'] = working_doc['md_attachments'].merge(sorted_attachments['obj_md_by_name'])
            #update attachments
            working_doc.save

            #puts "Most Recent Att Doc after saving: #{working_doc.inspect}"
            #Add Couch attachment data
            att_data = sorted_attachments['data_by_name'][new_att_name]
            att_md =  sorted_attachments['att_md_by_name'][new_att_name]
            working_doc.put_attachment(new_att_name, att_data,att_md)
            #puts "Database Version for that id(fnmame existed): #{BufsInfoAttachment.get(working_doc['_id']).inspect}"
          else
            #do anything here?
          end
        else #filename does not exist in attachment
          puts "Attachment Name not found in Attachment Document, adding #{new_att_name}"
          #current_doc = BufsInfoAttachment.get(att_doc_id)
          sorted_attachments = BufsInfoAttachmentHelpers.sort_attachment_data(new_att_name => new_data)
          #update doc
          working_doc['md_attachments'] = working_doc['md_attachments'].merge(sorted_attachments['obj_md_by_name'])
          #update attachments
          working_doc.save
            
          #puts "Att Doc after saving: #{att_doc.inspect}"
          #Add Couch attachment data
          puts "Updating Native Attachments in Database"
          att_data = sorted_attachments['data_by_name'][new_att_name]
          att_md =  sorted_attachments['att_md_by_name'][new_att_name]
          #p new_att_name
          #p att_data
          #p att_md
          working_doc.put_attachment(new_att_name, att_data,att_md)
          #working_doc does not have attachment
          
          #puts "Database Version for that id: #{BufsInfoAttachment.get(att_doc['_id']).inspect}"
        end
        #
      end
    end
    #puts "finished updating attachments"
    return BufsInfoAttachment.get(att_doc['_id'])
  end





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



  def self.get_attachments(doc_id)
    #puts "Getting Attachments"
    doc = BufsInfoAttachment.get(doc_id)
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

  def get_attachments
    BufsInfoAttachment.get_attachments(self['_id'])
  end

end
