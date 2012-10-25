require './credentials'

Infinity = 1.0/0

CACHED_HISTORY_ITEMS      = 200
OUTLIER_ITEMS             = 200
PAYLOAD_HISTORY_ITEMS     = 500
ANOMOLOUS_READING_HISTORY = 200

RABBIT_HOST     = '127.0.0.1'
RABBIT_PASSWORD = '2PvvWRzgrivs'

RABBIT_EXCHANGE = ''

RABBIT_READINGS_EXCHANGE  = 'process_inbound'
RABBIT_TWITTER_EXCHANGE   = 'holler_exchange'

DATA_STORE          = '30_camp_ground_road'
TEMPERATURE_SUFFIX  = '&deg; C'
WATT_HOURS          = ' wh<sup>-1</sup>'
BPS                 = ' bs<sup>-1</sup>'

SETTINGS = {
  'timezone' => 'Africa/Johannesburg'
}

MONITORS = {
  'electricity_total'   => { 
                              :monitor_type => :pulse, 
                              :expected_frequency => 60, 
                              :suffix => WATT_HOURS, 
                              :range => { :min => 0, :max => Infinity}, 
                              :websocket => { 
                                              :dimensions => {
                                                'day'   => ['sum'],
                                                'week'  => ['sum'],
                                                'month' => ['sum']
                                              }
                                            } 
                            },
  'electricity_geyser'  => { 
                              :monitor_type => :pulse, 
                              :expected_frequency => 60, 
                              :suffix => WATT_HOURS, 
                              :range => { :min => 0, :max => Infinity},
                              :websocket => { 
                                              :dimensions => {
                                                'day'   => ['sum'],
                                                'week'  => ['sum'],
                                                'month' => ['sum']
                                              }
                                            } 
                            },
  'electricity_pool'    => { 
                              :monitor_type => :pulse, 
                              :expected_frequency => 60, 
                              :suffix => WATT_HOURS, 
                              :range => { :min => 0, :max => Infinity},
                              :websocket => { 
                                              :dimensions => {
                                                'day'   => ['sum'],
                                                'week'  => ['sum'],
                                                'month' => ['sum']
                                              }
                                            } 
                            },
  'temperature_cellar'  => { :monitor_type => :gauge, :expected_frequency => 300, :suffix => TEMPERATURE_SUFFIX, :websocket => { :reading => true } },
  'temperature_outside' => { 
                              :monitor_type => :gauge, 
                              :expected_frequency => 300, 
                              :suffix => TEMPERATURE_SUFFIX , 
                              :websocket => { 
                                              :reading => true,
                                              :dimensions => {
                                                'day'   => ['min', 'max']
                                              }
                                            }
                            },
  'temperature_inside'  => { 
                              :monitor_type => :gauge, 
                              :expected_frequency => 300, 
                              :suffix => TEMPERATURE_SUFFIX, 
                              :websocket => { 
                                              :reading => true,
                                              :dimensions => {
                                                'day'   => ['min', 'max']
                                              }
                                            }
                            },
  'temperature_pool'    => { :monitor_type => :gauge, :range => { :min => 0, :max => 40}, :expected_frequency => 300, :suffix => TEMPERATURE_SUFFIX, :websocket => { :reading => true } },
  'bandwidth'           => { :monitor_type => :mrtg, :expected_frequency => 60  },
  'bandwidth_in'        => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60, :suffix => ' bytes' },
  'bandwidth_out'       => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60, :suffix => ' bytes' },
  'bandwidth_total'     => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60, :suffix => ' bytes' },
  'outlier'             => { :monitor_type => :counter },
  'alarm_alive'         => { :monitor_type => :keep_alive, :name => 'Alarm and Pool Keep Alive', :expected_frequency => 60*60 },
  'alarm_armed'         => { :monitor_type => :switch },
  'alarm_activated'     => { :monitor_type => :switch },
  'bandwidth_throughput'=> { :monitor_type => :gauge, :expected_frequency => 86400 },
  'bandwidth_bps'       => { :monitor_type => :gauge, :expected_frequency => 86400, :suffix => BPS },
  'bandwidth_qos'       => { :monitor_type => :gauge, :expected_frequency => 86400 },
  'weather_forecast'    => { :monitor_type => :keep_alive, :name => 'Weather Forecast', :expected_frequency => 60*60*24 }
}