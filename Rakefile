
begin
  require 'bones'
rescue LoadError
  abort '### Please install the "bones" gem ###'
end

ensure_in_path 'lib'
require 'rack-streaming-proxy'

task :default => 'test:run'
task 'gem:release' => 'test:run'

Bones {
  name  'rack-streaming-proxy'
  authors  'Nathan Witmer'
  email  'nwitmer@gmail.com'
  url  'http://github.com/aniero/rack-streaming-proxy'
  version  RackStreamingProxy::VERSION
  ignore_file  '.gitignore'
}

# EOF
