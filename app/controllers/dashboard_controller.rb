class DashboardController < ApplicationController

  def index
  end

  def readings
    @readings = memcache.get_readings_log(params).reverse
    @readings = @readings.first(params['n'].to_i) if params['n']
  end

end
