module Weather_Handlers

	def on_receive_weather_forecast(payload)
		p payload
		payload['packet'] = 'weather_forecast 1'
		p payload
		payload
	end

end