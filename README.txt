rack-streaming-proxy
    by Nathan Witmer <nwitmer@gmail.com>
    http://github.com/zerowidth/rack-streaming-proxy

== DESCRIPTION:

Streaming proxy for Rack, the rainbows to Rack::Proxy's unicorn.

== FEATURES/PROBLEMS:

Provides a transparent streaming proxy to be used as rack middleware.

* Streams the response from the downstream server to minimize memory usage
* Handles chunked encoding if used
* Proxies GET/PUT/POST/DELETE, XHR, and cookies

Use this when you need to have the response streamed back to the client,
for example when handling large file requests that could be proxied
directly but need to be authenticated against the rest of your middleware
stack.

Note that this will not work well with EventMachine. EM buffers the entire
rack response before sending it to the client. When testing, try
mongrel (via rackup) or passenger, rather than the EM-based thin. See
http://groups.google.com/group/thin-ruby/browse_thread/thread/4762f8f851b965f6
for more discussion.

I've included a simple streamer app for testing and development.

Thanks to:

* Tom Lea (cwninja) for Rack::Proxy (http://gist.github.com/207938)
* Tim Pease for bones, servolux, &c

== SYNOPSIS:

  require "rack/streaming_proxy"

  use Rack::StreamingProxy do |request|
    # inside the request block, return the full URI to redirect the request to,
    # or nil/false if the request should continue on down the middleware stack.
    if request.path.start_with?("/proxy")
      "http://another_server#{request.path}"
    end
  end

== REQUIREMENTS:

* servolux (gem install servolux)

== INSTALL:

* sudo gem install rack-streaming-proxy --source http://gemcutter.org

== LICENSE:

(The MIT License)

Copyright (c) 2009 Nathan Witmer

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
