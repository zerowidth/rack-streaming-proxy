require 'uri'
require 'net/https'
require 'servolux'

class Rack::StreamingProxy::Request
  include Rack::Utils # For HeaderHash

  class Error < RuntimeError; end

  class << self
    attr_accessor :num_5xx_retries
  end

  attr_reader :status, :headers

  def initialize(proxy_uri, current_request, logger)
    # No retries are performed be default.
    self.class.num_5xx_retries ||= 0

    @uri           = URI.parse(proxy_uri)
    @proxy_request = construct_proxy_request(current_request, @uri)
    @logger        = logger
    @piper         = Servolux::Piper.new 'r', timeout: 30
  end

  def start
    @logger.info "Proxying to: #{@uri.to_s}"

    #@logger.debug '[Rack::StreamingProxy] Proxy Request Headers:'
    #@proxy_request.each_header {|h,v| @logger.debug "[Rack::StreamingProxy] #{h} = #{v}"}
    @piper.child do
      begin
        http_req = Net::HTTP.new(@uri.host, @uri.port)
        http_req.use_ssl = @uri.is_a?(URI::HTTPS)

        http_req.start do |http|
          @logger.info "[Rack::StreamingProxy] Child starting request to #{http.inspect}"

          # Retry the request up to self.class.num_5xx_retries times if a 5xx is experienced.
          # This is because Heroku sometimes gives spurious 500/503 errors that resolve themselves quickly.
          # do...while loop as suggested by Matz: http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/6745
          retries = 1
          stop = false
          loop do
            http.request(@proxy_request) do |response|
              # at this point the headers and status are available, but the body has not yet been read.

              @logger.info "[Rack::StreamingProxy] Child got response: #{response.inspect}"

              #if [Net::HTTPServiceUnavailable, Net::HTTPInternalServerError].include? response.class

              if response.class <= Net::HTTPServerError
                if retries <= self.class.num_5xx_retries
                  @logger.info "[Rack::StreamingProxy] Child got 5xx, retrying (Retry ##{retries})"
                  sleep 1
                  retries += 1
                  next
                end
              end

              # Start putting the body in the parent's pipe.
              write_from_child(response)
              stop = true
            end

            break if stop
          end
        end

      ensure
        @logger.info "[Rack::StreamingProxy] Child process #{Process.pid} closing connection."
        @piper.close

        @logger.info "[Rack::StreamingProxy] Child process #{Process.pid} exiting."
        exit!(0) # child needs to exit, always.
      end
    end

    @piper.parent do
      @logger.info "[Rack::StreamingProxy] Parent process #{Process.pid} forked a child process #{@piper.pid}."
      # wait for the status and headers to come back from the child

      if @status = read_from_child
        @logger.info "[Rack::StreamingProxy] Parent received: Status = #{@status}."

        @body_permitted = read_from_child
        @logger.info "[Rack::StreamingProxy] Parent received: Reponse has body? = #{@body_permitted}."

        @headers = HeaderHash.new(read_from_child)

        # If there is a body, finish_request will be called inside each.
        finish_request if !@body_permitted
      else
        @logger.info "[Rack::StreamingProxy] Parent received unexpected nil status!"
        finish_request
        raise Error
      end
    end

  #rescue RuntimeError => e
  #  @logger.info "[Rack::StreamingProxy] Parent process #{Process.pid} rescued #{e.class}."
  #  finish_request
  #  raise

  end

  # This method is called by Rack itself, to iterate over the proxied contents.
  def each
    if @body_permitted
      chunked = @headers['Transfer-Encoding'] == 'chunked'
      term = '\r\n'

      while chunk = read_from_child
        break if chunk == :done
        if chunked
          size = bytesize(chunk)
          next if size == 0
          yield [size.to_s(16), term, chunk, term].join
        else
          yield chunk
        end
      end

      finish_request

      yield ['0', term, '', term].join if chunked
    end
  end

private

  def finish_request
    # parent needs to wait for the child, or it results in the child process becoming defunct, resulting in zombie processes!
    @logger.info "[Rack::StreamingProxy] Parent process #{Process.pid} waiting for child process #{@piper.pid} to exit."
    @piper.wait
  end

  def write_from_child(response)
    response_headers = {}
    response.each_header {|k,v| response_headers[k] = v}

    if response.code.to_i
      @logger.info "[Rack::StreamingProxy] Child process #{Process.pid} returning Status = #{response.code.to_i}."
    else
      @logger.info "[Rack::StreamingProxy] Child process #{Process.pid} unexpectedly has a Nil Status!"
    end

    @piper.puts response.code.to_i
    @piper.puts response.class.body_permitted?
    @piper.puts response_headers
    response.read_body { |chunk| @piper.puts chunk }
    @piper.puts :done
  end

  def read_from_child
    @piper.gets
  end

  def construct_proxy_request(current_request, uri)
    method = current_request.request_method.downcase
    method[0..0] = method[0..0].upcase

    proxy_request = Net::HTTP.const_get(method).new("#{uri.path}#{"?" if uri.query}#{uri.query}")

    if proxy_request.request_body_permitted? and current_request.body
      proxy_request.body_stream    = current_request.body
      proxy_request.content_length = current_request.content_length if current_request.content_length
      proxy_request.content_type   = current_request.content_type   if current_request.content_type
    end

    current_headers = current_request.env.reject {|env_key, env_val| !(env_key.match /^HTTP_/) }
    current_headers.each { |name, value|
      fixed_name = name.sub(/^HTTP_/, '').gsub('_', '-')
      # @logger.debug "Setting proxy header #{name} to #{value} using #{fixed_name}"
      proxy_request[fixed_name] = value unless fixed_name.downcase == 'host'
    }
    proxy_request['X-Forwarded-For'] = (current_request.env['X-Forwarded-For'].to_s.split(/, +/) + [current_request.env['REMOTE_ADDR']]).join(', ')

    proxy_request
  end

end
