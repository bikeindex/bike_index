require "rails_helper"

RSpec.describe Backfills::BParamAddressAttrsJob, type: :job do
  describe "iterable_scope" do
    let!(:b_param_with_street) { FactoryBot.create(:b_param, params: {bike: {street: "123 Main St"}}) }
    let!(:b_param_with_address) { FactoryBot.create(:b_param, params: {bike: {address: "456 Oak Ave"}}) }
    let!(:b_param_with_zipcode) { FactoryBot.create(:b_param, params: {bike: {zipcode: "12345"}}) }
    let!(:b_param_with_address_city) { FactoryBot.create(:b_param, params: {bike: {address_city: "Chicago"}}) }
    let!(:b_param_with_new_format) { FactoryBot.create(:b_param, params: {bike: {address_record_attributes: {street: "789 Elm St"}}}) }
    let!(:b_param_empty) { FactoryBot.create(:b_param, params: {bike: {}}) }

    it "includes b_params with legacy address keys" do
      expect(described_class.iterable_scope).to match_array([
        b_param_with_street, b_param_with_address, b_param_with_zipcode, b_param_with_address_city
      ])
    end
  end

  describe "build_address_record_attributes" do
    it "returns empty hash for blank bike_params" do
      expect(described_class.build_address_record_attributes(nil)).to eq({})
      expect(described_class.build_address_record_attributes({})).to eq({})
    end

    it "still extracts legacy keys when address_record_attributes already exists" do
      bike_params = {"address_record_attributes" => {"street" => "123"}, "city" => "Chicago"}
      expect(described_class.build_address_record_attributes(bike_params)).to eq({"city" => "Chicago"})
    end

    it "converts street from address" do
      expect(described_class.build_address_record_attributes({"address" => "123 Main"})).to eq({"street" => "123 Main"})
    end

    it "converts street from address_street" do
      expect(described_class.build_address_record_attributes({"address_street" => "123 Main"})).to eq({"street" => "123 Main"})
    end

    it "prefers street over address" do
      result = described_class.build_address_record_attributes({"street" => "preferred", "address" => "fallback"})
      expect(result).to eq({"street" => "preferred"})
    end

    it "converts city from address_city" do
      expect(described_class.build_address_record_attributes({"address_city" => "Chicago"})).to eq({"city" => "Chicago"})
    end

    it "converts postal_code from zipcode" do
      expect(described_class.build_address_record_attributes({"zipcode" => "12345"})).to eq({"postal_code" => "12345"})
    end

    it "converts postal_code from address_zipcode" do
      expect(described_class.build_address_record_attributes({"address_zipcode" => "12345"})).to eq({"postal_code" => "12345"})
    end

    it "converts region_string from state" do
      expect(described_class.build_address_record_attributes({"state" => "CA"})).to eq({"region_string" => "CA"})
    end

    it "converts region_string from address_state" do
      expect(described_class.build_address_record_attributes({"address_state" => "CA"})).to eq({"region_string" => "CA"})
    end

    it "converts country_id from country" do
      expect(described_class.build_address_record_attributes({"country" => "US"})).to eq({"country_id" => "US"})
    end

    it "converts country_id from address_country" do
      expect(described_class.build_address_record_attributes({"address_country" => "US"})).to eq({"country_id" => "US"})
    end

    it "converts all legacy fields at once" do
      bike_params = {
        "address" => "123 Main St",
        "address_city" => "Chicago",
        "state" => "IL",
        "zipcode" => "60601",
        "country" => "US"
      }
      expect(described_class.build_address_record_attributes(bike_params)).to eq({
        "street" => "123 Main St",
        "city" => "Chicago",
        "region_string" => "IL",
        "postal_code" => "60601",
        "country_id" => "US"
      })
    end
  end

  describe "cleaned_bike_params" do
    it "removes legacy keys and adds address_record_attributes" do
      bike_params = {
        "owner_email" => "test@example.com",
        "address" => "123 Main St",
        "city" => "Chicago",
        "state" => "IL",
        "zipcode" => "60601"
      }
      result = described_class.cleaned_bike_params(bike_params)
      expect(result).to eq({
        "owner_email" => "test@example.com",
        "address_record_attributes" => {
          "street" => "123 Main St",
          "city" => "Chicago",
          "region_string" => "IL",
          "postal_code" => "60601"
        }
      })
    end

    it "merges with existing address_record_attributes" do
      bike_params = {
        "address_record_attributes" => {"street" => "existing"},
        "city" => "Chicago"
      }
      result = described_class.cleaned_bike_params(bike_params)
      expect(result["address_record_attributes"]).to eq({
        "street" => "existing",
        "city" => "Chicago"
      })
    end

    it "returns unchanged when no legacy keys present" do
      bike_params = {"owner_email" => "test@example.com", "serial_number" => "ABC123"}
      expect(described_class.cleaned_bike_params(bike_params)).to eq(bike_params)
    end
  end

  describe "each_iteration" do
    let(:instance) { described_class.new }
    let(:b_param) do
      FactoryBot.create(:b_param, params: {
        "bike" => {
          "owner_email" => "test@example.com",
          "address" => "123 Main St",
          "city" => "Chicago",
          "state" => "IL",
          "zipcode" => "60601"
        }
      })
    end

    it "updates the b_param params" do
      instance.each_iteration(b_param)
      b_param.reload

      expect(b_param.params["bike"]["address"]).to be_nil
      expect(b_param.params["bike"]["city"]).to be_nil
      expect(b_param.params["bike"]["state"]).to be_nil
      expect(b_param.params["bike"]["zipcode"]).to be_nil
      expect(b_param.params["bike"]["owner_email"]).to eq("test@example.com")
      expect(b_param.params["bike"]["address_record_attributes"]).to eq({
        "street" => "123 Main St",
        "city" => "Chicago",
        "region_string" => "IL",
        "postal_code" => "60601"
      })
    end
  end
end
