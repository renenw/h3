module Lifecycle_Handlers

	# an opportunity to rewrite messages, ditch them etc
	# we add some very basic stuff (not that the upstream receiver would have added a timestamp)
	def udp_message_received(payload)
	  data = payload['packet'].scan(/[\w\.]+/)
	  if data && data[0] && MONITORS[data[0]]
	    source_type = MONITORS[data[0]][:monitor_type]
	    if source_type
	      payload.merge!(
                        { 'data_store' => DATA_STORE,
                          'source' => data[0],
                          'source_type' => source_type.to_s
                         }
	                    )
	    end
	  else
	    recent_reading = {
	                       'local_time' => Lifecycle_Handlers_Utils.get_local_time(SETTINGS['timezone'], Time.at(payload['received'].to_f)).to_f*1000,
	                       'Unknown' => true,
	                       'payload' => payload,
	                     }
	    @cache.array_append("30_camp_ground_road.anomoly_log", recent_reading, PAYLOAD_HISTORY_ITEMS)
	    @log.warn "Unknown: #{recent_reading}"
	    payload = nil
	  end
	  payload
	end


	def on_receive(payload)
		on_event('on_receive', payload)
	end

	def after_received(payload)
		on_event('after_received', payload)
	end

	# checks to see if on event methods have been defined for this source type, or this source, and then calls them
	def on_event(event_type, payload)
		type_target = "#{event_type}_#{payload['source_type']}".to_sym
		payload     = __send__(type_target, payload) if respond_to?(type_target)
		if payload
			name_target = "#{event_type}_#{payload['source']}".to_sym
			payload     = __send__(name_target, payload) if respond_to?(name_target)
		end
		payload
	end
	

	# messages should, by this point, have a basic "events" structure (source, number) with a received time that as closely as practically reflects the event time
	def initialise_structured_message(payload)
	  data = payload['packet'].scan(/[\w\.]+/)
	  i = data[1].to_f.round.to_i
	  event_time_in_utc = Time.at(payload['received'].to_f)
	  local_time = Lifecycle_Handlers_Utils.get_local_time(SETTINGS['timezone'], event_time_in_utc)
	  @mysql.query("insert into events (source, float_value, integer_value, created_at) values ('#{data[0]}', #{data[1]}, #{i}, '#{event_time_in_utc.strftime('%Y-%m-%d %H:%M:%S.%6N')}');")
	  event_id = @mysql.last_id
	  payload.merge!(
                    {
                      'local_time' => local_time.to_f,
                      'dimensions' => Lifecycle_Handlers_Utils.get_tagged_dimensions(local_time),
                      'event_id' => event_id,
                      'float_value' => data[1].to_f,
                      'integer_value' => i
                    }
	                )
	end

	class Lifecycle_Handlers_Utils

		def self.get_local_time(timezone, event_time_in_utc)
		  tz = TZInfo::Timezone.get(timezone)
		  tz.utc_to_local(event_time_in_utc)
		end

		def self.get_tagged_dimensions(local_time)
		  tagged_dimensions = { 'all_time' => 0 }
		  dimensions = get_dimensions(local_time)
		  dimensions.each do |key, value|
		    tagged_dimensions[key] = get_dimension_tag(key, dimensions)
		  end
		  tagged_dimensions
		end

		def self.get_dimensions(local_time)
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

		def self.get_dimension_tag(dimension, t)

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

	end

end