Infinity = 1.0/0

CACHED_HISTORY_ITEMS      = 200
OUTLIER_ITEMS             = 200
PAYLOAD_HISTORY_ITEMS     = 500
ANOMOLOUS_READING_HISTORY = 200


RABBIT_HOST     = '127.0.0.1'
RABBIT_PASSWORD = '2PvvWRzgrivs'

RABBIT_EXCHANGE = ''

RABBIT_PROCESS_EXCHANGE = 'process_inbound'

DATA_STORE = '30_camp_ground_road'
TEMPERATURE_SUFFIX = '&deg; C'

SETTINGS = {
  'timezone' => 'Africa/Johannesburg'
}

MONITORS = {
  'electricity_total'   => { :monitor_type => :pulse, :expected_frequency => 60 },
  'electricity_geyser'  => { :monitor_type => :pulse, :expected_frequency => 60 },
  'electricity_pool'    => { :monitor_type => :pulse, :expected_frequency => 60 },
  'temperature_cellar'  => { :monitor_type => :gauge, :expected_frequency => 300, :suffix => TEMPERATURE_SUFFIX },
  'temperature_outside' => { :monitor_type => :gauge, :expected_frequency => 300, :suffix => TEMPERATURE_SUFFIX  },
  'temperature_inside'  => { :monitor_type => :gauge, :expected_frequency => 300, :suffix => TEMPERATURE_SUFFIX  },
  'temperature_pool'    => { :monitor_type => :gauge, :range => { :min => 0, :max => 40}, :expected_frequency => 300, :suffix => TEMPERATURE_SUFFIX  },
  'bandwidth'           => { :monitor_type => :mrtg, :expected_frequency => 60  },
  'bandwidth_in'        => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
  'bandwidth_out'       => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
  'bandwidth_total'     => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
  'outlier'             => { :monitor_type => :counter },
  'alarm_alive'         => { :monitor_type => :keep_alive, :name => 'Alarm Monitor' },
  'bandwidth_throughput'=> { :monitor_type => :gauge, :expected_frequency => 86400 }
}


#  'alarm_armed'         => { : },
#  'alarm_activated'     => {}
