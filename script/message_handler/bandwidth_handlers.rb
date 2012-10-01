module Bandwidth_Handlers

	def on_receive_bandwidth_throughput(payload)
		# bandwidth_throughput 2048000 11.957 8.910 10.240 7.783
		data = payload['packet'].scan(/[\w\.]+/)

	  size = data[1].to_i
	  tests = data.length - 2

	  duration = 0.0
	  data.each_index do |i|
	  	duration += data[i].to_f if i > 1
	  end

	  bps = ((size*tests) / duration).round.to_i

	  mean  = duration / tests
	  var   = 0
	  data.each_index do |i|
	  	var += (data[i].to_f - mean)**2 if i > 1
	  end
	  stddev = (var / tests)**0.5

	  bps_message = { 'received' => payload['received'], 'packet' => "bandwidth_bps #{bps}" }.to_json
	  qos_message = { 'received' => payload['received'], 'packet' => "bandwidth_qos #{stddev}" }.to_json
	  
	  @exchange.publish bps_message, :routing_key => 'udp_message_received'  
	  @exchange.publish qos_message, :routing_key => 'udp_message_received'

	  nil

	end

end