require 'rails/railtie'

class Rack::StreamingProxy::Railtie < Rails::Railtie

  config.streaming_proxy = ActiveSupport::OrderedOptions.new

  config.after_initialize do
    options = config.streaming_proxy
    Rack::StreamingProxy::Proxy.logger             = options.logger             if options.logger
    Rack::StreamingProxy::Proxy.log_verbosity      = options.log_verbosity      if options.log_verbosity
    Rack::StreamingProxy::Proxy.num_retries_on_5xx = options.num_retries_on_5xx if options.num_retries_on_5xx
    Rack::StreamingProxy::Proxy.raise_on_5xx       = options.raise_on_5xx       if options.raise_on_5xx
  end
end
