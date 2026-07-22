require_relative "lib/ruby_zmq_framework/version"

Gem::Specification.new do |spec|
  spec.name        = "ruby_zmq_framework"
  spec.version     = RubyZmqFramework::VERSION
  spec.authors     = ["Paul Daniel"]
  spec.email       = ["paulgdan@gmail.com"]

  spec.summary     = "Lightweight pure-Ruby pub/sub framework over ZeroMQ with strict module contracts"
  spec.description = "Decouples modules using a peer-to-peer ZeroMQ network and enforces a " \
                      "strict runtime contract (similar to TypeScript interfaces) without " \
                      "requiring compilation or type-checkers."
  spec.license     = "MIT"
  spec.homepage    = "https://github.com/pgdaniel/ruby_zmq_framework"

  spec.metadata["source_code_uri"] = spec.homepage

  spec.required_ruby_version = ">= 2.7"

  spec.files         = Dir["lib/**/*.rb"] + ["README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "ffi-rzmq", "~> 2.0"
  spec.add_dependency "json", "~> 2.0"

  spec.add_development_dependency "minitest", "~> 5.20"
  spec.add_development_dependency "rake", "~> 13.0"
end
