# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::Search::SearchAll::Component, type: :component do
  let(:component) do
    render_inline(described_class.new(settings:, lock:, locked_hints: {email: "Why it's locked", impounded: "Why else"}))
  end
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:, search_all: true) }
  let(:lock) { nil }

  it "renders the checkbox checked from the settings, its hints hidden" do
    expect(component).to have_field("search_all", checked: true, disabled: false)
    expect(component).to have_text("Search all registrations (not just Brakebills)")
    expect(component).to have_css("span[data-org--search-target='searchAllHint'][hidden]", visible: :all, count: 2)
  end

  context "when locked" do
    let(:lock) { :impounded }

    it "disables the checkbox and shows only that lock's hint" do
      expect(component).to have_field("search_all", disabled: true)
      expect(component).to have_css("span[data-lock='impounded']:not([hidden])")
      expect(component).to have_css("button[aria-label=\"Why else\"]")
      expect(component).to have_css("span[data-lock='email'][hidden]", visible: :all)
    end
  end
end
