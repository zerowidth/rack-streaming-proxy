require 'uri'
require 'net/https'

class Rack::StreamingProxy::Session

  def initialize(destination_uri, piper)
    @proxy_session = Net::HTTP.new(destination_uri.host, destination_uri.port)
    @proxy_session.use_ssl = destination_uri.is_a? URI::HTTPS
    @piper = piper
  end

  def start(proxy_request)
    @proxy_session.start do |session|
      Rack::StreamingProxy::Proxy.log :debug, "Child starting request to #{session.inspect}"

      # Retry the request up to self.class.num_5xx_retries times if a 5xx is experienced.
      # This is because Heroku sometimes gives spurious 500/503 errors that resolve themselves quickly.
      # do...while loop as suggested by Matz: http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/6745
      retries = 1
      stop = false
      loop do
        session.request(proxy_request) do |response|
          # at this point the headers and status are available, but the body has not yet been read.

          Rack::StreamingProxy::Proxy.log :debug, "Child got response: #{response.inspect}"

          if response.class <= Net::HTTPServerError # Includes Net::HTTPServiceUnavailable, Net::HTTPInternalServerError
            if retries <= Rack::StreamingProxy::Proxy.num_5xx_retries
              Rack::StreamingProxy::Proxy.log :warn, "Child got 5xx, retrying (Retry ##{retries})"
              sleep 1
              retries += 1
              next
            end
          end

          # Start putting the body in the parent's pipe.
          write_response(response)
          stop = true
        end

        break if stop
      end
    end
  end

private

  def write_response(response)
    response_headers = {}
    response.each_header { |key, value| response_headers[key] = value }

    if response.code.to_i
      Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} returning Status = #{response.code.to_i}."
    else
      Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} unexpectedly has a Nil Status!"
    end

    @piper.puts response.code.to_i
    @piper.puts response.class.body_permitted?
    @piper.puts response_headers
    response.read_body { |chunk| @piper.puts chunk }
    @piper.puts :done
  end

end
