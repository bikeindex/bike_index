# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::Org::ImpoundCurrentLocation::Component, type: :component do
  let(:component) { render_inline(described_class.new(impound_record:)) }

  context "without a location or an address" do
    let(:impound_record) { FactoryBot.create(:impound_record_with_organization) }

    it "does not render" do
      expect(component.to_html).to be_blank
    end
  end

  context "held at a location without an address" do
    let(:location) { FactoryBot.create(:location, name: "Back lot") }
    let(:impound_record) { FactoryBot.create(:impound_record_with_organization, location:) }

    it "renders just the location" do
      expect(impound_record.reload.address_record_id).to be_nil
      expect(component).to have_text("Back lot")
      expect(component).not_to have_text("same as impounded from")
    end
  end

  context "impounded from an address" do
    let(:impound_record) { FactoryBot.create(:impound_record_with_organization, :with_address_record) }

    it "renders that it's the same as where it was impounded from" do
      expect(component).to have_text("same as impounded from")
      expect(component).not_to have_text("1300 W 14th Pl")
    end

    context "saved before impounded_from_address_record existed" do
      before { impound_record.update_column(:impounded_from_address_record_id, nil) }

      it "still knows it's where it was impounded from" do
        expect(impound_record.reload.impounded_from_address).to eq impound_record.address_record
        expect(component).to have_text("same as impounded from")
      end
    end

    context "held at a location" do
      let(:location) { FactoryBot.create(:location, :with_address_record, address_in: :new_york, name: "Back lot") }
      let(:impound_record) { FactoryBot.create(:impound_record_with_organization, :with_address_record, location:) }

      it "renders the location and its address" do
        expect(component).to have_css("strong", text: "Back lot")
        expect(component).to have_text("278 Broadway")
        expect(component).not_to have_text("same as impounded from")
      end
    end
  end
end
