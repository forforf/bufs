require 'log4r'

#Set Logger
#TODO: Create spec
module BufsLog
  include Log4r

  class << self; attr_accessor :default_level, :fatal_log, :log_output end
  BufsLog.default_level = :info
  BufsLog.log_output = 'stdout'
  BufsLog.fatal_log = Logger.new('fatal_log')
  BufsLog.fatal_log.level = FATAL
  BufsLog.fatal_log.outputters = Outputter[BufsLog.log_output]

  @@log_levels = { :debug => DEBUG,
                   :info => INFO,
                   :warn => WARN,
                   :error => ERROR,
                   :fatal => FATAL
                 }

  def self.set(name, level=BufsLog.default_level, out=Outputter.stdout)
    log = Logger[name] || Logger.new(name)
    log.outputters = out
    log.level = @@log_levels[level]
    log.trace = true if log.level <= DEBUG
    log
  end

  def self.log_raise(error_msg, exc_type= RuntimeError)
    self.fatal_log.fatal("#{__LINE__} #{error_msg}") 
    raise exc_type, error_msg
  end
end
