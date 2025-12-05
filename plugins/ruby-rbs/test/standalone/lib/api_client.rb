# Class with overloaded methods and nilable returns

class ApiClient
  attr_reader :base_url, :timeout

  def initialize(base_url, timeout: 30)
    @base_url = base_url
    @timeout = timeout
    @cache = {}
  end

  def get(path)
    @cache[path]
  end

  def fetch(path)
    if result = @cache[path]
      result
    else
      raise KeyError, "Not found: #{path}"
    end
  end

  def set(path, value)
    @cache[path] = value
  end

  def clear
    @cache.clear
  end

  def cached_paths
    @cache.keys
  end
end
