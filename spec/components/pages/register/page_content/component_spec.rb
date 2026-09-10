# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::PageContent::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:, faq_url: "https://example.com/faq") }
  let(:page_record) do
    FactoryBot.build(:registration_sequence_page, registration_sequence:, title: "Battery safety",
      heading: "Charge safely", subtitle: "A few rules",
      body: "<ul><li>Use the right charger</li><li>Store it cool</li></ul>")
  end

  it "renders the heading, the title as a section label, and a decorative checkbox per rule" do
    render_inline(described_class.new(page: page_record))

    expect(page).to have_css("h1", text: "Charge safely") # heading_text, big like the flow
    expect(page).to have_content("Battery safety") # the title labels the rules
    expect(page).to have_content("Use the right charger")
    expect(page).to have_link("E-Vehicle Acknowledgment FAQ", href: "https://example.com/faq")
    # Nameless, so the preview's GET form doesn't serialize them
    expect(page).to have_css("input[type=checkbox]:not([name])", count: 2)
  end

  it "names the checkboxes for the flow to submit" do
    render_inline(described_class.new(page: page_record, checkbox_name: :acknowledged, checked: true))

    expect(page).to have_css("input[type=checkbox][name='acknowledged[0]'][checked]")
    expect(page).to have_css("input[type=checkbox][name='acknowledged[1]'][checked]")
  end

  it "badges the opening page as the electric detection" do
    render_inline(described_class.new(page: page_record, first: true))

    expect(page).to have_content("Electric (motorized) detected")
    expect(page).to have_no_content("Brakebills")
  end

  context "organization_specific page" do
    it "badges with the organization's name" do
      page_record.organization_specific = true
      render_inline(described_class.new(page: page_record))

      expect(page).to have_content("Brakebills")
      expect(page).to have_no_content("Electric (motorized) detected")
    end

    context "on the template" do
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_template) }

      it "badges the template, matching what the editor promised" do
        page_record.organization_specific = true
        render_inline(described_class.new(page: page_record))

        expect(page).to have_content("Template")
      end
    end
  end

  context "without an faq_url" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }

    it "leaves out the FAQ affordance" do
      render_inline(described_class.new(page: page_record))

      expect(page).to have_no_link("E-Vehicle Acknowledgment FAQ")
    end
  end
end
