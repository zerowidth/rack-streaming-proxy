require 'uri'
require 'net/https'
require 'servolux'
require 'rack/streaming_proxy/errors'

class Rack::StreamingProxy::Session

  def initialize(request)
    @request = request
  end

  # Returns a Rack::StreamingProxy::Response
  def start
    @piper = Servolux::Piper.new 'r', timeout: 30
    @piper.child  { child }
    @piper.parent { parent }
  end

private

  def child
    begin
      Rack::StreamingProxy::Proxy.log :debug, "Child starting request to #{@request.uri}"
      perform_request

    rescue Exception => e
      # Rescue all exceptions to help with development and debugging, as otherwise when exceptions
      # occur the child process doesn't crash the parent process. Normally rescuing from Exception is a bad idea,
      # but it's the only way to get a stacktrace here for all exceptions including SyntaxError etc,
      # and we are simply passing it on so catastrophic exceptions will still be raised up the chain.
      Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} passing on #{e.class}: #{e.message}"
      @piper.puts e # Pass on the exception to the parent.

    ensure
      Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} closing connection."
      @piper.close

      Rack::StreamingProxy::Proxy.log :info, "Child process #{Process.pid} exiting."
      exit!(0) # child needs to exit, always.
    end
  end

  def parent
    Rack::StreamingProxy::Proxy.log :info, "Parent process #{Process.pid} forked a child process #{@piper.pid}."

    response = Rack::StreamingProxy::Response.new(@piper)
    return response
  end

  def perform_request
    http_session = Net::HTTP.new(@request.host, @request.port)
    http_session.use_ssl = @request.use_ssl?

    http_session.start do |session|
      # Retry the request up to self.class.num_retries_on_5xx times if a 5xx is experienced.
      # This is because some 500/503 errors resolve themselves quickly, might as well give it a chance.
      # do...while loop as suggested by Matz: http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/6745
      retries = 1
      stop = false
      loop do
        session.request(@request.http_request) do |response|
          # At this point the headers and status are available, but the body has not yet been read.
          Rack::StreamingProxy::Proxy.log :debug, "Child got response: #{response.class.name}"

          if response.class <= Net::HTTPServerError # Includes Net::HTTPServiceUnavailable, Net::HTTPInternalServerError
            if retries <= Rack::StreamingProxy::Proxy.num_retries_on_5xx
              Rack::StreamingProxy::Proxy.log :info, "Child got #{response.code}, retrying (Retry ##{retries})"
              sleep 1
              retries += 1
              next
            end
          end
          stop = true

          Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} returning Status = #{response.code}."

          process_response(response)
        end

        break if stop
      end
    end
  end

  def process_response(response)

    # Raise an exception if the raise_on_5xx config is set, and the response is a 5xx.
    # Otherwise continue and put the error body in the pipe. (e.g. Apache error page, for example)
    if response.class <= Net::HTTPServerError && Rack::StreamingProxy::Proxy.raise_on_5xx
      raise Rack::StreamingProxy::HttpServerError.new "Got a #{response.class.name} (#{response.code}) response while proxying to #{@request.uri}"
    end

    # Put the response in the parent's pipe.
    @piper.puts response.code
    @piper.puts response.class.body_permitted?

    # Could potentially use a one-liner here:
    # @piper.puts Hash[response.to_hash.map { |key, value| [key, value.join(', ')] } ]
    # But the following three lines seem to be more readable.
    # Watch out: response.to_hash and response.each_header returns in different formats!
    # to_hash requires the values to be joined with a comma.
    headers = {}
    response.each_header { |key, value| headers[key] = value }
    log_headers :debug, 'Proxy Response Headers:', headers
    @piper.puts headers

    response.read_body { |chunk| @piper.puts chunk }
    @piper.puts :done
  end

  def log_headers(level, title, headers)
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
    Rack::StreamingProxy::Proxy.log level, "| #{title}"
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
    headers.each { |key, value| Rack::StreamingProxy::Proxy.log level, "| #{key} = #{value.to_s}" }
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
  end

end
