# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::RegistrationSequence::Header::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }
  let(:admin_url) { "/admin/registration_sequences/#{registration_sequence.id}" }

  it "names the organization and status, and links the sequence's three screens" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_content("Viewing Brakebills Draft registration sequence", normalize_ws: true)
    expect(page).to have_link("View", href: admin_url)
    expect(page).to have_link("Preview", href: "#{admin_url}/preview")
    expect(page).to have_link("Edit", href: "#{admin_url}/edit")
    expect(page).to have_link("View in organization", href: "/o/#{organization.to_param}/registration_sequences/#{registration_sequence.id}")
    # Nothing to explain while it's editable
    expect(page).to_not have_css("[role='tooltip']", visible: :all)
  end

  it "marks the screen it's on" do
    render_inline(described_class.new(registration_sequence:, mode: :preview))

    expect(page).to have_content("Previewing Brakebills Draft", normalize_ws: true)
    expect(page).to have_css("a[data-active='true']", count: 1)
    expect(page).to have_css("a[data-active='true']", text: "Preview")
  end

  it "raises on a screen it doesn't have" do
    expect { described_class.new(registration_sequence:, mode: :destroy) }.to raise_error(ArgumentError, /mode/)
  end

  context "activated sequence" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, organization:) }

    it "offers Edit as a disabled button - activation freezes it" do
      render_inline(described_class.new(registration_sequence:, mode: :edit))

      expect(page).to have_content("Editing Brakebills Current", normalize_ws: true)
      expect(page).to_not have_link("Edit")
      expect(page).to have_css("button[disabled]", text: "Edit")
      # A disabled button can't be hovered, so the tooltip carries the reason
      expect(page).to have_css("[role='tooltip']", text: "Can't edit current registration sequence - create a draft", visible: :all)
      # The other two stay reachable
      expect(page).to have_link("View", href: admin_url)
      expect(page).to have_link("Preview", href: "#{admin_url}/preview")
    end

    context "archived" do
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, organization:, end_at: Time.current) }

      it "names the status it can't edit" do
        render_inline(described_class.new(registration_sequence:))

        expect(page).to have_css("[role='tooltip']", text: "Can't edit previous registration sequence - create a draft", visible: :all)
      end
    end
  end

  context "template" do
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_template) }

    it "names the template once, with no organization to view it in" do
      render_inline(described_class.new(registration_sequence:))

      expect(page).to have_content("Viewing Template registration sequence", normalize_ws: true)
      expect(page).to have_link("Edit", href: "#{admin_url}/edit")
      expect(page).to_not have_link("View in organization")
    end
  end
end
