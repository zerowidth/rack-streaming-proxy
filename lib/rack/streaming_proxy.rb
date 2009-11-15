module Rack
  class StreamingProxy

    # :stopdoc:
    VERSION = '1.0.0'
    LIBPATH = ::File.expand_path(::File.dirname(__FILE__)) + ::File::SEPARATOR
    PATH = ::File.dirname(LIBPATH) + ::File::SEPARATOR
    # :startdoc:

    # Returns the version string for the library.
    #
    def self.version
      VERSION
    end

    # Returns the library path for the module. If any arguments are given,
    # they will be joined to the end of the libray path using
    # <tt>File.join</tt>.
    #
    def self.libpath( *args )
      args.empty? ? LIBPATH : ::File.join(LIBPATH, args.flatten)
    end

    # Returns the lpath for the module. If any arguments are given,
    # they will be joined to the end of the path using
    # <tt>File.join</tt>.
    #
    def self.path( *args )
      args.empty? ? PATH : ::File.join(PATH, args.flatten)
    end

    # Utility method used to require all files ending in .rb that lie in the
    # directory below this file that has the same name as the filename passed
    # in. Optionally, a specific _directory_ name can be passed in such that
    # the _filename_ does not have to be equivalent to the directory.
    #
    def self.require_all_libs_relative_to( fname, dir = nil )
      dir ||= ::File.basename(fname, '.*')
      search_me = ::File.expand_path(
        ::File.join(::File.dirname(fname), dir, '**', '*.rb'))

        Dir.glob(search_me).sort.each {|rb| require rb}
    end

    # The block provided to the initializer is given a Rack::Request
    # and should return:
    #
    #   * nil/false to skip the proxy and continue down the stack
    #   * a complete uri (with query string if applicable) to proxy to
    #
    # E.g.
    #
    #   use Rack::StreamingProxy do |req|
    #     if req.path.start_with?("/search")
    #       "http://some_other_service/search?#{req.query}"
    #     end
    #   end
    #
    # Most headers, request body, and HTTP method are preserved.
    #
    def initialize(app, &block)
      @request_uri = block
      @app = app
    end

    def call(env)
      req = Rack::Request.new(env)
      return app.call(env) unless uri = request_uri.call(req)
      proxy = ProxyRequest.new(req, uri)
      [proxy.status, proxy.headers, proxy]
    end

    protected

    attr_reader :request_uri, :app

  end

end

Rack::StreamingProxy.require_all_libs_relative_to(__FILE__)
require "servolux"
require "net/http"
require "uri"
