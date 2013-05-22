require 'uri'
require 'net/https'
require 'servolux'

class Rack::StreamingProxy::Session

  def initialize(request)
    @request = request
  end

  def start
    @piper = Servolux::Piper.new 'r', timeout: 30
    @piper.child  { child }
    @piper.parent { parent }
  end

private

  def child
    begin
      perform_request

    rescue Exception => e
      # Rescue all exceptions and dump stacktrace to help with development and debugging, as
      # otherwise when exceptions occur the child process doesn't crash the parent process,
      # and no stack trace is generated. Rescuing the full slate of Exceptions for this purpose.
      Rack::StreamingProxy::Proxy.log :error, "Child process rescued #{e.class}: #{e.message}"
      e.backtrace.each { |line| Rack::StreamingProxy::Proxy.log :error, line }

    ensure
      Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} closing connection."
      @piper.close

      Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} exiting."
      exit!(0) # child needs to exit, always.
    end
  end

  def parent
    Rack::StreamingProxy::Proxy.log :debug, "Parent process #{Process.pid} forked a child process #{@piper.pid}."

    response = Rack::StreamingProxy::Response.new(@piper)
    response.receive
    return response
  end

  def perform_request
    http_session = Net::HTTP.new(@request.host, @request.port)
    http_session.use_ssl = @request.use_ssl?

    http_session.start do |session|
      Rack::StreamingProxy::Proxy.log :debug, "Child starting request to #{session.inspect}"

      # Retry the request up to self.class.num_retries_on_5xx times if a 5xx is experienced.
      # This is because some 500/503 errors resolve themselves quickly, might as well give it a chance.
      # do...while loop as suggested by Matz: http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/6745
      retries = 1
      stop = false
      loop do
        Rack::StreamingProxy::Proxy.log :debug, "Session #{session.inspect}"
        Rack::StreamingProxy::Proxy.log :debug, "Request #{@request.inspect}"

        session.request(@request.http_request) do |response|
          # At this point the headers and status are available, but the body has not yet been read.
          Rack::StreamingProxy::Proxy.log :debug, "Child got response: #{response.inspect}"

          if response.class <= Net::HTTPServerError # Includes Net::HTTPServiceUnavailable, Net::HTTPInternalServerError
            if retries <= Rack::StreamingProxy::Proxy.num_retries_on_5xx
              Rack::StreamingProxy::Proxy.log :warn, "Child got #{response.code}, retrying (Retry ##{retries})"
              sleep 1
              retries += 1
              next
            end
          end
          stop = true

          if response.code
            Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} returning Status = #{response.code}."
          else
            Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} unexpectedly has a Nil Status!"
          end

          # Put the response in the parent's pipe.
          write_response(response)
        end

        break if stop
      end
    end
  end

  def write_response(response)
    @piper.puts response.code
    @piper.puts response.class.body_permitted?

    # Could potentially use a one-liner here:
    # @piper.puts Hash[response.to_hash.map { |key, value| [key, value.join(', ')] } ]
    # But the following three lines seem to be more readable.
    # Watch out: response.to_hash and response.each_header returns in different formats!
    # to_hash requires the values to be joined with a comma.
    headers = {}
    response.each_header { |key, value| headers[key] = value }
    @piper.puts headers

    response.read_body { |chunk| @piper.puts chunk }
    @piper.puts :done
  end

end
