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
    @precipitation_tv = (@readings['precipitation_tv']['reading']*10.0).round/10.0
    @precipitation_tw = (@readings['precipitation_tw']['reading']*10.0).round/10.0
    @precipitation_tx = (@readings['precipitation_tx']['reading']*10.0).round/10.0
    @precipitation_t0 = (@readings['precipitation_t0']['reading']*10.0).round/10.0
    @precipitation_t1 = (@readings['precipitation_t1']['reading']*10.0).round/10.0
    @precipitation_t2 = (@readings['precipitation_t2']['reading']*10.0).round/10.0
    @precipitation_3h = (@readings['precipitation_3h']['reading']*10.0).round/10.0
    @precipitation_tv_icon = weather_icon(@precipitation_tv)
    @precipitation_tw_icon = weather_icon(@precipitation_tw)
    @precipitation_tx_icon = weather_icon(@precipitation_tx)
    @precipitation_t0_icon = weather_icon(@precipitation_t0)
    @precipitation_t1_icon = weather_icon(@precipitation_t1)
    @precipitation_t2_icon = weather_icon(@precipitation_t2)
    @precipitation_3h_icon = weather_icon(@precipitation_3h*8.0)

    @type_counts = {}

  end

  def weather_icon(precipitation)
    icon = 'sun.rays.small.png'
    icon = 'sun.rays.small.cloud.png'   if precipitation > 0 and precipitation <= 1
    icon = 'sun.rays.cloud.drizzle.png' if precipitation > 1 and precipitation <= 5
    icon = 'cloud.drizzle.png'          if precipitation > 5 and precipitation <= 10
    icon = 'cloud.dark.rain.png'        if precipitation > 10
    "weather/64x64/#{icon}"
  end

end
