# frozen_string_literal: true

require_relative "lib/binxtils/version"

Gem::Specification.new do |spec|
  spec.name = "binxtils"
  spec.version = Binxtils::VERSION
  spec.authors = ["Bike Index"]
  spec.email = ["seth@bikeidnex.org"]

  spec.summary = "Utility classes used by Bike Index"
  spec.description = "Time parsing, timezone parsing, and input normalization utilities"
  spec.homepage = "https://github.com/bikeindex/bike_index"
  spec.license = "MIT"

  spec.platform = Gem::Platform::RUBY
  spec.required_ruby_version = ">= 3.3"

  spec.extra_rdoc_files = ["README.md"]
  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "rails-html-sanitizer", ">= 1.0"

  spec.add_development_dependency "rspec", "~> 3.0"

  spec.metadata["rubygems_mfa_required"] = "true"
end
