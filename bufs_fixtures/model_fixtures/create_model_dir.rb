require 'fileutils'
require 'json'

class DataModel
  NodeDataFileName = ".node_data.json"
  DataModelSourceFile = "default_data_model.json"
  
 
  def initialize(options = {})
    @read_path = options[:read_path] || File.join(Dir.pwd, DataModelSourceFile)
    @write_path = options[:write_path] || File.join(Dir.pwd, "data_model.json")
    FileUtils.mkdir(@read_path) unless File.exists?(@read_path)
    FileUtils.mkdir(@write_path) unless File.exists?(@write_path)
    data_model_json = File.open(@read_path, 'r') {|f| f.read}
    @data_model = JSON.parse(data_model_json)
    make_model(@data_model)
  end

  
  def make_model(data_model)
    data_model.each do |basename, contents|
      model_entry_dir = File.join(@write_path, basename)
      FileUtils.mkdir(model_entry_dir)
      contents.each do |label, content|
        case label
        when "node_data"
          write_node_data(model_entry_dir, content)
        when "attachments"
          write_attachment(model_entry_dir, content)
        end
      end
    end
  end

  def write_node_data(dir, content)
    path = File.join(dir, NodeDataFileName)
    File.open(path, 'w') { |f| f.write content.to_json }   
  end

  def write_attachment(dir, attachments)
    attachments.each do |attachment_data|
      raise "Unable to write file data, no data provided" unless attachment_data
      raise "Unable to write file data, no file name provided" unless attachment_data["filename"]
      fname = File.join(dir, attachment_data["filename"])
      file_data = attachment_data["data"]
      #file_mod_time = attachment_data["mod_time"]
      File.open(fname, 'w') {|f| f.write attachment_data}
    end
  end
end 

read_from = File.join("/home/bufs/bufs/bufs_fixtures/model_fixtures/",DataModel::DataModelSourceFile)
write_to = "/home/bufs/bufs/sandbox_for_specs/bufs_view_builder_spec/model"
FileUtils.rm_rf write_to
DataModel.new(:read_path => read_from, :write_path => write_to)
