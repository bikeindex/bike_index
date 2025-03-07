# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integrations::ExchangeRateAPIClient, type: :service do
  describe "#latest" do
    let(:instance) { described_class.new("CAD") }

    it "returns a hash with :base and :rates keys" do
      Rails.cache.clear(instance.cache_key)
      VCR.use_cassette("exchange_rate_api_client", match_requests_on: [:path]) do
        response = instance.latest
        pp response unless response.key?(:base)
        expect(response).to have_key(:base)
        expect(response).to have_key(:rates)
        expect(response).to have_key(:date)
        expect(response[:base]).to eq("CAD")
        expect(response[:rates]).to be_a(Hash)
        expect(response[:rates]).to have_key("EUR")
      end
    end
  end
end
