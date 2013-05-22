require 'rack'
require 'logger'
require 'rack/streaming_proxy/session'
require 'rack/streaming_proxy/request'
require 'rack/streaming_proxy/response'

class Rack::StreamingProxy::Proxy

  class Error < RuntimeError; end

  class << self
    attr_accessor :logger, :log_verbosity, :num_retries_on_5xx, :raise_on_5xx

    def set_default_configuration
      # Logs to stdout by default unless configured with another logger via Railtie.
      @logger ||= Logger.new(STDOUT)

      # At :low verbosity by default -- will not output :debug level messages.
      # :high verbosity outputs :debug level messages.
      # This is independent of the Logger's log_level, as set in Rails, for example,
      # although the Logger's level can override this setting.
      @log_verbosity ||= :low

      # No retries are performed by default.
      @num_retries_on_5xx ||= 0

      # If the proxy cannot recover from 5xx's through retries (see num_retries_on_5xx),
      # then it by default passes through the content from the destination
      # e.g. the Apache error page. If you want an exception to be raised instead so
      # you can handle it yourself (i.e. display your own error page), set raise_on_5xx to true.
      @raise_on_5xx ||= false
    end

    def log(level, message)
      #puts "log_verbosity = #{@log_verbosity}, num_retries_on_5xx = #{@num_retries_on_5xx}, raise_on_5xx = #{@raise_on_5xx}"

      @logger.send level, "[Rack::StreamingProxy] #{message}" unless log_verbosity == :low && level == :debug
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
    self.class.set_default_configuration
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
