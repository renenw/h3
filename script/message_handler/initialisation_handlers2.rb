module Initialisation_Handlers

	# an opportunity to rewrite messages, ditch them etc
	def udp_message_received(payload)
	  p "New message: #{payload}" if payload =~ /alarm/
	  data = payload['packet'].scan(/[\w\.]+/)
	  if data && data[0] && MONITORS[data[0]]
	    source_type = MONITORS[data[0]][:monitor_type]
	    if source_type
	      payload.merge(
                        { 'data_store' => DATA_STORE,
                          'source' => data[0],
                          'source_type' => source_type.to_s
                         }
	                    )
	    end
	  else
	    recent_reading = {
	                       'local_time' => get_local_time(SETTINGS['timezone'], Time.at(payload['received'].to_f)).to_f*1000,
	                       'Unknown' => true,
	                       'payload' => payload,
	                     }
	    @cache.array_append("30_camp_ground_road.anomoly_log", recent_reading, PAYLOAD_HISTORY_ITEMS)
	    p "Unknown: #{recent_reading}"
	  end
	  payload
	end

	def udp_message_received_destination_queue(payload)
		next_handler = nil
		next_handler = ( payload['source'] == :mrtg ? 'handle_mrtg_pre_processing' : 'initialise_structured_message') if payload
		next_handler
	end

end