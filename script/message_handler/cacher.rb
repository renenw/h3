require 'dalli'

class Cacher

  def initialize(master)
    @master = Dalli::Client.new(master)
  end

  def set(key, value, ttl=nil, options=nil)
    @master.set(key, value, ttl, options)
  end

  def get(key, options=nil)
    @master.get(key, options)
  end

  def fetch(key, ttl=nil, options=nil)
    @master.fetch(key, ttl, options)
  end

  def incr(key, amt=1, ttl=nil, default=nil)
    @master.incr(key, amt, ttl, default)
  end

  def array_append(key, value, size)
    n = @master.incr(key, 1, nil, 0)
    @master.set("#{key}.#{ n % size }", value)
    @master.set("#{key}.size", size)
  end

  def get_multi(*keys)
    @master.get_multi(keys)
  end

  def array_get(key, limit = nil)
    result = []
    size = @master.get("#{key}.size")
    if size
      n = @master.get(key).to_i
      limit = size unless limit
      keys = []
      limit.to_i.times do |i|
        keys << "#{key}.#{n % size}"
        n = n - 1
      end
      @master.get_multi(keys).map do |k,v|
        result << v
      end
    end
    result
  end

end
