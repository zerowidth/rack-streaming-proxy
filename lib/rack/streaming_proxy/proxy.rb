require 'rack'
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
    @request_uri = block
    @app = app
  end

  def call(env)
    req = Rack::Request.new(env)

    unless uri = request_uri.call(req)
      code, headers, body = app.call(env)
      unless headers['X-Accel-Redirect']
        return [code, headers, body]
      else
        proxy_env = env.merge('PATH_INFO' => headers['X-Accel-Redirect'])
        unless uri = request_uri.call(Rack::Request.new(proxy_env))
          raise "Could not proxy #{headers['X-Accel-Redirect']}: Path does not map to any uri"
        end
      end
    end

    #begin
    proxy = Rack::StreamingProxy::Request.new(req, uri, self.class.logger)
    [proxy.status, proxy.headers, proxy]
    #rescue RuntimeError => e # only want to catch proxy errors, not app errors
    #  msg = "Proxy error when proxying to #{uri}: #{e.class}: #{e.message}"
    #  env['rack.errors'].puts msg
    #  env['rack.errors'].puts e.backtrace.map { |l| "\t" + l }
    #  env['rack.errors'].flush
    #  raise Error, msg
    #end
  end

private

  attr_reader :request_uri, :app

end
