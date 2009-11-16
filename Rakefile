begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

ensure_in_path 'lib'
require 'rack/streaming_proxy'

task :default => 'spec:specdoc'
task 'gem:release' => 'spec:specdoc'

Bones {
  name  'rack-streaming-proxy'
  authors  'Nathan Witmer'
  email  'nwitmer@gmail.com'
  url  'http://github.com/aniero/rack-streaming-proxy'
  version  Rack::StreamingProxy::VERSION
  ignore_file  '.gitignore'
  depend_on "rack", :version => "~> 1.0.1"
  depend_on "servolux", :version => "~> 0.8.1"
  depend_on "rack-test", :version => "~> 0.5.1", :development => true
  spec {
    opts ["--colour",  "--loadby mtime", "--reverse", "--diff unified"]
  }
}

