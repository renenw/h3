class ApiController < ApplicationController

  def get_readings
    respond_to do |format|
      format.json  { render :json => memcache.get_readings(params) }
    end
  end

  def get_history
    respond_to do |format|
      format.json  { render :json => memcache.get_history(params) }
    end
  end

  def get_sensor_list
    respond_to do |format|
      format.json  { render :json => memcache.get_sensor_list(params) }
    end
  end

  def get_summaries
    respond_to do |format|
      format.json  { render :json => memcache.get_summaries(params) }
    end    
  end

  def get_summary
    respond_to do |format|
      format.json  { render :json => memcache.get_summary(params) }
    end
  end

end


