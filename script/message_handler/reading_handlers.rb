require './websocket'

module Reading_Handlers

	include Websocket

	def reading(payload)
		reasonable = reading_reasonable(payload)
	  sql_error = nil
	  if reasonable
	    t = payload['dimensions']
	    begin
	      @mysql.query "insert into #{payload['data_store']}.readings (source, local_time, reading, year, month, week, day, hour, 5minute, 10minute, 15minute, 30minute, yday) values ('#{payload['source']}', #{payload['local_time']}, #{payload['converted_value']}, #{t['year']}, #{t['month']}, #{t['week']}, #{t['day']}, #{t['hour']}, #{t['5minute']}, #{t['10minute']}, #{t['15minute']}, #{t['30minute']}, #{t['yday']})"
	    rescue #should only really be catching the error on the sql
	      sql_error = $!
	    end
	  else
	    @mysql.query "insert into #{payload['data_store']}.outliers (event_id) values (#{payload['event_id']})"
	  end

	  recent_reading = {
	                     'local_time' => payload['local_time']*1000,
	                     'reading' => payload['converted_value'],
	                     'source' => payload['source'],
	                     'payload' => payload.select { |k, v| k!='dimensions'  },
	                     'outlier' => !reasonable,
	                     'sql_error' => sql_error,
	                   }
	  @cache.array_append("#{payload['data_store']}.reading_log", recent_reading, PAYLOAD_HISTORY_ITEMS)

	  broadcast_reading_to_websockets payload

	  if (sql_error || !reasonable)
	    @cache.array_append("#{payload['data_store']}.anomoly_log", recent_reading, ANOMOLOUS_READING_HISTORY)
	  end

	  payload

	end

	def cache_reading(payload)
	  expires = nil
	  expires = payload['received']*1000 + 1.5 * MONITORS[payload['source']][:expected_frequency]*1000 if MONITORS[payload['source']][:expected_frequency] 
	  @cache.set("#{payload['data_store']}.reading.#{payload['source']}", {
	                                                                        'local_time' => payload['local_time']*1000,
	                                                                        'reading' => payload['converted_value'],
	                                                                        'expires' => expires,
	                                                                        'guid' => payload['guid']
	                                                                       })
	end


	def summarisation(payload)
	  data_store = payload['data_store']
	  reading    = payload['converted_value']
	  source     = payload['source']
	  local_time = payload['local_time'].to_i

	  summary 	 = {}

	  payload['dimensions'].each do |dimension, tag|
	    cached_entry = get_current_summary_cache_entry(data_store, source, dimension, tag, reading)
	    history = update_summary_history_cache(data_store, source, dimension, tag, cached_entry) if dimension != 'all_time'
	    #print_history "#{source} #{dimension}:", history if history && dimension != 'all_time'
	    summary[dimension] = cached_entry
	  end

	  broadcast_dimensions_to_websockets payload, summary

	end

	def handle_history(payload)
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


=begin
	def print_history(description, history)
	  l = ""
	  p description
	  history.each do |e|
	    l = l + " | #{e['tag']} #{e['values']['sum']}"
	    if l.length > 120
	      p l
	      l = ""
	    end
	  end
	  p l
	end
=end

	def calculate_outlier_threshold(payload)

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

	def cache_sources(payload)
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
	  reasonable
	end

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

end