require File.dirname(__FILE__) + '/user_file_system'



class BindUserFileSystem

  @@add_user_script = "sudo /media-ec2/ec2a/projects/bufs/bufs_scripts/user_script_add"
  @@rem_user_script = "sudo /media-ec2/ec2a/projects/bufs/bufs_scripts/user_script_del"
  @@base_home_dir = "/media-ec2/ec2a/bufs_users/"

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

  def self.make_nodeClass(user_id, home_dir)
    UserFileNode.new(home_dir, user_id)
    UserFileNode.user_to_nodeClass[user_id]
  end

  def self.get_home_dir(user_id)
    @@base_home_dir + user_id + '/'
  end

  def self.get_user_node(user_id, pw)
     #TODO check password
     nodeClass = nil
     if BindUserFileSystem.user_exists?(user_id)
       #TODO Find Linux command or script to return home directory based on user id
       home_dir = BindUserFileSystem.get_home_dir(user_id)
       nodeClass = UserFileNode.user_to_nodeClass[user_id]||BindUserFileSystem.make_nodeClass(user_id, home_dir)
     else
       BindUserFileSystem.add_user_to_system(user_id, pw)
       #TODO: Find direct from linux
       home_dir = @@base_home_dir + user_id + '/'
       nodeClass = UserFileNode.user_to_nodeClass[user_id]||BindUserFileSystem.make_nodeClass(user_id, home_dir)
     end
     nodeClass
   end
end       
