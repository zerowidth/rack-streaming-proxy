require 'logger'

class Rack::StreamingProxy::ProxyRequest

  class Error < RuntimeError; end

  MAX_503_RETRIES = 5

  include Rack::Utils

  attr_reader :status, :headers

  def initialize(request, uri, logger)
    @logger = logger ? logger : Logger.new(STDOUT)
    uri = URI.parse(uri)

    @logger.info "Proxying to: #{uri.to_s}"

    method = request.request_method.downcase
    method[0..0] = method[0..0].upcase

    proxy_request = Net::HTTP.const_get(method).new("#{uri.path}#{"?" if uri.query}#{uri.query}")

    if proxy_request.request_body_permitted? and request.body
      proxy_request.body_stream = request.body
      proxy_request.content_length = request.content_length if request.content_length
      proxy_request.content_type = request.content_type if request.content_type
    end

    copy_headers_to_proxy_request(request, proxy_request)
    proxy_request["X-Forwarded-For"] =
      (request.env["X-Forwarded-For"].to_s.split(/, +/) + [request.env["REMOTE_ADDR"]]).join(", ")

    #@logger.debug "[Rack::StreamingProxy] Proxy Request Headers:"
    #proxy_request.each_header {|h,v| @logger.debug "[Rack::StreamingProxy] #{h} = #{v}"}
    @piper = Servolux::Piper.new 'r', timeout: 30

    @piper.child do
      begin
        http_req = Net::HTTP.new(uri.host, uri.port)
        http_req.use_ssl = uri.is_a?(URI::HTTPS)

        http_req.start do |http|
          @logger.info "[Rack::StreamingProxy] Child starting request to #{http.inspect}"

          # Retry the request up to MAX_503_RETRIES times if a 503 is experienced.
          # This is because Heroku sometimes gives spurious 503 errors that resolve themselves quickly.
          # do...while loop as suggested by Matz: http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-core/6745
          retries = 1
          stop = false
          loop do
            http.request(proxy_request) do |response|
              # at this point the headers and status are available, but the body has not yet been read.

              @logger.info "[Rack::StreamingProxy] Child got response: #{response.inspect}"

              if response.class == Net::HTTPServiceUnavailable
                if retries <= MAX_503_RETRIES
                  @logger.info "[Rack::StreamingProxy] Child got 503, retrying (Retry ##{retries})"
                  sleep 1
                  retries += 1
                  next
                end
              end

              # Start reading the body and putting it in the parent's pipe.
              puts_from_child(response)
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

        self.finish if !@body_permitted
      else
        @logger.info "[Rack::StreamingProxy] Parent received unexpected nil status!"
        self.finish
        raise Error
      end
    end

  #rescue RuntimeError => e
  #  @logger.info "[Rack::StreamingProxy] Parent process #{Process.pid} rescued #{e.class}."
  #  self.finish
  #  raise
  end

  # This method is called by Rack itself, to iterate over the proxied contents.
  def each
    if @body_permitted
      chunked = @headers["Transfer-Encoding"] == "chunked"
      term = "\r\n"

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

      self.finish

      yield ["0", term, "", term].join if chunked
    end
  end

protected

  def finish
    # parent needs to wait for the child, or it results in the child process becoming defunct, resulting in zombie processes!
    @logger.info "[Rack::StreamingProxy] Parent process #{Process.pid} waiting for child process #{@piper.pid} to exit."
    @piper.wait
  end

  def puts_from_child(response)
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

  def copy_headers_to_proxy_request(request, proxy_request)
    current_headers = request.env.reject {|env_key, env_val| !(env_key.match /^HTTP_/) }
    current_headers.each { |name, value|
      fixed_name = reconstructed_header_name_for name
      # @logger.debug "Setting proxy header #{name} to #{value} using #{fixed_name}"
      proxy_request[fixed_name] = value unless fixed_name.downcase == "host"
    }
  end

  def reconstructed_header_name_for(rackified_header_name)
    rackified_header_name.sub(/^HTTP_/, "").gsub("_", "-")
  end

end
