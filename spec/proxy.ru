require File.expand_path(
  File.join(File.dirname(__FILE__), %w[.. lib rack streaming_proxy]))

use Rack::Lint
# use Rack::CommonLogger
use Rack::StreamingProxy do |req|
  "http://localhost:4321#{req.path}"
end
run lambda { |env| [200, {}, "should never get here..."]}
