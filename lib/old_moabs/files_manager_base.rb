#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '../helpers/require_helper')

class FilesMgrInterfaceBase
  
  NotImpl = "Not implemented in base class"
  
  self.get_att_doc(node)
    #returns attachments
    #TODO: Slightly different implementations need to be reconciled
    raise NotImpl
  end
  
  def initialize(node_env, node_key)
    raise NotImpl
    #TODO: Slighty different implementations need to be reconciled
    @attachment_location = nil
  end
  
  def add_files(node, file_datas)
    raise NotImpl
    #add file information to file store
  end
  
  def add_raw_data(node, attach_name, content_type, raw_data, file_modified_at = nil)
    raise NotImpl
  end
  
  def subtract_files(node, file_basenames)
    #if file_basename == :all subtract all files
    # else subtract_some
    raise NotImpl
  end
  
  def get_raw_data(node, file_basename)
    raise NotImpl
  end
  
  def get_attachments_metadata(node)
    raise NotImpl
  end
  
  def list_files(node)
    raise NotImpl
  end
  
  private
  
  #need to reconcile subtrace some and all
  def subtract_some(node, basenames)
    raise NotImpl
  end
  
  def subtract_all(node)
    raise NotImpl
  end
end