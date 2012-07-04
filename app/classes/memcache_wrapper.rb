class MemcacheWrapper

  include Singleton

  def get_sources
    memcache_connector.get("monitors")
  end

  def get_reading(params, sensor)
    cache_get(params['data_store'], "reading.#{sensor}")
  end

  def get_readings(params)
    get_from_cache(params) do |key|
      "reading.#{key}"
    end
  end

  def get_history(params)
    get_from_cache(params) do |key|
      "history.#{key}"
    end
  end

  def get_sensor_list(params)
    cache_get(params['data_store'], 'sources')
  end

  def get_summaries(params)
    n = (params['n'] || 50).to_i
    summaries = get_from_cache(params) do |key|
      "history.#{key}.#{params['dimension']}"
    end
    summaries.each do |key, values|
      summaries[key] = values.drop( values.length - n ) if values.length > n
    end
    summaries
  end

  def get_summary(params)
    get_from_cache(params) do |key|
      "summary.#{key}.#{params['dimension']}"
    end
  end

  def get_array(array_name, params)
    memcache_connector.array_get("#{params['data_store']}.#{array_name}", params['n'])
  end

  protected

    def memcache_connector
      @cache ||= Cacher.new('localhost:11211')
      @cache
    end

    def get_from_cache(params)
      sources = get_sources_from_params(params) 
      cache_get_multi(params['data_store'], sources) do |key|
        yield(key)
      end
    end

    def get_sources_from_params(params)
      sources = []
      sources << params['source'] if params['source']
      if sources.empty?
        cached_entries = cache_get(params['data_store'], 'sources')
        sources = cached_entries.keys if cached_entries
      end
      sources
    end

    def cache_get(data_store, key)
      key = yield(key) if block_given?
      memcache_connector.get("#{data_store}.#{key}")
    end

    def cache_get_multi(data_store, keys)
      mapped_keys = {}
      keys.each do |key|
        mapped_key = key
        mapped_key = yield(key) if block_given?
        mapped_keys["#{data_store}.#{mapped_key}"] = key
      end
      Hash[memcache_connector.get_multi(mapped_keys.keys).map do |k, v|
        [mapped_keys[k], v] 
      end]
    end

end


