require "rails_helper"

RSpec.describe BikeCodeBatch, type: :model do
  describe "factory" do
    let(:bike_code_batch) { FactoryBot.create(:bike_code_batch) }
    let!(:bike_code) { FactoryBot.create(:bike_code, bike_code_batch: bike_code_batch) }
    it "works" do
      expect(bike_code_batch.bike_codes).to eq([bike_code])
      expect(bike_code.bike_code_batch).to eq bike_code_batch
    end
  end

  describe "create_codes" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:bike_code_batch) { FactoryBot.create(:bike_code_batch, prefix: "XD", code_number_length: nil, organization: organization) }
    let(:target_codes) { %w[XD9999 XD10000 XD10001] }
    it "create_codes works and derives last code" do
      expect(bike_code_batch.code_number_length_or_default).to eq 4
      expect(bike_code_batch.bike_codes.count).to eq 0
      expect do
        bike_code_batch.create_codes(3, initial_code_integer: 9999)
      end.to change(BikeCode, :count).by 3
      bike_code_batch.reload
      expect(bike_code_batch.bike_codes.count).to eq 3
      expect(bike_code_batch.bike_codes.sticker.count).to eq 3
      expect(organization.bike_codes.count).to eq 3
      expect(bike_code_batch.bike_codes.pluck(:code)).to match_array target_codes
      expect(bike_code_batch.bike_codes.pluck(:code_integer)).to match_array([9999, 10_000, 10_001])
      expect(bike_code_batch.code_number_length_or_default).to eq 5

      expect do
        bike_code_batch.create_codes(1)
      end.to change(BikeCode, :count).by 1
      expect(bike_code_batch.bike_codes.pluck(:code)).to match_array(target_codes + ["XD10002"])

      # If passed a code number that already exists, it creates the following one
      expect do
        bike_code_batch.create_codes(1, initial_code_integer: 10_002)
      end.to change(BikeCode, :count).by 1
      expect(bike_code_batch.bike_codes.pluck(:code)).to match_array(target_codes + %w[XD10002 XD10003])

      # It can do earlier numbers too. If doing so, it pads accordingly
      expect do
        bike_code_batch.create_codes(1, initial_code_integer: 12)
      end.to change(BikeCode, :count).by 1
      expect(bike_code_batch.bike_codes.pluck(:code)).to match_array(target_codes + %w[XD10002 XD10003 XD00012])
    end
    context "without a prefix" do
      let(:bike_code_batch) { FactoryBot.create(:bike_code_batch, prefix: nil) }
      it "errors" do
        expect do
          bike_code_batch.create_codes(100)
        end.to raise_error(/prefix/i)
      end
    end
  end
end
