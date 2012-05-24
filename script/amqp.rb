#!/usr/bin/env ruby
# encoding: utf-8

require "amqp"
require 'json'
require 'mysql2'
require 'tzinfo'
require './cacher'
require 'pp'

Infinity = 1.0/0

@mysql = Mysql2::Client.new(:host => "localhost", :username => "root", :database => "30_camp_ground_road")
@cache = Cacher.new('localhost:11211')

CACHED_HISTORY_ITEMS      = 200
OUTLIER_ITEMS             = 200
PAYLOAD_HISTORY_ITEMS     = 500
ANOMOLOUS_READING_HISTORY = 200

RABBIT_HOST     = '127.0.0.1'
RABBIT_PASSWORD = '2PvvWRzgrivs'

RABBIT_EXCHANGE = ''
RABBIT_PROCESS_EXCHANGE = 'process_inbound'

SETTINGS = {
  'timezone' => 'Africa/Johannesburg'
}

MONITORS = {
  'electricity_total'   => { :monitor_type => :pulse, :expected_frequency => 60 },
  'electricity_geyser'  => { :monitor_type => :pulse, :expected_frequency => 60 },
  'temperature_cellar'  => { :monitor_type => :gauge, :expected_frequency => 300 },
  'temperature_outside' => { :monitor_type => :gauge, :expected_frequency => 300 },
  'temperature_inside'  => { :monitor_type => :gauge, :expected_frequency => 300 },
  'temperature_pool'    => { :monitor_type => :gauge, :range => { :min => 0, :max => 40}, :expected_frequency => 300 },
  'bandwidth'           => { :monitor_type => :mrtg, :expected_frequency => 60  },
  'bandwidth_in'        => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
  'bandwidth_out'       => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
  'bandwidth_total'     => { :monitor_type => :pulse, :range => { :min => 0, :max => Infinity}, :expected_frequency => 60 },
  'outlier'             => { :monitor_type => :counter },
}

module UmmpServer

  def initialize(exchange)
    @ummp_exchange = exchange
  end

  def receive_data(udp_data)
    if udp_data =~ /\A(\w+)(\s[\d\.]+){1,3}$/
      message = { 'received' => Time.now.to_f, 'packet' => udp_data.strip }.to_json
      @ummp_exchange.publish message, :routing_key => 'udp_handler'
    end
  end
end

def orchestrate

  initialise_monitors
  udp_receiver = Thread.new() { receive_udp_packets }
  mesage_processor = Thread.new() { de_queuer }

  p "Started"

  udp_receiver.join
  mesage_processor.join

end

def receive_udp_packets
  EventMachine.run do
    udp_amqp_client = AMQP.connect(:host => RABBIT_HOST,  :password => RABBIT_PASSWORD)
    channel  = AMQP::Channel.new(udp_amqp_client)
    exchange = channel.direct(RABBIT_EXCHANGE)
    EventMachine::open_datagram_socket '10.245.77.15', 54545, UmmpServer, exchange
  end
end

