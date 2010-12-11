#bootstrap requires follow module

#Bufs Library Locations
module Bufs
  @@top = File.join(File.dirname(__FILE__), '../..')  #main bufs directory
  @@lib = File.join(@@top, 'lib/')
  @@helpers = File.join(@@top, 'lib/helpers/')
  @@moabs = File.join(@@lib, 'moabs')
  @@midas = File.join(@@lib, 'midas')
  @@glue = File.join(@@lib, 'glue_envs')
  @@specs = File.join(@@top, 'spec')
  @@spec_helpers = File.join(@@specs, 'helpers')
  @@fixtures = File.join(@@top, 'bufs_fixtures')

  def self.lib(req_file)
    File.expand_path(File.join(@@lib, req_file))
  end

  def self.helpers(req_file)
    File.expand_path(File.join(@@helpers, req_file))
  end

  def self.spec(req_file)
    File.expand_path(File.join(@@specs, req_file))
  end

  def self.spec_helpers(req_file)
    File.expand_path(File.join(@@spec_helpers, req_file))
  end

  def self.fixtures(req_file)
    File.expand_path(File.join(@@fixtures, req_file))
  end

  def self.moabs(req_file)
    File.expand_path(File.join(@@moabs, req_file))
  end

  def self.midas(req_file)
    File.expand_path(File.join(@@midas, req_file))
  end

  def self.glue(req_file)
    File.expand_path(File.join(@@glue, req_file))
  end
end

