# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::RadioButtonGroup::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/radio_button_group/component/" }
  # match_style retries, so it waits out the color transition
  let(:purple) { {"background-color" => "rgb(113, 94, 178)"} }
  let(:white) { {"background-color" => "rgb(255, 255, 255)"} }
  let(:transparent) { {"background-color" => "rgba(0, 0, 0, 0)"} }

  def label(text) = find("label", text:)

  context "default" do
    it "renders and selects on click" do
      visit("#{base_path}default")

      expect(page).to have_css "label", count: 3
      expect(page).to have_content "All"
      expect(page).to have_content "Active"
      expect(page).to have_content "Inactive"
      expect(page).to have_css "input[name='search_status'][value=''][checked]", visible: :all
      expect_axe_clean

      find("label", text: "Active").click
      expect(page).to have_css "input[name='search_status'][value='active']:checked", visible: :all

      find("label", text: "Inactive").click
      expect(page).to have_css "input[name='search_status'][value='inactive']:checked", visible: :all
      # The is-active variant matches a label around a checked radio
      expect(label("Inactive")).to match_style(purple)
      expect(label("Active")).to match_style(white)
    end
  end

  context "toggle" do
    it "raises the checked segment" do
      visit("#{base_path}toggle")

      expect(label("Set on map")).to match_style(white)
      expect(label("Enter address manually")).to match_style(transparent)

      find("label", text: "Enter address manually").click
      expect(page).to have_css "input[name='location_mode'][value='entered']:checked", visible: :all
      expect(label("Enter address manually")).to match_style(white)
      expect(label("Set on map")).to match_style(transparent)
    end
  end

  context "with_html_labels" do
    it "keeps spaces around inline markup" do
      visit("#{base_path}with_html_labels")

      # The label is inline-flex, so each text run/element is a separate flex
      # item — without a wrapper the whitespace between them gets collapsed.
      expect(find("label", text: "only not impounded")).to be_present
      expect(find("label", text: "only impounded")).to be_present
    end
  end

  context "with_selection" do
    it "renders with pre-selected value" do
      visit("#{base_path}with_selection")

      expect(page).to have_css "input[name='search_filter'][value='active'][checked]", visible: :all
    end
  end
end
