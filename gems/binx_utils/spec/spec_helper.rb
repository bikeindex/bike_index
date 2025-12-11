# frozen_string_literal: true

require "bundler/setup"
require "binx_utils"
require "active_model"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.before(:each) do
    Time.zone = BinxUtils::TimeParser.default_time_zone
  end
end

RSpec::Matchers.define :match_time do |expected|
  match do |actual|
    actual.to_i == expected.to_i
  end
end
