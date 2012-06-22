# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{rack-streaming-proxy}
  s.version = "1.0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nathan Witmer"]
  s.date = %q{2010-11-15}
  s.description = %q{Streaming proxy for Rack, the rainbows to Rack::Proxy's unicorn.}
  s.email = %q{nwitmer@gmail.com}
  s.extra_rdoc_files = ["History.txt", "README.txt"]
  s.files = ["History.txt", "README.txt", "Rakefile", "dev/proxy.ru", "dev/streamer.ru", "lib/rack/streaming_proxy.rb", "lib/rack/streaming_proxy/proxy_request.rb", "spec/app.ru", "spec/proxy.ru", "spec/spec_helper.rb", "spec/streaming_proxy_spec.rb"]
  s.homepage = %q{http://github.com/aniero/rack-streaming-proxy}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{rack-streaming-proxy}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Streaming proxy for Rack, the rainbows to Rack::Proxy's unicorn}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 1.0"])
      s.add_runtime_dependency(%q<servolux>, ["~> 0.8.1"])
      s.add_development_dependency(%q<rack-test>, ["~> 0.5.1"])
      s.add_development_dependency(%q<bones>, [">= 3.5.1"])
    else
      s.add_dependency(%q<rack>, [">= 1.0"])
      s.add_dependency(%q<servolux>, ["~> 0.8.1"])
      s.add_dependency(%q<rack-test>, ["~> 0.5.1"])
      s.add_dependency(%q<bones>, [">= 3.5.1"])
    end
  else
    s.add_dependency(%q<rack>, [">= 1.0"])
    s.add_dependency(%q<servolux>, ["~> 0.8.1"])
    s.add_dependency(%q<rack-test>, ["~> 0.5.1"])
    s.add_dependency(%q<bones>, [">= 3.5.1"])
  end
end
