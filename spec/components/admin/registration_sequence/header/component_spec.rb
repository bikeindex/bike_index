# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::RegistrationSequence::Header::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:registration_sequence) { FactoryBot.create(:registration_sequence, organization:) }
  let(:admin_url) { "/admin/registration_sequences/#{registration_sequence.id}" }

  it "names the organization and status, and links the sequence's three screens" do
    render_inline(described_class.new(registration_sequence:))

    expect(page).to have_content("Viewing Brakebills E-Vehicle Draft registration sequence", normalize_ws: true)
    expect(page).to have_link("View", href: admin_url)
    expect(page).to have_link("Preview", href: "#{admin_url}/preview")
    expect(page).to have_link("Edit", href: "#{admin_url}/edit")
    expect(page).to have_link("View in organization", href: "/o/#{organization.to_param}/registration_sequences/#{registration_sequence.id}")
    # Nothing to explain while it's editable
    expect(page).to_not have_css("[role='tooltip']", visible: :all)
    # Making the draft live is the header's action; discarding it lives at the foot of the page
    expect(page).to have_css("form[action='#{admin_url}?activate=true'] button", text: "Activate")
    expect(page).to_not have_button("Create draft")
    expect(page).to_not have_button("Discard draft")
  end

  it "marks the screen it's on" do
    render_inline(described_class.new(registration_sequence:, mode: :preview))

    expect(page).to have_content("Previewing Brakebills E-Vehicle Draft", normalize_ws: true)
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

      expect(page).to have_content("Editing Brakebills E-Vehicle Current", normalize_ws: true)
      expect(page).to_not have_link("Edit")
      expect(page).to have_css("button[disabled]", text: "Edit")
      # A disabled button can't be hovered, so the tooltip carries the reason
      expect(page).to have_css("[role='tooltip']", text: "Can't edit current registration sequence - create a draft", visible: :all)
      # The other two stay reachable
      expect(page).to have_link("View", href: admin_url)
      expect(page).to have_link("Preview", href: "#{admin_url}/preview")
      # What the inert Edit chip points at instead
      expect(page).to have_css("form[action='/admin/registration_sequences?kind=e_vehicle&organization_id=#{organization.id}'] button",
        text: "Create draft")
      expect(page).to_not have_button("Activate")
    end

    context "with a draft already open" do
      let!(:draft) { FactoryBot.create(:registration_sequence, organization:) }

      it "points at the draft that exists rather than offering a new one" do
        render_inline(described_class.new(registration_sequence:))

        expect(page).to have_button("Edit draft")
        expect(page).to_not have_button("Create draft")
      end
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

    it "names the template's status, with no organization to view it in" do
      render_inline(described_class.new(registration_sequence:))

      expect(page).to have_content("Viewing Template E-Vehicle Draft registration sequence", normalize_ws: true)
      expect(page).to have_link("Edit", href: "#{admin_url}/edit")
      expect(page).to_not have_link("View in organization")
      expect(page).to have_button("Activate")
    end

    context "live" do
      let(:registration_sequence) { FactoryBot.create(:registration_sequence_template_active) }

      it "is frozen like any live sequence, and drafts without an organization" do
        render_inline(described_class.new(registration_sequence:, mode: :edit))

        expect(page).to have_content("Editing Template E-Vehicle Current registration sequence", normalize_ws: true)
        expect(page).to have_css("button[disabled]", text: "Edit")
        expect(page).to have_css("form[action='/admin/registration_sequences?kind=e_vehicle'] button", text: "Create draft")
      end
    end
  end
end
