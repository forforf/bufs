#require helper for cleaner require statements
require File.join(File.dirname(__FILE__), '/helpers/require_helper')

require Bufs.lib 'bufs_node_factory'

class BindUserFileSystem

  @@add_user_script = "sudo /media-ec2/ec2a/projects/bufs/bufs_scripts/user_script_add"
  @@rem_user_script = "sudo /media-ec2/ec2a/projects/bufs/bufs_scripts/user_script_del"
  @@base_home_dir = "/media-ec2/ec2a/bufs_users/"
  
  @@base_class_name = "FileSys"
  @@glue_libs = [File.join(File.dirname(__FILE__), 'glue_envs/bufs_filesystem_glue_env')]
  
  def self.user_filesys_env_builder(node_class_id, root_path, user_id)
      node_env = Hash[ node_class_id =>
                      Hash[ :requires => @@glue_libs,
                            :includes => [:FileSystemEnv],
                            :glue_name => "BufsFileSystemEnv",
                            :class_env =>
                            Hash[ :bufs_file_system_env =>
                                  Hash[ :path => root_path,
                                        :user_id => user_id
                                      ]
                                ]
                          ]
                    ]
  end

  def self.user_exists?(user_id)
    if `id #{user_id}`.empty?
      false
    else
      true
    end
  end

  def self.add_user_to_system(user_id, pw)
     #FIXME: Thread safe?
    `#{@@add_user_script} #{user_id} #{pw}` unless BindUserFileSystem.user_exists?(user_id)
  end

  def self.remove_user_from_system(user_id)
    `#{@@rem_user_script} #{user_id}`
  end 
  
  def self.make_class_name(user_id)
    "#{@@base_class_name}#{user_id}"
  end
  
  def self.make_nodeClass(user_id)
    #raise "Need to rewrite for new architecture"
    node_class_name = BindUserFileSystem.make_class_name(user_id)
    fs_env = BindUserFileSystem.user_filesys_env_builder(node_class_name, File.join(@@base_home_dir), user_id)
    BufsNodeFactory.make(fs_env)
  end

  def self.get_home_dir(user_id)
    @@base_home_dir + user_id + '/'
  end

  def self.get_user_node_class(user_id, pw)
    #raise "Need to rewrite for new arch"
     #TODO check password
     nodeClass = nil
     if BindUserFileSystem.user_exists?(user_id)
       #Home Dirs are generated automatically so below is no longer needed?
       #TODO Find Linux command or script to return home directory based on user id
       #home_dir = BindUserFileSystem.get_home_dir(user_id)
       
       #TODO: create method to find existing user class (if it exists)
       #For now it shouldn't cause problems to recreate the class, since Ruby will merge it to the existing class
       nodeClass = BindUserFileSystem.make_nodeClass(user_id)
     else
       BindUserFileSystem.add_user_to_system(user_id, pw)
       #TODO: Find direct from linux
       home_dir = BindUserFileSystem.get_home_dir(user_id)
       
       #TODO: create method to find existing user class (if it exists)
       #For now it shouldn't cause problems to recreate the class, since Ruby will merge it to the existing class
       nodeClass = BindUserFileSystem.make_nodeClass(user_id)
     end
     nodeClass
   end
end       
