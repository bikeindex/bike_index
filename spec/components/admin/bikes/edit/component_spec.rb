# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::Edit::Component, type: :component do
  let(:bike) { FactoryBot.create(:bike, :with_ownership) }
  let(:organizations) { Organization.all }
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(bike:, organizations:, **options)) }

  it "renders the form and its serial targets" do
    expect(component.css("form[data-controller='admin--bike-edit-form']").count).to eq 1
    expect(component.css("[data-admin--bike-edit-form-target='serial']").count).to eq 1
    expect(component.css("[data-admin--bike-edit-form-target='noSerial']").count).to eq 2
    expect(component).to have_content("No organizations")
  end

  # The sentinel each checkbox writes into the serial field is what Bike#serial_number reads
  it "names the serial sentinels on the checkboxes" do
    expect(component.css("[data-admin--bike-edit-form-target='noSerial']").map { |i| i["data-serial"] })
      .to eq %w[unknown made_without_serial]
  end

  context "without a stolen record" do
    it "renders no stolen fields" do
      expect(component).to_not have_content("Edit stolen record")
      expect(component.css("[data-admin--bike-edit-form-target='stolen']")).to be_empty
    end
  end

  context "with a stolen record" do
    let(:bike) { FactoryBot.create(:stolen_bike) }

    it "renders the stolen fields and the recovery toggle" do
      expect(component).to have_content("Edit stolen record")
      expect(component.css("[data-admin--bike-edit-form-target='stolen']").count).to eq 1
      expect(component.css("[data-admin--bike-edit-form-target='recoveryFields']").count).to eq 1
      expect(component.css("[data-admin--bike-edit-form-target='recoveryReason']").count).to eq 1
    end
  end

  context "with bike organizations" do
    let(:organization) { FactoryBot.create(:organization, name: "Cool Org") }
    let!(:bike_organization) { FactoryBot.create(:bike_organization, bike:, organization:) }

    it "renders them in the table" do
      expect(component).to_not have_content("No organizations")
      expect(component).to have_content("Cool Org")
    end

    # Deleted bike_organizations still matter to admins, so the table unscopes
    context "when deleted" do
      before { bike_organization.destroy }

      it "still renders the row" do
        expect(component).to have_content("Cool Org")
      end
    end
  end

  context "with a deleted bike" do
    before { bike.destroy }

    it "drops the delete button" do
      expect(component).to_not have_link("Delete #{bike.type}")
    end
  end
end
