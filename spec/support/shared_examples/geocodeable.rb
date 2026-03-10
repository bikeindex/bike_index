# frozen_string_literal: true

RSpec.shared_examples "geocodeable#clean_city" do
  let(:record) { described_class.new(city:, country_id: Country.united_states_id, region_record_id:, skip_geocoding: true) }
  let(:region_record_id) { nil }

  context "with city containing state abbreviation" do
    let(:city) { "Sacramento, CA" }

    it "removes state abbreviation and assigns region" do
      california = FactoryBot.create(:state_california)
      record.valid?
      expect(record.city).to eq "Sacramento"
      expect(record.region_record_id).to eq california.id
    end
  end

  context "with city containing state abbreviation and region already assigned" do
    let(:city) { "Sacramento, CA" }
    let(:region_record_id) { FactoryBot.create(:state_california).id }

    it "removes state abbreviation when matching" do
      record.valid?
      expect(record.city).to eq "Sacramento"
    end
  end

  context "with city containing non-matching state abbreviation" do
    let(:city) { "Sacramento, NY" }
    let(:region_record_id) { FactoryBot.create(:state_california).id }

    it "does not remove the abbreviation" do
      record.valid?
      expect(record.city).to eq "Sacramento, NY"
    end
  end

  context "with period separator" do
    let(:city) { "Sacramento. CA" }

    it "removes state abbreviation" do
      FactoryBot.create(:state_california)
      record.valid?
      expect(record.city).to eq "Sacramento"
    end
  end

  context "with non-US country" do
    let(:record) { described_class.new(city: "Amsterdam, NH", country_id: Country.netherlands.id, skip_geocoding: true) }

    it "does not modify city" do
      record.valid?
      expect(record.city).to eq "Amsterdam, NH"
    end
  end

  context "with plain city name" do
    let(:city) { "Sacramento" }

    it "leaves city unchanged" do
      record.valid?
      expect(record.city).to eq "Sacramento"
    end
  end
end
