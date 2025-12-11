# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "binx_utils"
  spec.version = "0.1.0"
  spec.authors = ["Bike Index"]
  spec.email = ["dev@bikeindex.org"]

  spec.summary = "Utility classes for Bike Index"
  spec.description = "Time parsing, timezone parsing, and input normalization utilities"
  spec.homepage = "https://github.com/bikeindex/bike_index"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "rails-html-sanitizer", ">= 1.0"
end
