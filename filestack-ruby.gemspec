# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
puts lib
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "filestack/ruby/version"

Gem::Specification.new do |spec|
  spec.name          = "filestack"
  spec.version       = Filestack::Ruby::VERSION
  spec.authors       = ["Filestack"]
  spec.email         = ["dev@filestack.com"]

  spec.summary       = %q{Official Ruby SDK for the Filestack API}
  spec.description   = %q{This is the official Ruby SDK for Filestack - API and content management system that makes it easy to add powerful file uploading and transformation capabilities to any web or mobile application.}
  spec.homepage      = "https://github.com/filestack/filestack-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|test-files)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "unirest", "~> 1.1.2"
  spec.add_dependency "parallel", "~> 1.11.2"
  spec.add_dependency "mimemagic", "~> 0.3.2"
  spec.add_dependency "progress_bar"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.14"
end