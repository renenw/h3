module MRTG_Handlers

	def on_receive_mrtg(payload)
		# "packet"=>"bandwidth 1330463695 2198531 2374663"
		data = payload['packet'].scan(/[\w\.]+/)
	  inbound = data[2]
	  outbound = data[3]
	  inbound_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_in #{inbound}" }.to_json
	  outbound_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_out #{outbound}" }.to_json
	  combined_message = { 'received' => payload['received'], 'packet' => "#{payload['source']}_total #{outbound.to_i + inbound.to_i}" }.to_json
	  @exchange.publish inbound_message, :routing_key => 'udp_message_received'  
	  @exchange.publish outbound_message, :routing_key => 'udp_message_received'
	  @exchange.publish combined_message, :routing_key => 'udp_message_received'
	  nil
	end

end