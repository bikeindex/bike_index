# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExchangeRateApiClient, type: :model, vcr: true do
  describe "#latest" do
    it "returns a hash with :base and :rates keys" do
      client = ExchangeRateApiClient.new("CAD")
      response = client.latest
      expect(response).to have_key(:base)
      expect(response).to have_key(:rates)
      expect(response).to have_key(:date)
      expect(response[:base]).to eq("CAD")
      expect(response[:rates]).to be_a(Hash)
      expect(response[:rates]).to have_key("EUR")
    end
  end
end
