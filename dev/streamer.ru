class Streamer
  include Rack::Utils

  def call(env)
    req = Rack::Request.new(env)
    headers = {"Content-Type" => "text/plain"}

    @chunked = req.path.start_with?("/chunked")

    if count = req.path.match(/(\d+)$/)
      count = count[0].to_i
    else
      count = 100
    end
    @strings = count.times.collect {|n| "~~~~~ #{n} ~~~~~\n" }

    if chunked?
      headers["Transfer-Encoding"] = "chunked"
    else
      headers["Content-Length"] = @strings.inject(0) {|sum, s| sum += bytesize(s)}.to_s
    end

    [200, headers, self.dup]
  end

  def each
    term = "\r\n"
    @strings.each do |chunk|
      if chunked?
        size = bytesize(chunk)
        yield [size.to_s(16), term, chunk, term].join
      else
        yield chunk
      end
      sleep 0.05
    end
    yield ["0", term, "", term].join if chunked?
  end

  protected

  def chunked?
    @chunked
  end
end

# use Rack::CommonLogger # rackup already has commonlogger loaded
use Rack::Lint

# GET /
# GET /10
# GET /chunked
# GET /chunked/10
run Streamer.new
