require 'logger'

class Log_Wrapper
	
	def initialize
		@log   = Logger.new('log.txt', 10, 1024000)
	end

	def debug(message)
		p message
		@log.debug message
	end

	def info(message)
		p message
		@log.debug message
	end

	def warn(message)
		p message
		@log.warn message
	end

end