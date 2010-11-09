#Copyright (C) 2010  David Martin
#
#David Martin mailto:dmarti21@gmail.com
  

require 'mime/types'

#This class will include the Office 2007 extension types when looking up MIME types.
class MimeNew

  DefaultUnknownContentType = "application/octet-stream"
  #Returns the mime type of a file
  #  MimeNew.for_ofc_x('a_new_word_doc.docx') 
  #  #=>  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  def self.for_ofc_x(fname)
    cont_type = nil
    old_ext = File.extname(fname)
    cont_type =case old_ext
      #New Office Formats
    when '.docx'
      ["application/vnd.openxmlformats-officedocument.wordprocessingml.document"]
    when '.dotx'
      ["application/vnd.openxmlformats-officedocument.wordprocessingml.template"]
    when '.pptx'
      ["application/vnd.openxmlformats-officedocument.presentationml.presentation"]
    when '.ppsx'
      ["application/vnd.openxmlformats-officedocument.presentationml.slideshow"]
    when '.potx'
      ["application/vnd.openxmlformats-officedocument.presentationml.template"]
    when '.xlsx'
      ["application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"]
    when '.xltx'
      ["application/vnd.openxmlformats-officedocument.spreadsheetml.template"]
    else
      self.other_content_types(fname)
    end#case
    cont_type = [cont_type].flatten.first
    #puts "Content Type returned: #{cont_type.inspect}"
    return cont_type
  end# def
  
  def self.other_content_types(fname)
    std_type = MIME::Types.type_for(fname).first
    rtn = if std_type
      std_type.content_type
    else
      DefaultUnknownContentType
    end
    return rtn
  end#def
end

