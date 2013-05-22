require 'rack'
require 'logger'
require 'rack/streaming_proxy/session'
require 'rack/streaming_proxy/request'
require 'rack/streaming_proxy/response'

class Rack::StreamingProxy::Proxy

  class Error < RuntimeError; end

  class << self
    attr_accessor :logger, :log_verbosity, :num_retries_on_5xx

    def log(level, message)
      unless @log_verbosity == :low && level == :debug
        @logger.send level, "[Rack::StreamingProxy] #{message}"
      end
    end
  end

  # The block provided to the initializer is given a Rack::Request
  # and should return:
  #
  #   * nil/false to skip the proxy and continue down the stack
  #   * a complete uri (with query string if applicable) to proxy to
  #
  # Example:
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
    # Logs to stdout by default unless configured with another logger via Railtie.
    self.class.logger ||= Logger.new(STDOUT)

    # At :low verbosity by default -- will not output :debug level messages.
    # :high verbosity outputs :debug level messages.
    # This is independent of the Logger's log_level, as set in Rails, for example,
    # although the Logger's level can override this setting.
    self.class.log_verbosity ||= :low

    # No retries are performed by default.
    self.class.num_retries_on_5xx ||= 0

    @app   = app
    @block = block
  end

  def call(env)
    current_request = Rack::Request.new(env)

    # Decide whether this request should be proxied.
    if destination_uri = @block.call(current_request)
      self.class.log :info, "Starting proxy request to: #{destination_uri}"

      #begin
      request = Rack::StreamingProxy::Request.new(destination_uri, current_request)
      session = Rack::StreamingProxy::Session.new(request)
      response = session.start
      self.class.log :info, "Finishing proxy request to: #{destination_uri}"
      [response.status, response.headers, response]

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
