require "yaml"

class Streamer
  include Rack::Utils

  def initialize(sleep=0.05)
    @sleep = sleep
    @strings = 5.times.collect {|n| "~~~~~ #{n} ~~~~~\n" }
  end

  def call(env)
    req = Rack::Request.new(env)
    headers = {"Content-Type" => "text/plain"}
    headers["Transfer-Encoding"] = "chunked"
    [200, headers, self.dup]
  end

  def each
    term = "\r\n"
    @strings.each do |chunk|
      size = bytesize(chunk)
      yield [size.to_s(16), term, chunk, term].join
      sleep @sleep
    end
    yield ["0", term, "", term].join
  end
end

# if no content-length is provided and the response isn't streamed,
# make sure the headers get a content length.
use Rack::ContentLength

map "/" do
  run lambda { |env| [200, {"Content-Type" => "text/plain"}, ["ALL GOOD"]] }
end

map "/stream" do
  run Streamer.new
end

map "/slow_stream" do
  run Streamer.new(0.5)
end

map "/env" do
  run lambda { |env|
    req = Rack::Request.new(env)
    req.POST # modifies env inplace to include "rack.request.form_vars" key
    [200, {"Content-Type" => "application/x-yaml"}, [env.to_yaml]] }
end

map "/boom" do
  run lambda { |env| [500, {"Content-Type" => "text/plain"}, ["kaboom!"]] }
end