def de_queuer
  EventMachine.run do
    AMQP.connect(:host => RABBIT_HOST,  :password => RABBIT_PASSWORD) do |connection|

      channel  = AMQP::Channel.new(connection)

      @exchange = channel.direct(RABBIT_EXCHANGE)
      @process_exchange = channel.fanout(RABBIT_PROCESS_EXCHANGE)

      channel.queue('udp_handler', :auto_delete => false).subscribe do |message|
        handle_udp(message)
      end

      channel.queue('initialise_structured_message', :auto_delete => false).subscribe do |message|
        initialise_structured_message(message)
      end

      channel.queue('handle_mrtg_pre_processing', :auto_delete => false).subscribe do |message|
        handle_mrtg_pre_processing(message)
      end

      channel.queue('counter', :auto_delete => false).subscribe do |message|
        handle_gauge(message)
      end

      channel.queue('gauge', :auto_delete => false).subscribe do |message|
        handle_gauge(message)
      end

      channel.queue('pulse', :auto_delete => false).subscribe do |message|
        handle_pulse(message)
      end

      channel.queue('reading', :auto_delete => false).subscribe do |message|
        handle_reading(message)
      end

      channel.queue('summariser', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_summarisation(message)
      end

      channel.queue('historifier', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_history(message)
      end

      channel.queue('calculate_outlier_threshold', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_calculate_outlier_threshold(message)
      end

      channel.queue('cache_reading', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_cache_reading(message)
      end

      channel.queue('cache_sources', :auto_delete => false).bind(@process_exchange).subscribe do |message|
        handle_cache_sources(message)
      end

    end
  end
end

# an opportunity to rewrite messages, ditch them etc
def handle_udp(message)
  payload = JSON.parse(message)
  data = payload['packet'].scan(/[\w\.]+/)
  source_type = MONITORS[data[0]][:monitor_type]
  next_handler = 'initialise_structured_message'
  if source_type
    next_handler = 'handle_mrtg_pre_processing' if source_type == :mrtg
    @exchange.publish payload.merge(
                                    { 'data_store' => '30_camp_ground_road',
                                      'source' => data[0],
                                      'source_type' => source_type.to_s
                                     }
                                 ).to_json, :routing_key => next_handler
  end
end

def handle_mrtg_pre_processing(message)
  payload = JSON.parse(message)
  #puts "MRTG message received: #{payload}"
# "packet"=>"bandwidth 1330463695 2198531 2374663"
  data = payload['packet'].scan(/[\w\.]+/)
  inbound = data[2]
  outbound = data[3]
  inbound_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_in #{inbound}" }.to_json
  outbound_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_out #{outbound}" }.to_json
  combined_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_total #{outbound.to_i + inbound.to_i}" }.to_json
  @exchange.publish inbound_message, :routing_key => 'udp_handler'  
  @exchange.publish outbound_message, :routing_key => 'udp_handler'
  @exchange.publish combined_message, :routing_key => 'udp_handler'
end

# messages should, by this point, have a basic "events" structure (source, number) with a received time that as closely as practically reflects the event time
def initialise_structured_message(message)
  #puts "Initialise structured message: #{message}."
  payload = JSON.parse(message)
  data = payload['packet'].scan(/[\w\.]+/)
  i = data[1].to_f.round.to_i
  event_time_in_utc = Time.at(payload['received'].to_f)
  local_time = get_local_time(SETTINGS['timezone'], event_time_in_utc)
  @mysql.query("insert into events (source, float_value, integer_value, created_at) values ('#{data[0]}', #{data[1]}, #{i}, '#{event_time_in_utc.strftime('%Y-%m-%d %H:%M:%S.%6N')}');")
  event_id = @mysql.last_id
  @exchange.publish payload.merge(
                                    {
                                      'local_time' => local_time.to_f,
                                      'dimensions' => get_tagged_dimensions(local_time),
                                      'event_id' => event_id,
                                      'float_value' => data[1].to_f,
                                      'integer_value' => i
                                    }
                                 ).to_json, :routing_key => payload['source_type']
end

def handle_reading(message)
  payload = JSON.parse(message)
  reasonable = reading_reasonable(payload)
  sql_error = nil
  if reasonable
    t = payload['dimensions']
    begin
      @mysql.query "insert into #{payload['data_store']}.readings (source, local_time, reading, year, month, week, day, hour, 5minute, 10minute, 15minute, 30minute, yday) values ('#{payload['source']}', #{payload['local_time']}, #{payload['converted_value']}, #{t['year']}, #{t['month']}, #{t['week']}, #{t['day']}, #{t['hour']}, #{t['5minute']}, #{t['10minute']}, #{t['15minute']}, #{t['30minute']}, #{t['yday']})"
      @process_exchange.publish message
    rescue #should only really be catching the error on the sql
      p "Insert failed"
      p "#{payload}"
      p "#{$!}"
      sql_error = $!
    end
  else
    @mysql.query "insert into #{payload['data_store']}.outliers (event_id) values (#{payload['event_id']})"
  end
  #n = @cache.incr("#{payload['data_store']}.reading_log", 1, nil, 0)
  #@cache.set("#{payload['data_store']}.reading_log.#{ n % PAYLOAD_HISTORY_ITEMS }", {
  @cache.array_append("#{payload['data_store']}.reading_log", {
                                                                                       'local_time' => payload['local_time']*1000,
                                                                                       'reading' => payload['converted_value'],
                                                                                       'source' => payload['source'],
                                                                                       'payload' => payload,
                                                                                       'outlier' => !reasonable,
                                                                                       'sql_error' => sql_error,
                                                                                     }, PAYLOAD_HISTORY_ITEMS)

  if (sql_error || !reasonable)
    @cache.array_append("#{payload['data_store']}.anomoly_log", {
                                                                                         'local_time' => payload['local_time']*1000,
                                                                                         'reading' => payload['converted_value'],
                                                                                         'source' => payload['source'],
                                                                                         'payload' => payload,
                                                                                         'outlier' => !reasonable,
                                                                                         'sql_error' => sql_error,
                                                                                       }, ANOMOLOUS_READING_HISTORY)
  end

end

def handle_cache_reading(message)
  payload = JSON.parse(message)
  expires = nil
  expires = payload['received']*1000 + 1.5 * MONITORS[payload['source']][:expected_frequency]*1000 if MONITORS[payload['source']][:expected_frequency] 
  @cache.set("#{payload['data_store']}.reading.#{payload['source']}", {
                                                                        'local_time' => payload['local_time']*1000,
                                                                        'reading' => payload['converted_value'],
                                                                        'expires' => expires,
                                                                       })
end

def handle_cache_sources(message)
  payload = JSON.parse(message)
  sources = @cache.get("#{payload['data_store']}.sources")
  if sources
    sources[payload['source']] = payload['received'].to_i
  else
    p "miss sources"
    sources = {}
    @mysql.query("select source, max(created_at) as _created_at from #{payload['data_store']}.events group by source").each do |row|
      sources[row['source']] = row['_created_at'].to_i
    end
  end
  @cache.set("#{payload['data_store']}.sources", sources)
end


def handle_calculate_outlier_threshold(message)

  payload = JSON.parse(message)
  converted_value = payload['converted_value']

  if MONITORS[payload['source']][:range]
    #p "Pool range check"
  else
    if MONITORS[payload['source']][:monitor_type] == :pulse
      s = @cache.get("#{payload['data_store']}.outlier.#{payload['source']}.history")
      unless s
        p "missed outliers #{payload['source']}"
        s = []
        @mysql.query("select reading from #{payload['data_store']}.readings where source = '#{payload['source']}' and reading > 0 order by local_time desc limit #{OUTLIER_ITEMS}").each do |row|
          s << row['reading']
        end
      end
      revised_threshold = nil
      current_threshold = @cache.get("#{payload['data_store']}.outlier.#{payload['source']}.threshold")
      s = [] unless s
      if current_threshold.nil? || ( converted_value <= current_threshold )
        s << converted_value if converted_value > 0
        s.shift if s.length > OUTLIER_ITEMS
      end
      if s.length > 100
        stats = get_stats(s)
        revised_threshold = stats[:average] * 2 + stats[:standard_deviation] * 6 if stats[:standard_deviation] != 0
     end
      @cache.set("#{payload['data_store']}.outlier.#{payload['source']}.history", s)
      if revised_threshold && ( current_threshold != revised_threshold)
        @cache.set("#{payload['data_store']}.outlier.#{payload['source']}.threshold", revised_threshold)
      end
    end
  end

end

def get_stats(a)
  min = a.first
  max = a.first
  sum = 0
  a.each do |e|
    min = ( e<min ? e : min )
    max = ( e>max ? e : max )
    sum = sum + e
  end
  avg = sum / a.length.to_f
  var = 0
  a.each do |e|
    var = var + (e - avg)**2
  end
  var = var / (a.length - 1).to_f
  {
    :average => avg,
    :min => min,
    :max => max,
    :variance => var,
    :standard_deviation => Math.sqrt(var)
  }
end

def handle_history(message)
  payload = JSON.parse(message)
  history = @cache.get("#{payload['data_store']}.history.#{payload['source']}")
  if history
    history << { 'local_time' => (payload['local_time']*1000).to_i, 'converted_value' => payload['converted_value'] }
    history.shift if history.length > CACHED_HISTORY_ITEMS
  else
    p "miss history"
    history = []
    @mysql.query("select local_time, reading from #{payload['data_store']}.readings where source = '#{payload['source']}' order by local_time desc limit #{CACHED_HISTORY_ITEMS}").each do |row|
      history << { 'local_time' => row['local_time']*1000, 'reading' => row['reading'] }
    end
  end
  @cache.set("#{payload['data_store']}.history.#{payload['source']}", history)
end

def handle_summarisation(message)
  payload = JSON.parse(message)
  data_store = payload['data_store']
  reading    = payload['converted_value']
  source     = payload['source']
  local_time = payload['local_time'].to_i

  payload['dimensions'].each do |dimension, tag|
    cached_entry = get_current_summary_cache_entry(data_store, source, dimension, tag, reading)
    history = update_summary_history_cache(data_store, source, dimension, tag, cached_entry) if dimension != 'all_time'
#    print_history "#{source} #{dimension}:", history if history && dimension != 'all_time'
  end
end

#def print_history(description, history)
#  l = ""
#  p description
#  history.each do |e|
#    l = l + " | #{e['tag']} #{e['values']['sum']}"
#    if l.length > 120
#      p l
#      l = ""
#    end
#  end
#  p l
#end

def update_summary_history_cache(data_store, source, dimension, tag, cached_entry)
  history = @cache.get("#{data_store}.history.#{source}.#{dimension}")
  if history
    if history.last['tag'] == tag
      history[history.length-1] = cached_entry
    else
      history << cached_entry
    end
    history.shift if history.length > CACHED_HISTORY_ITEMS
  else
    p "miss summary history"
    history = []
    @mysql.query(summary_history_sql(data_store, dimension, source)).each do |row|
      history << {
                    'tag'        => row[dimension],
                    'values'     => construct_summary_history_entry(row),
                 }
    end
    history.reverse!
  end
  @cache.set("#{data_store}.history.#{source}.#{dimension}", history)
  history
end

def get_current_summary_cache_entry(data_store, source, dimension, tag, reading)
  cached_entry = @cache.get("#{data_store}.summary.#{source}.#{dimension}")
  if cached_entry
    if cached_entry['tag'] == tag
      cached_entry['values']['count'] += 1
      cached_entry['values']['sum'] = cached_entry['values']['sum'] + reading
      cached_entry['values']['avg'] = cached_entry['values']['sum'] / cached_entry['values']['count'].to_f
      cached_entry['values']['max'] = ( reading>cached_entry['values']['max'] ? reading : cached_entry['values']['max'] )
      cached_entry['values']['min'] = ( reading<cached_entry['values']['min'] ? reading : cached_entry['values']['min'] )
    else
      cached_entry['tag'] = tag
      cached_entry['values']['count'] = 1
      cached_entry['values']['sum'] = reading
      cached_entry['values']['avg'] = reading
      cached_entry['values']['max'] = reading
      cached_entry['values']['min'] = reading
    end
  else
    p 'summary cache miss'
    cached_entry = { "tag" => tag }
    @mysql.query(summary_sql(data_store, dimension, tag, source)).each do |row|
      cached_entry['values'] = construct_summary_history_entry(row)
    end
  end
  @cache.set("#{data_store}.summary.#{source}.#{dimension}", cached_entry)
  cached_entry
end

def construct_summary_history_entry(row)
  {
    'count' => row['_count'].to_i,
    'sum'   => row['_sum'].to_f,
    'avg'   => row['_avg'].to_f,
    'max'   => row['_max'].to_f,
    'min'   => row['_min'].to_f,
  }
end

def handle_counter
  payload = JSON.parse(message)
  @exchange.publish payload.merge( { 'converted_value' => payload['float_value'] } ).to_json, :routing_key => 'reading'
end

def handle_gauge(message)
  payload = JSON.parse(message)
  @exchange.publish payload.merge( { 'converted_value' => payload['float_value'] } ).to_json, :routing_key => 'reading'
end

def handle_pulse(message)
  payload = JSON.parse(message)
  prior_pulses = @cache.fetch("#{payload['data_store']}.pulse.last.#{payload['source']}") do
    p "pulse miss"
    pulses = nil
    @mysql.query("select max(integer_value) as pulses from #{payload['data_store']}.events where source = '#{payload['source']}' and id < #{payload['event_id']};").each do |row|
      pulses = row['pulses']
    end
    pulses
  end
  if prior_pulses
    elapsed_pulses = payload['integer_value'] - prior_pulses
    # this is kuk. should pass conversion function using monitors structure at start
    converted_value = elapsed_pulses
    converted_value = pulse_to_watt_hours(elapsed_pulses) unless payload['source'] =~ /band/
    @exchange.publish payload.merge( { 'converted_value' => converted_value } ).to_json, :routing_key => 'reading'
  end
  @cache.set("#{payload['data_store']}.pulse.last.#{payload['source']}", payload['integer_value'])
end

def pulse_to_watt_hours(pulses)
  pulses * 10
end

def get_local_time(timezone, event_time_in_utc)
  tz = TZInfo::Timezone.get(timezone)
  tz.utc_to_local(event_time_in_utc)
end

def get_tagged_dimensions(local_time)
  tagged_dimensions = { 'all_time' => 0 }
  dimensions = get_dimensions(local_time)
  dimensions.each do |key, value|
    tagged_dimensions[key] = get_dimension_tag(key, dimensions)
  end
  tagged_dimensions
end

def get_dimensions(local_time)
  {
    'year'       => local_time.year,
    'month'      => local_time.month,
    'day'        => local_time.day,
    'week'       => local_time.strftime('%U').to_i,
    'yday'        => local_time.yday,
    'hour'       => local_time.hour,
    '5minute'    => ( ( local_time.min * 2) / 10 ) * 5,
    '10minute'   => local_time.min / 10 * 10,
    '15minute'   => local_time.min / 15 * 15,
    '30minute'   => local_time.min / 30 * 30,
  }
end

def get_dimension_tag(dimension, t)

  r = nil
  r = Time.utc(t['year'])                                                            if dimension == 'year'
  r = Time.utc(t['year'], t['month'])                                                if dimension == 'month'
  r = Time.utc(t['year'], t['month'], t['day'])                                      if dimension == 'day'
  r = Time.utc(t['year'], t['month'], t['day'], t['hour'])                           if dimension == 'hour'

  r = Time.utc(t['year'], t['month'], t['day'], t['hour'], t['5minute'])             if dimension == '5minute'
  r = Time.utc(t['year'], t['month'], t['day'], t['hour'], t['10minute'])            if dimension == '10minute'
  r = Time.utc(t['year'], t['month'], t['day'], t['hour'], t['15minute'])            if dimension == '15minute'
  r = Time.utc(t['year'], t['month'], t['day'], t['hour'], t['30minute'])            if dimension == '30minute'

  r = Time.utc(t['year']) + (t['yday']-1) * 24 * 60 * 60                             if dimension == 'yday'

  if dimension == 'week'
    r = Time.utc(t['year'])
    while (r.strftime('%U').to_i < t['week'])
      r = r + 24 * 60 * 60
    end
  end

  r.to_i

end

def summary_sql(data_store, dimension, tag, source)
  "select count(reading) as _count, sum(reading) as _sum, avg(reading) as _avg, max(reading) as _max, min(reading) as _min from #{data_store}.readings where source = '#{source}'" + (tag==0 ? '' : " and #{dimension} = #{tag}")
end

def summary_history_sql(data_store, dimension, source)
  "select #{dimension}, min(local_time) as _local_time, " \
    + "count(reading) as _count, sum(reading) as _sum, avg(reading) as _avg, max(reading) as _max, min(reading) as _min " \
    + "from #{data_store}.readings " \
    + "where source = '#{source}' " \
    + "group by #{dimension} " \
    + "order by _local_time desc " \
    + "limit #{CACHED_HISTORY_ITEMS}"
end

def reading_reasonable(payload)
  reasonable = true
  converted_value = payload['converted_value']
  if MONITORS[payload['source']][:range]
    reasonable = false if converted_value < MONITORS[payload['source']][:range][:min] || converted_value > MONITORS[payload['source']][:range][:max]
  else
    if MONITORS[payload['source']][:monitor_type] == :pulse
      threshold = @cache.get("#{payload['data_store']}.outlier.#{payload['source']}.threshold")
      reasonable = false if (threshold && (converted_value > threshold)) || converted_value < 0
    end
  end
  unless payload['source']=='outlier'
    unless reasonable
      outlier_message = { 'received' => payload['received'], 'packet' => "outlier 1" }.to_json
      @exchange.publish outlier_message, :routing_key => 'udp_handler'
    end
  end
  p "Outlier / rejection: #{payload['source']}" unless reasonable
  reasonable
end

def initialise_monitors
  @cache.set("monitors", MONITORS)
  pp @cache.get("monitors")
end

orchestrate
