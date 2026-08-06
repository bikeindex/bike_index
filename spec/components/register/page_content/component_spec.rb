# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::PageContent::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:, faq_url: "https://example.com/faq") }
  let(:page_record) do
    FactoryBot.build(:registration_sequence_page, registration_sequence:, title: "Battery safety",
      heading: "Charge safely", subtitle: "A few rules",
      body: "<ul><li>Use the right charger</li><li>Store it cool</li></ul>")
  end
  # In real use the control lambda is defined in a template, where view helpers exist;
  # here a plain string stands in for whatever checkbox the caller renders.
  let(:control) { ->(index) { %(<input type="checkbox" data-index="#{index}">).html_safe } }

  it "renders the heading, the title as a section label, and a control per bullet" do
    render_inline(described_class.new(page: page_record, control:))

    expect(page).to have_css("h1", text: "Charge safely") # heading_text, big like the flow
    expect(page).to have_content("Battery safety") # the title labels the rules
    expect(page).to have_css("input[type=checkbox][data-index='0']")
    expect(page).to have_css("input[type=checkbox][data-index='1']")
    expect(page).to have_content("Use the right charger")
    expect(page).to have_link("E-Vehicle Acknowledgment FAQ", href: "https://example.com/faq")
  end

  it "badges the opening page as the electric detection" do
    render_inline(described_class.new(page: page_record, control:, first: true))

    expect(page).to have_content("Electric (motorized) detected")
    expect(page).to have_no_content("Brakebills")
  end

  context "organization_specific page" do
    it "badges with the organization's name" do
      page_record.organization_specific = true
      render_inline(described_class.new(page: page_record, control:))

      expect(page).to have_content("Brakebills")
      expect(page).to have_no_content("Electric (motorized) detected")
    end
  end

  context "without an faq_url" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }

    it "leaves out the FAQ affordance" do
      render_inline(described_class.new(page: page_record, control:))

      expect(page).to have_no_link("E-Vehicle Acknowledgment FAQ")
    end
  end
end
