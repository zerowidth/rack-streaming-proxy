require 'rails/railtie'

class Rack::StreamingProxy::Railtie < Rails::Railtie

  config.streaming_proxy = ActiveSupport::OrderedOptions.new

  config.after_initialize do |app|
    Rack::StreamingProxy::Proxy.logger = config.streaming_proxy.logger
  end
end
