require 'yaml'
require File.join(File.dirname(__FILE__), %w[spec_helper])

describe Rack::StreamingProxy do
  include Rack::Test::Methods

  APP_PORT = 4321 # hardcoded in proxy.ru as well!
  PROXY_PORT = 4322

  def app
    @app ||= Rack::Builder.new do
      use Rack::Lint
      use Rack::StreamingProxy do |req|
        unless req.path.start_with?("/not_proxied")
          url = "http://localhost:#{APP_PORT}#{req.path}"
          url << "?#{req.query_string}" unless req.query_string.empty?
          # STDERR.puts "PROXYING to #{url}"
          url
        end
      end
      run lambda { |env|
        raise "app error" if env["PATH_INFO"] =~ /boom/
        [200, {"Content-Type" => "text/plain"}, ["not proxied"]]
      }
    end
  end

  before(:all) do
    app_path = Rack::StreamingProxy.path("spec", "app.ru")
    @app_server = Servolux::Child.new(
      # :command => "thin -R #{app_path} -p #{APP_PORT} start", # buffers!
      :command => "rackup #{app_path} -p #{APP_PORT}",
      :timeout => 30, # all specs should take <30 sec to run
      :suspend => 0.25
    )
    puts "----- starting app server -----"
    @app_server.start
    sleep 2 # give it a sec
    puts "----- started app server -----"
  end

  after(:all) do
    puts "----- shutting down app server -----"
    @app_server.stop
    @app_server.wait
    puts "----- app server is stopped -----"
  end

  def with_proxy_server
    proxy_path = Rack::StreamingProxy.path("spec", "proxy.ru")
    @proxy_server = Servolux::Child.new(
      :command => "rackup #{proxy_path} -p #{PROXY_PORT}",
      :timeout => 10,
      :suspend => 0.25
    )
    puts "----- starting proxy server -----"
    @proxy_server.start
    sleep 2
    puts "----- started proxy server -----"
    yield
  ensure
    puts "----- shutting down proxy server -----"
    @proxy_server.stop
    @proxy_server.wait
    puts "----- proxy server is stopped -----"
  end

  it "passes through to the rest of the stack if block returns false" do
    get "/not_proxied"
    last_response.should be_ok
    last_response.body.should == "not proxied"
  end

  it "proxies a request back to the app server" do
    get "/"
    last_response.should be_ok
    last_response.body.should == "ALL GOOD"
  end

  it "uses chunked encoding when the app server send data that way" do
    get "/stream"
    last_response.should be_ok
    last_response.headers["Transfer-Encoding"].should == "chunked"
    last_response.body.should =~ /^e\r\n~~~~~ 0 ~~~~~\n\r\n/
  end

  # this is the most critical spec: it makes sure things are actually streamed, not buffered
  it "streams data from the app server to the client" do
    @app = Rack::Builder.new do
      use Rack::Lint
      run lambda { |env|
        body = []
        Net::HTTP.start("localhost", PROXY_PORT) do |http|
          http.request_get("/slow_stream") do |response|
            response.read_body do |chunk|
              body << "#{Time.now.to_i}\n"
            end
          end
        end
        [200, {"Content-Type" => "text/plain"}, body]
      }
    end

    with_proxy_server do
      get "/"
      last_response.should be_ok
      times = last_response.body.split("\n").map {|l| l.to_i}
      unless (times.last - times.first) >= 2
        fail "expected receive time of first chunk to be at least two seconds before the last chunk, but the times were: #{times.join(', ')}"
      end
    end

  end

  it "handles POST, PUT, and DELETE methods" do
    post "/env"
    last_response.should be_ok
    last_response.body.should =~ /REQUEST_METHOD: POST/
    put "/env"
    last_response.should be_ok
    last_response.body.should =~ /REQUEST_METHOD: PUT/
    delete "/env"
    last_response.should be_ok
    last_response.body.should =~ /REQUEST_METHOD: DELETE/
  end

  it "sets a X-Forwarded-For header" do
    post "/env"
    last_response.should =~ /HTTP_X_FORWARDED_FOR: 127.0.0.1/
  end

  it "preserves the post body" do
    post "/env", "foo" => "bar"
    last_response.body.should =~ /rack.request.form_vars: foo=bar/
  end

  it "raises a Rack::Proxy::StreamingProxy error when something goes wrong" do
    Rack::StreamingProxy::ProxyRequest.should_receive(:new).and_raise(RuntimeError.new("kaboom"))
    lambda { get "/" }.should raise_error(Rack::StreamingProxy::Error, /proxy error.*kaboom/i)
  end

  it "does not raise a Rack::Proxy error if the app itself raises something" do
    lambda { get "/not_proxied/boom" }.should raise_error(RuntimeError, /app error/)
  end

  it "preserves cookies" do
    set_cookie "foo"
    post "/env"
    YAML::load(last_response.body)["HTTP_COOKIE"].should == "foo"
  end

  it "preserves authentication info" do
    basic_authorize "admin", "secret"
    post "/env"
    YAML::load(last_response.body)["HTTP_AUTHORIZATION"].should == "Basic YWRtaW46c2VjcmV0"
  end

end

