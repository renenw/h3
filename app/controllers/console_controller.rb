class ConsoleController < ApplicationController

  def index
  end

  def readings
    @readings = memcache.get_array('reading_log', params).reverse
    @readings = @readings.first(params['n'].to_i) if params['n']
  end

end
