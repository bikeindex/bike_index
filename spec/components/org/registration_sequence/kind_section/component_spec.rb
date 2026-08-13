# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSequence::KindSection::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:base_url) { "/o/#{organization.to_param}/registration_sequences" }

  it "offers to start the kind's first sequence" do
    render_inline(described_class.new(organization:, kind: "non_e_vehicle", editable: true))

    expect(page).to have_css("h2", text: "Non-e-vehicle registrations")
    expect(page).to have_content("There is no active non-e-vehicle registration sequence")
    expect(page).to have_css("form[action='#{base_url}?kind=non_e_vehicle'] button", text: "Create a sequence")
  end

  context "with sequences of both kinds" do
    let!(:active) { FactoryBot.create(:registration_sequence_active, :with_pages, organization:) }
    let!(:non_e_vehicle_draft) do
      FactoryBot.create(:registration_sequence, :non_e_vehicle, :with_pages, organization:,
        acknowledgment_text: "agree to the bike rules")
    end

    it "shows only its own kind's sequences" do
      render_inline(described_class.new(organization:, kind: "non_e_vehicle", editable: true))

      expect(page).to have_content("There is no active non-e-vehicle registration sequence")
      expect(page).to have_content("Your draft sequence, last edited")
      expect(page).to have_css("form[action='#{base_url}/#{non_e_vehicle_draft.id}'] button", text: "Discard draft")
      expect(page).to_not have_css("form[action='#{base_url}/#{active.id}']")
    end

    it "hides the draft from an organization that can't edit" do
      render_inline(described_class.new(organization:, kind: "non_e_vehicle"))

      expect(page).to_not have_content("Your draft sequence, last edited")
      expect(page).to_not have_button("Discard draft")
      expect(page).to_not have_button("Create a sequence")
    end
  end

  context "with a superseded sequence" do
    let!(:archived) do
      FactoryBot.create(:registration_sequence_active, :non_e_vehicle, :with_pages, organization:,
        end_at: Time.current)
    end

    it "lists it under Previous" do
      render_inline(described_class.new(organization:, kind: "non_e_vehicle"))

      expect(page).to have_css("h3", text: "Previous")
      expect(page).to have_link("Preview", href: "#{base_url}/#{archived.id}")
    end
  end
end
