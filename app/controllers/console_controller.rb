class ConsoleController < ApplicationController

  def index
  end

  def graphs
  end

  def documentation
  end

  def readings
    target = 'reading_log'
    @heading = 'Recent Readings'
    if params['type'] == 'anomalies'
      target = 'anomoly_log'
      @heading = 'Anomalies'
    end
    @readings = memcache.get_array(target, params)
  end

  def log
    log = Log_Wrapper.new('/home/renen/cep/log.txt')
    @log_detail = log.web_grep(params['guid'])
  end

end