# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::Edit::Component, type: :component do
  let(:component) { render_inline(described_class.new(bike:, organizations:)) }
  let(:bike) { FactoryBot.create(:bike, :with_ownership, serial_number: "og serial") }
  let(:organizations) { Organization.all }

  it "renders the form wired to the stimulus controller, with the serial's original value" do
    form = component.css("form.admin-bike-edit").first
    expect(form["data-controller"]).to eq "admin--bike-edit-form"
    expect(form["data-admin--bike-edit-form-original-serial-value"]).to eq "og serial"

    serial = component.css("[data-admin--bike-edit-form-target=serial]").first
    expect(serial["value"]).to eq "og serial"
    expect(serial["class"]).to_not include("fake-disabled")
  end

  it "renders the no-serial checkboxes with the sentinel each one assigns" do
    checkboxes = component.css("[data-admin--bike-edit-form-target=noSerial]")
    expect(checkboxes.map { it["data-serial"] }).to eq(%w[unknown made_without_serial])
    expect(checkboxes.map { it["checked"] }).to eq([nil, nil])
  end

  context "with an unknown serial" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership, serial_number: "unknown") }

    it "checks 'Unknown serial' and greys out the serial field" do
      expect(component.css("#has_no_serial").first["checked"]).to be_present
      expect(component.css("[data-admin--bike-edit-form-target=serial]").first["class"]).to include("fake-disabled")
    end
  end

  it "doesn't render the legacy JS hooks, which the vendored admin bundle still binds" do
    expect(component.css(".serial-check")).to be_blank
    expect(component.css("#stolenCheckBox")).to be_blank
    expect(component.css(".fancy-select")).to be_blank
  end

  it "renders every field through UI::Forms::Group, and no bootstrap form classes" do
    expect(component.css("form .form-control")).to be_blank
    expect(component.css("form .form-group")).to be_blank
    # skip_email is its own label, so the required marker stays with "Owner email"
    expect(component.css("label[for=bike_owner_email]").text.strip).to eq "Owner email *"
    expect(component.css("input#bike_owner_email").first["class"]).to eq "twinput"
  end

  it "renders primary_activity as a combobox rather than a select" do
    expect(component.css("select#bike_primary_activity_id")).to be_blank
    expect(component.css("input[name='bike[primary_activity_id]']")).to be_present
  end

  context "with organizations" do
    let!(:organization) { FactoryBot.create(:organization, name: "Cool Bike Shop") }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership, creation_organization: organization) }

    it "renders the current orgs as a multiselect combobox holding the comma-joined ids" do
      combobox = component.css("input[name='bike[bike_organization_ids]']").first
      expect(combobox["value"]).to eq organization.id.to_s
      expect(component.css("[data-hw-combobox-selection-chip-src-value]").first["data-hw-combobox-selection-chip-src-value"])
        .to eq "/admin/combobox/organization_chips"
    end

    it "lists the bike_organizations in a UI::Table" do
      table = component.css("table.ui-table").first
      expect(table.css("th").map { it.text.strip }).to eq(["Organizations", "Created", "Edit claimed?", "Deleted"])
      expect(table.css("tbody tr").length).to eq 1
      expect(table.css("tbody tr").text).to include("Cool Bike Shop")
      expect(component.text).to_not include("No organizations")
    end

    context "with the organization deleted" do
      before { organization.destroy }

      # Admin::OrganizationCell resolves it unscoped, where the association reads nil
      it "still names the organization, and flags it deleted" do
        row = component.css("table.ui-table tbody tr").text
        expect(row).to include("Cool Bike Shop")
        expect(row).to match(/deleted!/)
      end
    end
  end

  it "renders the empty state rather than an empty table" do
    expect(component.css("table.ui-table")).to be_blank
    expect(component.text).to include("No organizations")
  end

  context "with a stolen bike" do
    let(:bike) { FactoryBot.create(:stolen_bike, :with_ownership) }

    it "renders the recovery fields collapsed, revealed by unchecking 'Bike is stolen'" do
      stolen = component.css("[data-admin--bike-edit-form-target=stolen]").first
      expect(stolen["checked"]).to be_present
      expect(stolen["data-action"]).to eq "change->admin--bike-edit-form#stolenChanged"

      recovery_fields = component.css("[data-admin--bike-edit-form-target=recoveryFields]").first
      expect(recovery_fields["class"]).to include("tw:hidden")
      expect(recovery_fields.css("[data-admin--bike-edit-form-target=recoveryReason]")).to be_present
    end
  end
end
