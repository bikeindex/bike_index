# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::SearchAll::Component, type: :component do
  let(:component) { render_inline(described_class.new(settings:, locked:, locked_hint: "Why it's locked")) }
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:, search_all: true) }
  let(:locked) { false }

  it "renders the checkbox checked from the settings, its hint hidden" do
    expect(component).to have_field("search_all", checked: true, disabled: false)
    expect(component).to have_text("Search all registrations (not just Brakebills)")
    expect(component).to have_css("span[data-org--search-target='searchAllHint'][hidden]", visible: :all)
  end

  context "when locked" do
    let(:locked) { true }

    it "disables the checkbox and shows the hint" do
      expect(component).to have_field("search_all", disabled: true)
      expect(component).to have_css("span[data-org--search-target='searchAllHint']:not([hidden])")
      expect(component).to have_css("button[aria-label=\"Why it's locked\"]")
    end
  end
end
