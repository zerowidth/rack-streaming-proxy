require 'uri'
require 'net/https'

class Rack::StreamingProxy::Request

  attr_reader :http_request

  def initialize(destination_uri, current_request)
    @destination_uri = URI.parse(destination_uri)
    @http_request    = translate_request(current_request, @destination_uri)
  end

  def host
    @destination_uri.host
  end

  def port
    @destination_uri.port
  end

  def use_ssl?
    @destination_uri.is_a? URI::HTTPS
  end

private

  def translate_request(current_request, uri)
    method = current_request.request_method.downcase
    method[0..0] = method[0..0].upcase

    request = Net::HTTP.const_get(method).new("#{uri.path}#{"?" if uri.query}#{uri.query}")

    if request.request_body_permitted? and current_request.body
      request.body_stream    = current_request.body
      request.content_length = current_request.content_length if current_request.content_length
      request.content_type   = current_request.content_type   if current_request.content_type
    end

    log_headers :debug, 'Current Request Headers', current_request.env

    current_headers = current_request.env.reject { |env_key, env_val| !(env_key.match /^HTTP_/) }
    current_headers.each do |name, value|
      fixed_name = name.sub(/^HTTP_/, '').gsub('_', '-')
      request[fixed_name] = value unless fixed_name.downcase == 'host'
    end
    request['X-Forwarded-For'] = (current_request.env['X-Forwarded-For'].to_s.split(/, +/) + [current_request.env['REMOTE_ADDR']]).join(', ')

    log_headers :debug, 'Proxy Request Headers:', request

    request
  end

  def log_headers(level, title, headers)
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
    Rack::StreamingProxy::Proxy.log level, "| #{title}"
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
    headers.each { |key, value| Rack::StreamingProxy::Proxy.log level, "| #{key} = #{value.to_s}" }
    Rack::StreamingProxy::Proxy.log level, "+-------------------------------------------------------------"
  end

end
