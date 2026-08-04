# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSequence::PageEdit::Component, type: :component do
  let(:page) { RegistrationSequencePage.new(body: "<ul><li>first bullet</li></ul>") }

  def rendered_component(page)
    render_in_view_context do
      form_for page, url: "#", method: :patch do |f|
        render(Org::RegistrationSequence::PageEdit::Component.new(form_builder: f))
      end
    end
  end

  let(:component) { rendered_component(page) }

  it "renders a hidden body field and a Lexxy editor per bullet" do
    expect(component).to have_css("input[type=hidden][name='registration_sequence_page[body]']", visible: :all)
    expect(component).to have_css("lexxy-editor[name='bullet[0][content]']", visible: :all)
    expect(component).to_not have_field("registration_sequence_page_listing_order")
    # Only an organization's own draft can badge a page with its name
    expect(component).to_not have_field("registration_sequence_page_organization_specific")
  end

  context "on an organization's draft" do
    let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
    let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }
    let(:page) { FactoryBot.create(:registration_sequence_page, registration_sequence:) }

    it "offers the organization-specific toggle, named after the organization" do
      expect(component).to have_field("registration_sequence_page_organization_specific")
      expect(component).to have_content("specific to Brakebills")
    end
  end
end
