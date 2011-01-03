require 'dbi'
require 'json'

require Bufs.helpers 'mime_types_new'

module MySqlInterface
  class FilesMgr

    class << self; attr_accessor :dbh; end
    @@home_dir = ENV["HOME"]
    @@my_pw = File.open("#{@@home_dir}/.locker/tinkit_mysql"){|f| f.read}.strip
    
    @dbh = DBI.connect("DBI:Mysql:tinkit:localhost", "tinkit", @@my_pw)

  #Table Structure
  MySqlPrimaryKey = '__pkid-file'
  NodeName = 'node_name'
  Basename = 'basename'
  ContentType = 'content_type'
  ModifiedAt = 'modified_at'
  RawContent = 'raw_content'
  FileTableKeys = [MySqlPrimaryKey, NodeName, Basename, ContentType, ModifiedAt, RawContent]
  
  
  attr_accessor :file_table_name
  
  def initialize(glue_env, node_key_value)
    @dbh = self.class.dbh
    @file_table_name = glue_env.file_table_name
  end
  
  def add_files(node, file_datas)
    filenames = []
    file_datas.each do |file_data|
      filenames << file_data[:src_filename]
    end
    
    filenames.each do |filename|
      basename = File.basename(filename)
      #derive content_type
      content_type = MimeNew.for_ofc_x(basename)
      #derive modified time from file
      modified_at = File.mtime(filename)
      rb = 'rb' #lazily avoiding escape issues
      node_name = node.__send__(node.my_GlueEnv.model_key.to_sym)
      fields_str =   "`#{NodeName}`, `#{Basename}`, `#{ContentType}`, `#{ModifiedAt}`, `#{RawContent}`"
      prep_sql = "REPLACE INTO `#{@file_table_name}` (#{fields_str})
      VALUES ( ?, ?, ?, ?, ?)"
      sth = @dbh.prepare(prep_sql)
      values_input = [node_name, basename, content_type, modified_at, File.open(filename, rb){|f| f.read}]
      sth.execute(*values_input)
    end
  end

  def get_raw_data(node, file_basename)
    model_key = node.my_GlueEnv.model_key
    sql = "SELECT `#{RawContent}` FROM `#{@file_table_name}`
     WHERE `#{NodeName}` = '#{node.__send__(model_key.to_sym)}'
     AND `#{Basename}` = '#{file_basename}'"
    #puts "Raw Data SQL: #{sql}"
    sth = @dbh.prepare(sql)
    rtn = []
    sth.execute
    while row=sth.fetch do
      rtn << row.to_h
    end
    #rtn
    sth.finish
    rtn_val = rtn.first || {} #remember in production to sort on internal primary id (once delete revisions works)
    rtn_val['raw_content'] 
  end

    #todo change name to get_files_metadata
  def get_attachments_metadata(node)
    files_md = {}
    md_list = FileTableKeys
    md_list.delete(RawContent)
    md_fields = md_list.join("`, `")
      
    model_key = node.my_GlueEnv.model_key
    sql = "SELECT `#{md_fields}` FROM `#{@file_table_name}`
     WHERE `#{NodeName}` = '#{node.__send__(model_key.to_sym)}'"
    sth = @dbh.prepare(sql)
    rtn = []
    sth.execute
    while row=sth.fetch do
      rtn << row.to_h
    end
    #rtn
    sth.finish
    objects = rtn
    objects.each do |object|
      obj_md = object 
      #speputs "Obj It: #{obj_md.inspect}"
      obj_md_file_modified = obj_md["modified_at"]
      obj_md_content_type = obj_md["content_type"]
      new_md = {:content_type => obj_md_content_type, :file_modified => obj_md_file_modified}
      new_md.merge(obj_md)  #where does the original metadata go?
      #p new_md.keys
      files_md[obj_md["basename"]] = new_md
      #puts "Obj METADATA: #{new_md.inspect}"
    end
    files_md
  end#def
    
  
end
end
    