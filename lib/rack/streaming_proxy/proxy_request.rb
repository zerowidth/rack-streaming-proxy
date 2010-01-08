class Rack::StreamingProxy
  class ProxyRequest
    include Rack::Utils

    attr_reader :status, :headers

    def initialize(request, uri)
      uri = URI.parse(uri)

      method = request.request_method.downcase
      method[0..0] = method[0..0].upcase

      proxy_request = Net::HTTP.const_get(method).new("#{uri.path}#{"?" if uri.query}#{uri.query}")

      if proxy_request.request_body_permitted? and request.body
        proxy_request.body_stream = request.body
        proxy_request.content_length = request.content_length
        proxy_request.content_type = request.content_type
      end

      %w(Accept Accept-Encoding Accept-Charset
        X-Requested-With Referer User-Agent Cookie
        Authorization
        ).each do |header|
        key = "HTTP_#{header.upcase.gsub('-', '_')}"
        proxy_request[header] = request.env[key] if request.env[key]
      end
      proxy_request["X-Forwarded-For"] =
        (request.env["X-Forwarded-For"].to_s.split(/, +/) + [request.env["REMOTE_ADDR"]]).join(", ")

      @piper = Servolux::Piper.new 'r', :timeout => 30

      @piper.child do
        Net::HTTP.start(uri.host, uri.port) do |http|
          http.request(proxy_request) do |response|
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
      @piper.parent { raise }
      @piper.child { @piper.puts e }
    ensure
      # child needs to exit, always.
      @piper.child { exit!(0) }
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

  end
end
