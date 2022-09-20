# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExchangeRateAPIClient, type: :model, vcr: true do
  describe "#latest" do
    it "returns a hash with :base and :rates keys" do
      client = ExchangeRateAPIClient.new("CAD")
      response = client.latest
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
