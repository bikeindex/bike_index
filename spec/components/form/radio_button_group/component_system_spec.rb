# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::RadioButtonGroup::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/form/radio_button_group/component/" }

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
