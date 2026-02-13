require "rails_helper"

RSpec.describe Backfills::OwnershipRegistrationInfoKeysJob, type: :job do
  describe "iterable_scope" do
    let!(:ownership_with_zipcode) { FactoryBot.create(:ownership, registration_info: {zipcode: "12345", phone: "1234567890"}) }
    let!(:ownership_with_state) { FactoryBot.create(:ownership, registration_info: {state: "CA", phone: "1234567890"}) }
    let!(:ownership_with_country) { FactoryBot.create(:ownership, registration_info: {country: "US", phone: "1234567890"}) }
    let!(:ownership_with_new_keys) { FactoryBot.create(:ownership, registration_info: {postal_code: "12345", region_string: "CA", country: "US"}) }
    let!(:ownership_without_location) { FactoryBot.create(:ownership, registration_info: {phone: "1234567890"}) }

    it "includes ownerships with old keys" do
      expect(described_class.iterable_scope).to match_array([ownership_with_zipcode, ownership_with_state])
    end
  end

  describe "updated_registration_info" do
    it "renames zipcode to postal_code" do
      result = described_class.updated_registration_info({"zipcode" => "12345", "phone" => "555"})
      expect(result).to eq({"postal_code" => "12345", "phone" => "555"})
    end

    it "renames state to region_string" do
      result = described_class.updated_registration_info({"state" => "CA", "phone" => "555"})
      expect(result).to eq({"region_string" => "CA", "phone" => "555"})
    end

    it "renames all old keys at once" do
      result = described_class.updated_registration_info({
        "zipcode" => "12345",
        "state" => "CA",
        "country" => "US",
        "phone" => "555"
      })
      expect(result).to eq({
        "postal_code" => "12345",
        "region_string" => "CA",
        "country" => "US",
        "phone" => "555"
      })
    end

    it "does not overwrite existing new keys" do
      result = described_class.updated_registration_info({
        "zipcode" => "old_zip",
        "postal_code" => "new_zip",
        "phone" => "555"
      })
      expect(result).to eq({"postal_code" => "new_zip", "phone" => "555"})
    end

    it "returns blank registration_info unchanged" do
      expect(described_class.updated_registration_info(nil)).to be_nil
      expect(described_class.updated_registration_info({})).to eq({})
    end
  end

  describe "each_iteration" do
    let(:instance) { described_class.new }
    let(:ownership) { FactoryBot.create(:ownership, registration_info: {"zipcode" => "12345", "state" => "CA", "country" => "US"}) }

    it "updates the ownership registration_info" do
      instance.each_iteration(ownership)

      ownership.reload
      expect(ownership.registration_info).to eq({
        "postal_code" => "12345",
        "region_string" => "CA",
        "country" => "US"
      })
    end
  end
end
