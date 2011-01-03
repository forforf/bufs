#Bufs directory structure defined in lib/helpers/require_helpers'
require Bufs.midas 'bufs_data_structure'
require Bufs.glue '/mysql/mysql_files_mgr'
require Bufs.helpers 'hash_helpers'
require Bufs.helpers 'log_helper'

require 'json'
require 'dbi'

module MySqlEnv
    class << self; attr_accessor :dbh; end
    @@home_dir = ENV["HOME"]
    @@my_pw = File.open("#{@@home_dir}/.locker/tinkit_mysql"){|f| f.read}.strip

    self.dbh = DBI.connect("DBI:Mysql:tinkit:localhost", "tinkit", @@my_pw)
    
class GlueEnv
    
    @@log = BufsLog.set(self.name, :info)
    
    #table format
    # primary key - autogenerated integer, should not be visible outside of the db model
    # model_key - the actual key that will be used to store the data
    # version key - not sure if it will be used
    #namespace key - name to identify this is the mysql interface?
    #used to identify metadata for models (should be consistent across models)
    ModelKey = :my_id
    VersionKey = :_rev #derived from timestamp
    NamespaceKey = :mysql_namespace
    
    #MySql Primary Key ID
    #TODO, Don't set directly to constant, use accessor 
    PRIMARY_KEY ='__mysql_pk'    
    attr_accessor :user_id,
           :user_datastore_location,
			     :metadata_keys,
			     :required_instance_keys,
			     :required_save_keys,
			     :node_key,
			     :model_key,
			     :version_key,
			     :namespace_key,
			     :_files_mgr_class,
           :views,
			     :model_save_params,
           :moab_data,
           #accessors specific to this persitence model
           :dbh  #database handler #spec uses
           :file_mgr_table #identifies the table the FileMgr Class should use
           

       

  def initialize(persist_env, data_model_bindings)
    #host = "https://sdb.amazonaws.com/"  (not provided by user)
    @dbh = MySqlEnv.dbh

    mysql_env = persist_env[:env]
    #TODO: validations on format

    @user_id = mysql_env[:user_id]
    #use namespace generator?
    domain_table_name = "#{mysql_env[:path]}__#{@user_id}"
    #data_model_bindings from NodeElementOperations
    key_fields = data_model_bindings[:key_fields] 
    initial_views_data = data_model_bindings[:views]
    
    @required_instance_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredInstanceKeys
    @required_save_keys = key_fields[:required_keys] #DataStructureModels::Bufs::RequiredSaveKeys
    @node_key = key_fields[:primary_key] #DataStructureModels::Bufs::NodeKey
    
    @version_key = VersionKey  
    @model_key = ModelKey
    @namespace_key = NamespaceKey
    @metadata_keys = [@version_key, @model_key, @namespace_key] 
    
    initial_table_fields = @required_instance_keys + @required_save_keys + @metadata_keys
    initial_table_fields.compact!
    initial_table_fields.uniq!
    #may want to verify a flat array
    node_identifying_keys = [@model_key] #, @version_key]
    
    @user_datastore_location = use_table!(initial_table_fields, node_identifying_keys, domain_table_name)

    @model_save_params = {:dbh => dbh, :table => user_datastore_location, :node_key => @node_key}
    @_files_mgr_class = MySqlInterface::FilesMgr
    @file_mgr_table = create_file_mgr_table
    #@views = "temp"
      
  end#def
    
  def save(new_data)
    #raise "Required key missing" unless @model_save_params[:required_save_key] = @required_save_key
    orig_cols = get_existing_columns(@user_datastore_location)
    new_cols = new_data.keys
    table_name = reconcile_table(@user_datastore_location, orig_cols, new_cols)
    esc_col_names = new_data.keys.map{|k| "`#{k}`"}.join(",")
    json_values = new_data.values.map{|v| "'#{v.to_json}'"}.join(",")
    
    #Need to update a bit when moved to tinkit (formerly bufs) to account for revs
    sql = "REPLACE INTO `#{table_name}` (#{esc_col_names}) VALUEs (#{json_values})"
    puts "SAVE SQL: #{sql}"
    @dbh.do(sql)
  end
    
  def get(id)
    #get all records with the given id and return the one with the highest (internal) primary key
    #because tinkit _rev has no ordering properties ... this may be a bug eventually, ok so far
    sql = "SELECT * FROM `#{@user_datastore_location}` WHERE `#{@model_key}` = '#{id.to_json}'"
    sth = @dbh.prepare(sql)
    rtn = []
    sth.execute
    while row=sth.fetch do
      rtn << row.to_h
    end
    #rtn
    sth.finish
    puts "GOT: #{rtn.inspect}"
    rtn_raw = rtn.first || {} #remember in production to sort on internal primary id
    rtnj = {}
    rtn_raw.delete(PRIMARY_KEY)
    rtn_raw.each do |k,v|
          rtnj[k] = jparse(v)
    end
    rtn_h = HashKeys.str_to_sym(rtnj)
    puts "RTN: #{rtn_h.inspect}"
    return rtn_h
  end
  
  def destroy_node(model_metadata)
    node_id = model_metadata[@model_key]
    node_rev = model_metadata[@version_key]
    sql = "DELETE FROM `#{@user_datastore_location}` 
         WHERE `#{@model_key}` = '#{node_id.to_json}'"
    puts "DELETE:  #{sql}"
    @dbh.do(sql)
  end
  
  def query_all
    sql = "SELECT * FROM `#{@user_datastore_location}`"
    sth = @dbh.prepare(sql)
    rtn = []
    rtn_raw_rows = []
    sth.execute
    while row=sth.fetch do
      rtn_raw_rows << row.to_h
    end
    #rtn
    sth.finish
    rtnj = {}
    rtn_raw_rows.each do |rtn_raw|
      rtn_raw.delete(PRIMARY_KEY)
      rtn_raw.each do |k,v|
          rtnj[k] = jparse(v)
      end
      rtn_h = HashKeys.str_to_sym(rtnj)
      rtn << rtn_h
    end
    return rtn
  end
  
  def destroy_bulk(records)
    record_key_data = records.map{|r| r[@model_key].to_json}
    #record_rev = ?
    record_key_data_sql = record_key_data.join("', '")
    sql = "DELETE FROM `#{@user_datastore_location}` 
        WHERE `#{@model_key}` IN ('#{record_key_data_sql}')"
    puts "DELETE:  #{sql}"
    @dbh.do(sql)
  end
  
  def use_table!(fields, keys, table_name)
    #return [fields, keys, table_name]
    table_name = find_table!(fields, keys, table_name)
    raise "No table could be found or created" unless table_name
    column_names = get_existing_columns(table_name)
    fields_str = fields.map{|f| f.to_s}
    unless fields_str.sort == column_names.sort
      puts "Warning Fields Dont Match, Adding unmatched fields to table"
      p fields_str.sort
      p column_names.sort
      #table has changed, reconcile them
      table_name = reconcile_table(table_name, column_names, fields_str)
    end
    return table_name
  end
  
  def find_table!(fields, keys, table_name)
    rtn_val = table_name
    tables = @dbh.tables
    unless tables.include? table_name
      create_table(fields, keys, table_name)
    end    
    rtn_val
  end
  
  def create_table(fields, keys, table_name)
    rtn_val = nil
    field_str_list = []
    fields.each do |field|
      sql_str = "`#{field}` VARCHAR(255) NOT NULL,"
      field_str_list << sql_str
    end
    field_str  = field_str_list.join("\n")
    #change this for tinkit
    mk_str = "UNIQUE KEY `_uniq_idx`(`#{keys.join("`, `")}`)"
    sql = "CREATE TABLE `#{table_name}` (
           `#{PRIMARY_KEY}` INT NOT NULL AUTO_INCREMENT,
           #{field_str}
           PRIMARY KEY ( `#{PRIMARY_KEY}` ),
           #{mk_str} )"
    @dbh.do(sql)
    puts "Created Table sql: #{sql}"
    rtn_val = table_name if @dbh.tables.include? table_name
  end
  
  def get_existing_columns(table_name)
    existing_columns = []
    sql = "DESCRIBE #{table_name}"
    sth = @dbh.prepare(sql)
    sth.execute
    sth.each do |row|
      fld = row.to_h['Field']
      existing_columns << fld if fld
    end
    #for select queries this would work sth.column_names (but less efficient)
    sth.finish
    return existing_columns
  end
  
  def reconcile_table(table_name, orig_cols, new_cols, opts = {} )
    opts[:allow_remove] = opts[:allow_remove] || nil  #useless code but shows options
    #remove_cols = []
    current_cols = get_existing_columns(table_name).map{|col| col.to_sym}
    orig_cols = orig_cols.map{|col| col.to_sym}
    new_cols = new_cols.map{|col| col.to_sym}
    #puts "current: #{current_cols.inspect}"
    add_cols = new_cols
    add_cols = new_cols - current_cols - [PRIMARY_KEY]
    add_cols.delete_if{|col| col =~ /^XXXX_/ }
    remove_cols = current_cols - new_cols - [PRIMARY_KEY]
    remove_cols.delete_if{|col| col !=~ /^XXXX_/ }

    puts "orig cols: #{orig_cols.inspect}"
    puts "new cols: #{new_cols.inspect}"
    puts "Remove: #{remove_cols.inspect}"
    puts "Add: #{add_cols.inspect}"
       #STOP_HERE
    if opts[:allow_remove] 
      remove_columns(table_name, remove_cols) unless remove_cols.empty?
    end
    add_columns(table_name, add_cols) unless add_cols.empty?
    return table_name
  end

  def add_columns(table_name, add_cols)
    add_list = []
    add_cols.each do |col_name|
      add_list << "ADD `#{col_name}` VARCHAR (255)"
    end
    add_sql= add_list.join(", ")
    sql = "ALTER TABLE `#{table_name}` #{add_sql}"
    p sql
    sth = @dbh.prepare(sql)
    sth.execute
    sth.finish
  end
  
  def remove_columns(table_name, remove_cols)
    remove_list = []
    existing_cols = get_existing_columns(table_name)
    existing_cols.each do |curr_col_name|
      #existing_cols.each do |ex_col|
      expired_col_regexp = /^XXXX_XXXX_/
        if curr_col_name.match expired_col_regexp
          puts "#{curr_col_name} matched #{expired_col_regexp}"
          #iterating in ruby makes cleaner ruby code, but not as efficient
          sql = "ALTER TABLE #{table_name} DROP #{curr_col_name}"
          sth = @dbh.prepare(sql)
          sth.execute
          sth.finish
        end#if
    end
      #end#each existing_cols
    removed_cols = existing_cols - get_existing_columns(table_name)
    remove_cols = remove_cols - removed_cols 
    remove_cols.each do |rmv_col_name|
      remove_list << "CHANGE `#{rmv_col_name}` `XXXX_#{rmv_col_name}` VARCHAR(255)"
    end#each remove_cols
    existing_cols = get_existing_columns(table_name)
    remove_sql= remove_list.join(", ")
    sql = "ALTER TABLE `#{table_name}` #{remove_sql}"
    p sql
    sth = @dbh.prepare(sql)
    sth.execute
    sth.finish
  end

  def create_file_mgr_table
    primary_key = '__pkid-file'
    file_table_name_postfix = "files"
    #Create the table to store files when class is loaded
    #Add modified_at to the UNIQUE KEY to keep versions
    
    file_table_name = "#{@user_datastore_location.to_s}_#{file_table_name_postfix}"
    sql = "CREATE TABLE IF NOT EXISTS `#{file_table_name}` (
          `#{primary_key}` INT NOT NULL AUTO_INCREMENT,
          node_name VARCHAR(255),
          basename VARCHAR(255) NOT NULL,
          content_type VARCHAR(255),
          modified_at VARCHAR(255),
          raw_content LONGBLOB,
          PRIMARY KEY (`#{primary_key}`),
          UNIQUE KEY (node_name, basename) )"

    @dbh.do(sql) 
    return file_table_name    
  end#def
  
def jparse(str)
  return JSON.parse(str) if str =~ /\A\s*[{\[]/
  JSON.parse("[#{str}]")[0]
end
  
  
end#class
end#module
