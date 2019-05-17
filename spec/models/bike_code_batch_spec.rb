require "spec_helper"

RSpec.describe BikeCodeBatch, type: :model do
  describe "factory" do
    let(:bike_code_batch) { FactoryBot.create(:bike_code_batch) }
    let!(:bike_code) { FactoryBot.create(:bike_code, bike_code_batch: bike_code_batch) }
    it "works" do
      expect(bike_code_batch.bike_codes).to eq([bike_code])
      expect(bike_code.bike_code_batch).to eq bike_code_batch
    end
  end
end
