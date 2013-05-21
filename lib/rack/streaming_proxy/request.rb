require 'uri'
require 'net/https'
require 'servolux'
require 'rack/streaming_proxy/session'

class Rack::StreamingProxy::Request

  class Error < RuntimeError; end

  def initialize(destination_uri, current_request)
    @destination_uri = URI.parse(destination_uri)
    @proxy_request   = construct_proxy_request(current_request, @destination_uri)
  end

  def start
    @piper = Servolux::Piper.new 'r', timeout: 30

    @piper.child do
      begin
        proxy_session = Rack::StreamingProxy::Session.new(@destination_uri, @piper)
        proxy_session.start(@proxy_request)

      ensure
        Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} closing connection."
        @piper.close

        Rack::StreamingProxy::Proxy.log :debug, "Child process #{Process.pid} exiting."
        exit!(0) # child needs to exit, always.
      end
    end

    @piper.parent do
      Rack::StreamingProxy::Proxy.log :debug, "Parent process #{Process.pid} forked a child process #{@piper.pid}."

      response = Rack::StreamingProxy::Response.new(@piper)
      response.receive
      return response
    end

  #rescue RuntimeError => e
  #  Rack::StreamingProxy::Proxy.log :debug, "Parent process #{Process.pid} rescued #{e.class}."
  #  finish_request
  #  raise

  end

private

  def construct_proxy_request(current_request, uri)
    method = current_request.request_method.downcase
    method[0..0] = method[0..0].upcase

    proxy_request = Net::HTTP.const_get(method).new("#{uri.path}#{"?" if uri.query}#{uri.query}")

    if proxy_request.request_body_permitted? and current_request.body
      proxy_request.body_stream    = current_request.body
      proxy_request.content_length = current_request.content_length if current_request.content_length
      proxy_request.content_type   = current_request.content_type   if current_request.content_type
    end

    log_headers :debug, 'Current Request Headers', current_request.env

    current_headers = current_request.env.reject { |env_key, env_val| !(env_key.match /^HTTP_/) }
    current_headers.each do |name, value|
      fixed_name = name.sub(/^HTTP_/, '').gsub('_', '-')
      proxy_request[fixed_name] = value unless fixed_name.downcase == 'host'
    end
    proxy_request['X-Forwarded-For'] = (current_request.env['X-Forwarded-For'].to_s.split(/, +/) + [current_request.env['REMOTE_ADDR']]).join(', ')

    log_headers :debug, 'Proxy Request Headers:', proxy_request

    proxy_request
  end

  def log_headers(level, title, headers)
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
    Rack::StreamingProxy::Proxy.log level, "| #{title}"
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
    headers.each { |key, value| Rack::StreamingProxy::Proxy.log level, "| #{key} = #{value}" }
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
  end

end
