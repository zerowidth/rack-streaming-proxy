require 'rack/streaming_proxy'
require 'rails'

class Rack::StreamingProxy::Railtie < Rails::Railtie

  config.streaming_proxy = ActiveSupport::OrderedOptions.new

  config.after_initialize do |app|
    Rack::StreamingProxy.logger = config.streaming_proxy.logger
  end
end
