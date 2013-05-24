module Rack::StreamingProxy
  class Error           < RuntimeError; end
  class UnknownError    < Error;        end
  class HttpServerError < Error;        end
end