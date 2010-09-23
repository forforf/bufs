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

#for testing CouchRest model
module CouchRestNodeHelpers

  def self.env_builder(node_class_id, db, db_user_id)
      node_env = Hash[ node_class_id =>
                      Hash[ :requires => UserNodeSpecHelpers::BufsNodeLibs,
                            :includes => UserNodeSpecHelpers::BufsNodeIncludes,
                            :glue_name => "BufsCouchRestEnv",
                            :class_env =>
                            Hash[ :bufs_info_doc_env =>
                                  Hash[ :host => db.host,
                                        :path => db.uri,
                                        :user_id => db_user_id
                                      ]
                                ]
                          ]
                    ]
  end
end

module FileSystemNodeHelpers
  def self.env_builder(node_class_id, root_path, fs_user_id)
      node_env = Hash[ node_class_id =>
                      Hash[ :requires => UserNodeSpecHelpers::BufsFileLibs,
                            :includes => UserNodeSpecHelpers::BufsFileIncludes,
                            :glue_name => "BufsFileSystemEnv",
                            :class_env =>
                            Hash[ :bufs_file_system_env =>
                                  Hash[ :path => root_path,
                                        :user_id => fs_user_id
                                      ]
                                ]
                          ]
                    ]
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
