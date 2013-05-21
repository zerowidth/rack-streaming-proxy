class Rack::StreamingProxy::Response
  include Rack::Utils # For HeaderHash

  attr_reader :status, :headers

  def initialize(piper)
    @piper = piper
  end

  def receive
    # wait for the status and headers to come back from the child
    if @status = read_from_proxy
      Rack::StreamingProxy::Proxy.log :debug, "Parent received: Status = #{@status}."

      @body_permitted = read_from_proxy
      Rack::StreamingProxy::Proxy.log :debug, "Parent received: Reponse has body? = #{@body_permitted}."

      @headers = HeaderHash.new(read_from_proxy)

      # If there is a body, finish_request will be called inside each.
      finish_request if !@body_permitted
    else
      Rack::StreamingProxy::Proxy.log :error, "Parent received unexpected nil status!"
      finish_request
      raise Error
    end
  end

  # This method is called by Rack itself, to iterate over the proxied contents.
  def each
    if @body_permitted
      chunked = @headers['Transfer-Encoding'] == 'chunked'
      term = '\r\n'

      while chunk = read_from_proxy
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
    Rack::StreamingProxy::Proxy.log :debug, "Parent process #{Process.pid} waiting for child process #{@piper.pid} to exit."
    @piper.wait
  end

  def read_from_proxy
    @piper.gets
  end

end