require File.expand_path(
  File.join(File.dirname(__FILE__), %w[.. lib rack streaming_proxy]))

ENV['RACK_ENV'] = 'none' # 'development' automatically use Rack::Lint and results in errors with unicorn
# use Rack::CommonLogger
use Rack::StreamingProxy::Proxy do |req|
  "http://localhost:4321#{req.path}"
end
run lambda { |env| [200, {}, ["should never get here..."]]}
