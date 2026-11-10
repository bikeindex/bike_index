require "rails_helper"

RSpec.describe UpdateExchangeRatesJob, type: :job do
  before { Rails.cache.delete(Integrations::ExchangeRateAPIClient.new.cache_key) }
  around { |example| VCR.use_cassette("exchange_rate_api_client", match_requests_on: [:method, :query]) { example.run } }

  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "stores rates from USD" do
    described_class.new.perform

    expect(ExchangeRate.get_rate("USD", "USD")).to eq 1
    expect(ExchangeRate.get_rate("USD", "EUR")).to be_within(0.00001).of(0.88995)
    expect(ExchangeRate.where.not(from: "USD")).to be_empty
  end
end
