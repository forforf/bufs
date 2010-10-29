user = "dbtest004"
#link = %x[sudo /home/bufs/bufs/bufs_scripts/user_script_dropbox_testing.rb #{user}]
#p link
$stdout.sync
    IO.popen("sudo /home/bufs/bufs/bufs_scripts/user_script_dropbox_testing.rb #{user}") { |f|
      flags = []
      until f.eof?
        output = f.gets
        #if output =~ /Please visit https:\/\/www.dropbox.com\//
        #  db_match = output.match(/https.*to link this machine/)
        #  db_link = db_match.to_s.gsub(" to link this machine", "")
        #  return db_link
        #end
        puts "stdout: #{output}"
      end
    }

