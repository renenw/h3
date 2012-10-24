module Websocket

	def broadcast_to_websockets(payload)
		@exchange.publish payload.to_json, :routing_key => 'websocket_broadcast'
	end

	def broadcast_message_to_websockets(message_type, message, payload)
		broadcast_to_websockets :data_store		=> payload['data_store'],
														:source 			=> payload['source'], 
														:message_type => message_type,
														:message 			=> message,
														:guid 				=> payload['guid']
	end

	def broadcast_reading_to_websockets(payload)
		if MONITORS[payload['source']][:websocket] && MONITORS[payload['source']][:websocket][:reading]
			broadcast_to_websockets :data_store		=> payload['data_store'],
															:source 			=> payload['source'], 
															:message_type => 'reading',
															:message 			=> payload['converted_value'],
															:guid 				=> payload['guid']
		end
	end

	def broadcast_dimensions_to_websockets(payload, summary)
		dimensions = MONITORS[payload['source']][:websocket][:dimensions] if MONITORS[payload['source']][:websocket]
		if dimensions
			summary_for_client = {}
			dimensions.each_key do |key|
				summary_for_client[key] = {
					'tag' 	=> summary[key]['tag'],
					'values'	=> {}
				}
				dimensions[key].each do |item|
					summary_for_client[key]['values'][item] = summary[key]['values'][item]
				end
			end
			broadcast_to_websockets :data_store		=> payload['data_store'],
															:source 			=> payload['source'], 
															:message_type => 'dimensions',
															:message 			=> summary_for_client,
															:guid 				=> payload['guid']
		end
	end

end