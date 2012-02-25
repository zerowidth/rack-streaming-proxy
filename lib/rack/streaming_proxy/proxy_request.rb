require 'logger'

class Rack::StreamingProxy
  class ProxyRequest
    include Rack::Utils

    attr_reader :status, :headers

    def initialize(request, uri)
			@logger = Logger.new(STDOUT)
      uri = URI.parse(uri)

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

			@logger.info "[Rack::StreamingProxy] Proxy Request Headers:"
			proxy_request.each_header {|h,v| @logger.info "[Rack::StreamingProxy] #{h} = #{v}"}
      @piper = Servolux::Piper.new 'r', :timeout => 30

      @piper.child do
        http_req = Net::HTTP.new(uri.host, uri.port)
        http_req.use_ssl = uri.is_a?(URI::HTTPS)
        http_req.start do |http|
					@logger.info "[Rack::StreamingProxy] Starting request to #{http.inspect}"
					
          http.request(proxy_request) do |response|
						@logger.info "[Rack::StreamingProxy] got response: #{response.inspect}"
            # at this point the headers and status are available, but the body
            # has not yet been read. start reading it and putting it in the parent's pipe.
            response_headers = {}
            response.each_header {|k,v| response_headers[k] = v}
            @piper.puts response.code.to_i
            @piper.puts response_headers

            response.read_body do |chunk|
              @piper.puts chunk
            end
            @piper.puts :done
          end
        end
      end

      @piper.parent do
        # wait for the status and headers to come back from the child
        @status = read_from_child
        @headers = HeaderHash.new(read_from_child)
      end
    rescue => e
      if @piper
        @piper.parent { raise }
        @piper.child { @piper.puts e }
      else
        raise
      end
    ensure
      # child needs to exit, always.
      @piper.child { exit!(0) } if @piper
    end

    def each
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

      yield ["0", term, "", term].join if chunked
    end


    protected

    def read_from_child
      val = @piper.gets
      raise val if val.kind_of?(Exception)
      val
    end

    def copy_headers_to_proxy_request(request, proxy_request)
      current_headers = request.env.reject {|env_key, env_val| !(env_key.match /^HTTP_/) }
      current_headers.each { |name, value|
        fixed_name = reconstructed_header_name_for name
        # @logger.info "Setting proxy header #{name} to #{value} using #{fixed_name}"
        proxy_request[fixed_name] = value }
    end

    def reconstructed_header_name_for(rackified_header_name)
      rackified_header_name.sub(/^HTTP_/, "").gsub("_", "-")
    end

  end

end
