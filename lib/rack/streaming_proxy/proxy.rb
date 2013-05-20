require 'rack'
require 'logger'
require 'rack/streaming_proxy/request'

class Rack::StreamingProxy::Proxy

  class Error < RuntimeError; end

  # Class instance variable for the logger.
  # Note that all instances of the Rack::StreamingProxy::Proxy class will share this logger.
  class << self
    attr_accessor :logger
  end

  # The block provided to the initializer is given a Rack::Request
  # and should return:
  #
  #   * nil/false to skip the proxy and continue down the stack
  #   * a complete uri (with query string if applicable) to proxy to
  #
  # E.g.
  #
  #   use Rack::StreamingProxy::Proxy do |req|
  #     if req.path.start_with?('/search')
  #       "http://some_other_service/search?#{req.query}"
  #     end
  #   end
  #
  # Most headers, request body, and HTTP method are preserved.
  #
  def initialize(app, &block)
    @@logger ||= Logger.new(STDOUT)

    @app   = app
    @block = block
  end

  def call(env)
    current_request = Rack::Request.new(env)

    # Decide whether this request should be proxied.
    if proxy_uri = @block.call(current_request)

      #begin
      proxied_request = Rack::StreamingProxy::Request.new(proxy_uri, current_request, self.class.logger)
      proxied_request.start
      [proxied_request.status, proxied_request.headers, proxied_request]

      #rescue RuntimeError => e # only want to catch proxy errors, not app errors
      #  msg = "Proxy error when proxying to #{uri}: #{e.class}: #{e.message}"
      #  env['rack.errors'].puts msg
      #  env['rack.errors'].puts e.backtrace.map { |l| "\t" + l }
      #  env['rack.errors'].flush
      #  raise Error, msg
      #end

    # Continue down the middleware stack if the request is not to be proxied.
    else
      @app.call(env)
    end
  end

end
