class HomeController < ApplicationController

  def index

    @readings           = memcache.get_readings(params)
    @inside_day         = memcache.get_summary('data_store' => params['data_store'], 'source' => 'temperature_inside', 'dimension' => 'day' )['temperature_inside']['values']
    @outside_day        = memcache.get_summary('data_store' => params['data_store'], 'source' => 'temperature_outside', 'dimension' => 'day' )['temperature_outside']['values']

    @electricity_total_day    = memcache.get_summary('data_store' => params['data_store'], 'source' => 'electricity_total', 'dimension' => 'day' )['electricity_total']['values']['sum']/1000
    @electricity_total_week   = memcache.get_summary('data_store' => params['data_store'], 'source' => 'electricity_total', 'dimension' => 'week' )['electricity_total']['values']['sum']/1000
    @electricity_total_month  = memcache.get_summary('data_store' => params['data_store'], 'source' => 'electricity_total', 'dimension' => 'month' )['electricity_total']['values']['sum']/1000

    @messages           = memcache.get_array("messages", params)
    @message_icons      = {
        'alarm'         => 'icon-bell',
        'solenoid'      => 'icon-tint',
        'grey_water'    => 'icon-share',
        'notice'        => 'icon-envelope',
        'access'        => 'icon-remove-circle',
    }

    @bps        = (@readings['bandwidth_bps']['reading']/1024).round
    @bps_class  = ''
    @bps_class  = 'label-success' if @bps>300
    @bps_class  = 'label-warning' if @bps<200

    @qos        = @readings['bandwidth_qos']['reading'].round(2)
    @qos_class  = 'label-success'
    @qos_class  = ''              if @qos > 1
    @qos_class  = 'label-warning' if @qos > 2

    @irrigation = (@readings['rainy_day']['reading']==0)
    @precipitation_t0 = (@readings['precipitation_t0']['reading']*10.0).round/10.0
    @precipitation_t1 = (@readings['precipitation_t1']['reading']*10.0).round/10.0
    @precipitation_t2 = (@readings['precipitation_t2']['reading']*10.0).round/10.0
    @precipitation_t0_icon = weather_icon(@precipitation_t0)
    @precipitation_t1_icon = weather_icon(@precipitation_t1)
    @precipitation_t2_icon = weather_icon(@precipitation_t2)

    @type_counts = {}

  end

  def weather_icon(precipitation)
    icon = 'weather/64x64/sun.rays.small.png'
    icon = 'weather/64x64/sun.rays.small.cloud.png'   if precipitation > 0 and precipitation <= 1
    icon = 'weather/64x64/sun.rays.cloud.drizzle.png' if precipitation > 1 and precipitation <= 5
    icon = 'weather/64x64/cloud.drizzle.png'          if precipitation > 5 and precipitation <= 10
    icon = 'weather/64x64/cloud.dark.rain.png'        if precipitation > 10
    icon
  end

end
