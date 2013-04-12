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
    }

    @bps        = (@readings['bandwidth_bps']['reading']/1024).round
    @bps_class  = ''
    @bps_class  = 'label-success' if @bps>300
    @bps_class  = 'label-warning' if @bps<200

    @qos        = @readings['bandwidth_qos']['reading'].round(2)
    @qos_class  = 'label-success'
    @qos_class  = ''              if @qos > 1
    @qos_class  = 'label-warning' if @qos > 2

    @type_counts = {}

  end

end
