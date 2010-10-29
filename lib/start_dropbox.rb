#!/usr/local/bin/ruby

class DropboxScript
  def self.start(user)
    $stdout.sync
    IO.popen("/usr/bin/sudo /home/bufs/bufs/bufs_scripts/user_script_start_dropboxd #{user}") { |f|
      flags = []
      until f.eof?
        output = f.gets
        if output =~ /Please visit https:\/\/www.dropbox.com\//
          db_match = output.match(/https.*to link this machine/)
          ret_value = db_match.to_s.gsub(" to link this machine", "")
          return ret_value
        else
           ret_value = ret_value || ""
           output = output || ""
           ret_value = ret_value + ":::" + output
        end
        puts "stdout: #{output}"
      end
      return ret_value
    }
  end
end

#x = DropboxScript.start(ARGV[0])
#puts "Returned Value = #{x}"

