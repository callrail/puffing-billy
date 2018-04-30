require 'forwardable'

module Billy
  class RequestHandler
    extend Forwardable
    include Handler

    def_delegators :stub_handler, :stub, :unstub

    def handlers
      @handlers ||= { stubs: StubHandler.new,
                      cache: CacheHandler.new,
                      proxy: ProxyHandler.new }
    end

    def handle_request(method, url, headers, body)
      # Process the handlers by order of importance
      [:stubs, :cache, :proxy].each do |key|
        if (response = handlers[key].handle_request(method, url, headers, body))
          return response
        end
      end

      body_msg = Billy.config.cache_request_body_methods.include?(method) ? " with body '#{body}'" : ''
      { error: "Connection to #{url}#{body_msg} not cached and new http connections are disabled" }
    rescue => error
      { error: error.message }
    end

    def handles_request?(method, url, headers, body)
      [:stubs, :cache, :proxy].any? do |key|
        handlers[key].handles_request?(method, url, headers, body)
      end
    end

    def stubs
      stub_handler.stubs
    end

    def reset
      handlers.each_value(&:reset)
    end

    def reset_stubs
      stub_handler.reset
    end

    def reset_cache
      handlers[:cache].reset
    end

    def restore_cache
      warn '[DEPRECATION] `restore_cache` is deprecated as cache files are dynamically checked. Use `reset_cache` if you just want to clear the cache.'
      reset_cache
    end

    private

    def stub_handler
      handlers[:stubs]
    end
  end
end
