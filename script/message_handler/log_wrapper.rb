require 'logger'

class Log_Wrapper
	
	def initialize
		@log   = Logger.new('log.txt', 10, 1024000)
	end

	# loggers, taking a message arg[0], and arg[1]
	# if arg[1] is a hash, it is probed for a guid
	def method_missing(method, *args)
		@log.__send__(method, caller[0][/`([^']*)'/, 1]) do
			guid, hash = nil
			guid = args[1]['guid'] if args[1] && args[1].is_a?(Hash)
			hash = args[1].to_s if args[1]
			"#{guid} | #{args[0]} | #{hash}"
		end
		p args[0] unless method == :debug
  end

  def build_message
  end

end