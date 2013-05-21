require 'rails/railtie'

class Rack::StreamingProxy::Railtie < Rails::Railtie

  config.streaming_proxy = ActiveSupport::OrderedOptions.new

  config.after_initialize do |app|
    # If no logger is passed in, then writes to stdout by default.
    Rack::StreamingProxy::Proxy.logger = config.streaming_proxy.logger

    # 0 by default, i.e. No retries are performed.
    Rack::StreamingProxy::Proxy.num_5xx_retries = config.streaming_proxy.num_5xx_retries
  end
end
