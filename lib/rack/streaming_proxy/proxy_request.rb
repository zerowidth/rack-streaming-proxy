class Rack::StreamingProxy
  class ProxyRequest
    include Rack::Utils

    attr_reader :status, :headers

    def initialize(env, uri)
      uri = URI.parse(uri)
      proxy_headers = {
          "Accept" => env["HTTP_ACCEPT"],
          "User-Agent" => env["HTTP_USER_AGENT"]
      }
      if env["HTTP_ACCEPT_ENCODING"]
        proxy_headers["Accept-Encoding"] = env["HTTP_ACCEPT_ENCODING"]
      end

      @piper = Servolux::Piper.new 'r', :timeout => 30

      @piper.child do
        Net::HTTP.start(uri.host, uri.port) do |http|
          http.request_get(uri.request_uri, proxy_headers) do |response|
            # at this point the headers and status are available, but
            # the body has not yet been read. start reading it
            # and putting it in the parent's pipe.
            @piper.puts [response.code.to_i, response.to_hash]
            response.read_body do |chunk|
              @piper.puts chunk
            end
            @piper.puts :done
          end
        end
        exit!
      end

      @piper.parent do
        # wait for the status and headers to come back from the child
        @status, @headers = @piper.gets

        # headers from net/http response are arrays, clean 'em up for rack
        @headers.each do |key, value|
          @headers[key] = value.join if value.respond_to?(:join)
        end

        @headers = HeaderHash.new(@headers)
      end
    end

    # thanks to Rack::Chunked...
    def each
      chunked = @headers["Transfer-Encoding"] == "chunked"
      term = "\r\n"

      while chunk = @piper.gets
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

  end
end
