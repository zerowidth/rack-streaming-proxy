# Rack::StreamingProxy

A transparent streaming proxy to be used as rack middleware.

* Streams the response from the downstream server to minimize memory usage
* Handles chunked encoding if used
* Proxies GET/PUT/POST/DELETE, XHR, and cookies

Now updated to be compatible with Rails 3 and 4, and fixes major concurrency issues that were present in 1.0.

Use Rack::StreamingProxy when you need to have the response streamed back to the client, for example when handling large file requests that could be proxied directly but need to be authenticated against the rest of your middleware stack.

Note that this will not work well with EventMachine. EM buffers the entire rack response before sending it to the client. When testing, try Unicorn or Passenger rather than the EM-based Thin (See [discussion](http://groups.google.com/group/thin-ruby/browse_thread/thread/4762f8f851b965f6)).

A simple streamer app has been included for testing and development.

## Usage

To use inside a Rails app, add a `config/initializers/streaming_proxy.rb` initialization file, and place in it:

```ruby
require 'rack/streaming_proxy'

YourRailsApp::Application.configure do
  config.streaming_proxy.logger = Rails.logger

  # Will be inserted at the end of the middleware stack by default.
  config.middleware.use Rack::StreamingProxy::Proxy do |request|

    # Inside the request block, return the full URI to redirect the request to,
    # or nil/false if the request should continue on down the middleware stack.
    if request.path.start_with?('/proxy')
      "http://another_server#{request.path}"
    end
  end

end
```

To use as a Rack app:

```ruby
require 'rack/streaming_proxy'

use Rack::StreamingProxy::Proxy do |request|
  if request.path.start_with?('/proxy')
    "http://another_server#{request.path}"
  end
end
```

## Installation

Add this line to your application's Gemfile:

    gem 'rack-streaming-proxy'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-streaming-proxy

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## Thanks To

* [Nathan Witmer](http://github.com/zerowidth) for the 1.0 implementation of [Rack::StreamingProxy](http://github.com/zerowidth/rack-streaming-proxy)
* [Tom Lea](http://github.com/cwninja) for [Rack::Proxy](http://gist.github.com/207938), which inspired Rack::StreamingProxy.
* [Tim Pease](http://github.com/TwP) for [Servolux](https://github.com/Twp/servolux)
