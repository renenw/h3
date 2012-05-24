class ConsoleController < ApplicationController

  def index
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

end
