$stdout.sync
IO.popen('./test_script') { |f|
    flags = []
    until f.eof?
      output = f.gets
      if (output =~ /^Start/) && (!flags.include? output)
        puts "Starting Now" if output =~ /^Start/
      else
        puts "More #{output}" if (!flags.include? output)
      end
      flags << output
      flags.uniq!
      puts "stdout: #{output}"
    end
  }

