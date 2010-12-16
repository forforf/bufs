DirEnvHelpers = File.dirname(__FILE__)
DirBaseEnvHelpers = File.join(DirEnvHelpers, '../../')
DirFixEnvHelpers = File.join(DirBaseEnvHelpers, 'bufs_fixtures/bufs_fixtures')

#include fixtures
require DirFixEnvHelpers

require 'couchrest'
node_db_name = "http://bufs.younghawk.org:5984/bufs_test_spec/"
CouchDB = BufsFixtures::CouchDB #CouchRest.database!(node_db_name)
CouchDB.compact!
CouchDB2 = BufsFixtures::CouchDB2
CouchDB2.compact!
FileSystem1 = "/home/bufs/bufs/sandbox_for_specs/file_system_specs/group1"
FileSystem2 = "/home/bufs/bufs/sandbox_for_specs/file_system_specs/group2"

require File.join(DirBaseEnvHelpers, 'lib/bufs_node_factory')

module UserNodeSpecHelpers
  BufsNodeLibs = [File.join(DirBaseEnvHelpers,'lib/glue_envs/bufs_couchrest_glue_env')]
  BufsNodeIncludes = [:CouchRestEnv]
  BufsFileLibs = [File.join(DirBaseEnvHelpers, 'lib/glue_envs/bufs_filesystem_glue_env')]
  BufsFileIncludes = [:FileSystemEnv]
end

module NodeHelper
  def self.env_builder(model_name, node_class_id, user_id, path, host = nil)
        #binding data (note this occurs in two different places in the env)
    
    key_fields = {:required_keys => [:my_category],
                         :primary_key => :my_category }
    #data model
    field_op_set ={:my_category => :static_ops,
                             :parent_categories => :list_ops,
                             :links => :replace_ops }
    #op_set_mod => <Using default definitions>
    
    data_model = {:field_op_set => field_op_set, :key_fields => key_fields}
    
    #persistence layer model
    pmodel_env = { :host => host,
                          :path => path,
                          :user_id => user_id}
    persist_model = {:name => model_name, :env => pmodel_env, :key_fields => key_fields}
    
    #final env model
    env = { :node_class_id => node_class_id,
                :data_model => data_model,
                :persist_model => persist_model }
  end
end
#for testing CouchRest model
module CouchRestNodeHelpers

  def self.env_builder(node_class_id, db, db_user_id)
    raise "Don't Use this to build environments anymore"
=begin
      node_env = Hash[ node_class_id =>
                      Hash[ :requires => UserNodeSpecHelpers::BufsNodeLibs,
                            #:includes => UserNodeSpecHelpers::BufsNodeIncludes,
                            :includes => {:field_op_set => {:my_category => :static_ops,
                                                                            :parent_categories => :list_ops,
                                                                            :links => :replace_ops } },
                            :glue_name => "BufsCouchRestEnv",
                            :class_env =>
                            Hash[ :couchrest_env =>
                                  Hash[ :host => db.host,
                                        :path => db.uri,
                                        :user_id => db_user_id
                                      ]
                                ]
                          ]
                    ]
  end
=end
  end


end

module FileSystemNodeHelpers
  def self.env_builder(node_class_id, root_path, fs_user_id)
    raise "Don't Use this to build environments anymore"
=begin
      node_env = Hash[ node_class_id =>
                      Hash[ :requires => UserNodeSpecHelpers::BufsFileLibs,
                            #:includes => UserNodeSpecHelpers::BufsFileIncludes,
                            :includes => {:field_op_set => {:my_category => :static_ops,
                                                                            :parent_categories => :list_ops,
                                                                            :links => :replace_ops } },
                            :glue_name => "BufsFileSystemEnv",
                            :class_env =>
                            Hash[ :filesystem_env =>
                                  Hash[ :path => root_path,
                                        :user_id => fs_user_id
                                      ]
                                ]
                          ]
                    ]
  end
=end
 end   
end

module NodeHelpers
  DefaultNodeParams = {:my_category => 'default',
                      :parent_categories => ['default_parent'],
                      :description => 'default description'}

  def get_default_params
    DefaultNodeParams.dup #to avoid a couchrest weirdness don't use the params directly
  end

  def make_doc_no_attachment(user_class, override_defaults={})
    init_params = get_default_params.merge(override_defaults)
    return user_class.new(init_params)
  end

  def make_doc_w_attach_from_file(user_class, att_fname, override_defaults={})
    test_filename = att_fname
    test_basename = File.basename(test_filename)
    raise "can't find file #{test_filename.inspect}" unless File.exists?(test_filename)
    new_doc = make_doc_no_attachment(user_class, override_defaults)
    new_doc.__save #doc must be saved before we can attach
    file_data = {:src_filename => test_filename}
    new_doc.files_add(file_data)
    #new_doc.add_data_file(test_filename)
    return new_doc
  end
end
