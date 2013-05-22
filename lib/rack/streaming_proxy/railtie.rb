require 'rails/railtie'

class Rack::StreamingProxy::Railtie < Rails::Railtie

  config.streaming_proxy = ActiveSupport::OrderedOptions.new

  config.after_initialize do |app|
    Rack::StreamingProxy::Proxy.logger             = config.streaming_proxy.logger
    Rack::StreamingProxy::Proxy.log_verbosity      = config.streaming_proxy.log_verbosity
    Rack::StreamingProxy::Proxy.num_retries_on_5xx = config.streaming_proxy.num_retries_on_5xx
  end
end
