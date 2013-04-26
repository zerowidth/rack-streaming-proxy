# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "rack-streaming-proxy"
  s.version = "1.0.6"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Nathan Witmer"]
  s.date = "2012-06-22"
  s.description = "Streaming proxy for Rack, the rainbows to Rack::Proxy's unicorn."
  s.email = "nwitmer@gmail.com"
  s.extra_rdoc_files = ["History.txt", "README.txt"]
  s.files = [".gitignore", ".rspec", ".rvmrc", "Gemfile", "History.txt", "README.txt", "Rakefile", "dev/proxy.ru", "dev/streamer.ru", "lib/rack/streaming_proxy.rb", "lib/rack/streaming_proxy/proxy_request.rb", "lib/rack/streaming_proxy/railtie.rb", "rack-streaming-proxy.gemspec", "spec/app.ru", "spec/proxy.ru", "spec/spec_helper.rb", "spec/streaming_proxy_spec.rb"]
  s.homepage = "http://github.com/fredngo/rack-streaming-proxy"
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = "rack-streaming-proxy"
  s.rubygems_version = "1.8.24"
  s.summary = "Streaming proxy for Rack, the rainbows to Rack::Proxy's unicorn."

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<rack>, [">= 1.0"])
      s.add_runtime_dependency(%q<servolux>, ["~> 0.10.0"])
      s.add_development_dependency(%q<rack-test>, ["~> 0.5.1"])
      s.add_development_dependency(%q<bones>, [">= 3.8.0"])
    else
      s.add_dependency(%q<rack>, [">= 1.0"])
      s.add_dependency(%q<servolux>, ["~> 0.10.0"])
      s.add_dependency(%q<rack-test>, ["~> 0.5.1"])
      s.add_dependency(%q<bones>, [">= 3.8.0"])
    end
  else
    s.add_dependency(%q<rack>, [">= 1.0"])
    s.add_dependency(%q<servolux>, ["~> 0.10.0"])
    s.add_dependency(%q<rack-test>, ["~> 0.5.1"])
    s.add_dependency(%q<bones>, [">= 3.8.0"])
  end
end
