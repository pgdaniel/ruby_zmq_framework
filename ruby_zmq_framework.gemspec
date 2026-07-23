require_relative "lib/ruby_zmq_framework/version"

Gem::Specification.new do |spec|
  spec.name        = "ruby_zmq_framework"
  spec.version     = RubyZmqFramework::VERSION
  spec.authors     = ["Paul Daniel"]
  spec.email       = ["paulgdan@gmail.com"]

  spec.summary     = "Flow-based, language-agnostic node runtime over ZeroMQ — Node-RED without the UI"
  spec.description = "Blackbox node processes wired together by pub/sub topics: the graph lives " \
                      "in a flow.yml manifest, nodes are configured entirely from the environment, " \
                      "and a one-page protocol lets any language join the bus. Includes a hardened " \
                      "ZeroMQ transport with strict runtime module contracts."
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/pgdaniel/ruby_zmq_framework"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.required_ruby_version = ">= 2.7"

  spec.files         = Dir["lib/**/*.rb"] + ["README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  # json is deliberately not declared: it is a default gem shipped with
  # every supported Ruby.
  spec.add_dependency "ffi-rzmq", "~> 2.0"

  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "rake", "~> 13.0"
end
