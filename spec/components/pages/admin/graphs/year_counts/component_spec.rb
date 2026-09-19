# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::Graphs::YearCounts::Component, type: :component do
  let(:component) { render_inline(described_class.new(bounding_box:)) }
  let(:headers) { component.css("thead th").map { |th| th.text.strip } }
  let(:current_year_counts) do
    row = component.css("tbody tr").find { |tr| tr.css("td").first.text.strip == Time.current.year.to_s }
    headers.zip(row.css("td").map { |td| td.text.split.first }).drop(1).to_h
  end

  context "everywhere" do
    let(:bounding_box) { nil }
    let(:cache_key) { "admin_graphs_year_counts_#{Time.current.year}" }
    let!(:stolen_record) { FactoryBot.create(:stolen_record) }
    # The test cache is a file_store, so a leftover entry would outlive the run
    around do |example|
      Rails.cache.delete(cache_key)
      example.run
      Rails.cache.delete(cache_key)
    end

    it "counts every stolen record, and registrations and users" do
      expect(headers.last).to eq "Users in year"
      expect(current_year_counts["Stolen in year"]).to eq "1"
      expect(current_year_counts["Stolen & non, in year"]).to eq "1"
    end
  end

  context "within a bounding box" do
    let(:bounding_box) { [33.91017581688915, -118.41733407395493, 34.19963938311085, -118.06795192604507] }
    let!(:recovered_in_los_angeles) { FactoryBot.create(:stolen_record_recovered, :in_los_angeles) }
    let!(:recovered_in_chicago) { FactoryBot.create(:stolen_record_recovered, :in_chicago) }

    # StolenRecord.recovered is unscoped, so chaining it here would count Chicago too
    it "only counts the records inside it, without the registration columns" do
      expect(headers.last).to eq "Recovered by eoy"
      expect(current_year_counts["Stolen in year"]).to eq "1"
      expect(current_year_counts["Recovered in year"]).to eq "1"
    end
  end
end
