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

  spec.add_development_dependency 'bundler',  '>= 1.3'
  spec.add_development_dependency 'rake',     '>= 10.0'

  spec.add_runtime_dependency     'rack',     '>= 1.4'
  spec.add_runtime_dependency     'servolux', '~> 0.10'
end

# Old stuff to be removed later

#spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=
#spec.date = "2012-06-22"
#spec.extra_rdoc_files = ["History.txt", "README.txt"]
#spec.rdoc_options = ["--main", "README.txt"]
#spec.rubyforge_project = "rack-streaming-proxy"
#spec.rubygems_version = "1.8.24"
#
#if spec.respond_to? :specification_version then
#  spec.specification_version = 3
#
#  if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
#    spec.add_runtime_dependency(%q<rack>, [">= 1.0"])
#    spec.add_runtime_dependency(%q<servolux>, ["~> 0.10.0"])
#    spec.add_development_dependency(%q<rack-test>, ["~> 0.5.1"])
#    spec.add_development_dependency(%q<bones>, [">= 3.8.0"])
#  else
#    spec.add_dependency(%q<rack>, [">= 1.0"])
#    spec.add_dependency(%q<servolux>, ["~> 0.10.0"])
#    spec.add_dependency(%q<rack-test>, ["~> 0.5.1"])
#    spec.add_dependency(%q<bones>, [">= 3.8.0"])
#  end
#else
#  spec.add_dependency(%q<rack>, [">= 1.0"])
#  spec.add_dependency(%q<servolux>, ["~> 0.10.0"])
#  spec.add_dependency(%q<rack-test>, ["~> 0.5.1"])
#  spec.add_dependency(%q<bones>, [">= 3.8.0"])
#end

