# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rack/streaming_proxy/version'

Gem::Specification.new do |spec|
  spec.name          = 'rack-streaming-proxy'
  spec.version       = Rack::StreamingProxy::VERSION
  spec.authors       = ['Fred Ngo', 'Nathan Witmer']
  spec.email         = ['fredngo@gmail.com', 'nwitmer@gmail.com']
  spec.description   = %q{Streaming proxy for Rack, the rainbows to Rack::Proxy's unicorn.}
  spec.summary       = %q{Streaming proxy for Rack, the rainbows to Rack::Proxy's unicorn.}
  spec.homepage      = 'http://github.com/fredngo/rack-streaming-proxy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency     'rack',     '>= 1.4'
  spec.add_runtime_dependency     'servolux', '~> 0.10'

  # test
  spec.add_development_dependency 'bundler',  '>= 1.3'
  spec.add_development_dependency 'rake',     '>= 10.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rack-test'

  # debug
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'pry-nav'
end
