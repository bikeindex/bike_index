# For codeclimate test coverage.
# Only enable if the environmental variable is set - i.e. on CI
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start "rails"
end
