# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::MissingManufacturerTable::Component, type: :component do
  let(:bike) do
    FactoryBot.create(:bike, manufacturer: Manufacturer.other, manufacturer_other: "Wombat Cycles",
      year: 2019, frame_model: "Roadie")
  end
  let(:search_params) { {} }
  let(:index) do
    ComponentStructs::IndexState.new(params: search_params,
      sort_state: ComponentStructs::SortState.new(search_params:))
  end
  let(:options) { {} }
  let(:component) do
    with_request_url("/admin/bikes/missing_manufacturer") do
      render_inline(described_class.new(bikes: [bike], index:, **options))
    end
  end

  # UI::Table instance_execs its cell blocks, so every method a cell needs is passed as a
  # local - a cell reaching for the component directly renders nothing and raises
  it "renders each cell, including the ones that call component methods" do
    expect(component.css("input[data-table-multi-checkbox-target='checkbox']").count).to eq 1
    expect(component).to have_content("Wombat Cycles")
    expect(component).to have_content("2019 Roadie")
    expect(component).to have_link("search")
  end

  it "offers a toggle-all in the header" do
    expect(component.css("[data-action='click->table-multi-checkbox#toggleAll']").count).to eq 1
  end

  # Already searching that name makes a link to it useless
  context "when searching that other name" do
    let(:options) { {searched_other_name: "Wombat Cycles"} }

    it "drops the search link" do
      expect(component).to_not have_link("search")
    end
  end

  context "with a bike whose manufacturer_other is blank" do
    let(:bike) { FactoryBot.create(:bike, manufacturer: Manufacturer.other) }

    it "falls back to the mnfg_name" do
      expect(component.css("em").map { |e| e.text.strip }).to include bike.mnfg_name
    end
  end
end
