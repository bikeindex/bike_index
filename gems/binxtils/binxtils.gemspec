# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "binxtils"
  spec.version = "0.1.0"
  spec.authors = ["Bike Index"]
  spec.summary = "Bike Index utility modules"

  spec.required_ruby_version = ">= 3.4"

  spec.files = Dir["lib/**/*"]
  spec.require_paths = ["lib"]

  spec.add_dependency "functionable"
  spec.add_dependency "activesupport"
  spec.add_dependency "activerecord"
  spec.add_dependency "rails-html-sanitizer"
end
