# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Org::SearchResults::BikesTable::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) do
    with_request_url("/o/#{organization.to_param}/registrations") do
      render_inline(instance)
    end
  end
  let(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs:) }
  let(:enabled_feature_slugs) { %w[bike_search] }
  let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization) }
  let(:bikes) { [bike] }
  let(:options) { {organization:, bikes:} }

  it "renders a table row with the bike data" do
    expect(component).to have_css("table")
    expect(component).to have_css("tbody tr", count: 1)
    expect(component).to have_text(bike.mnfg_name)
  end

  it "renders plain headers when not sortable" do
    expect(component).to have_css("th", text: "Registered")
    expect(component).not_to have_css("th a.twlink")
  end

  context "with a hidden-serial bike and an authorized org member" do
    let(:current_user) { FactoryBot.create(:organization_role_claimed, organization:).user }
    let(:options) { super().merge(current_user:) }
    let(:bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization).reload }

    it "passes the current user through so the hidden serial is revealed" do
      expect(bike.serial_hidden?).to be_truthy
      expect(component).to have_css(".serial_number_cell .serial-span", text: bike.serial_number.upcase)
      expect(component).to have_no_css(".serial_number_cell", text: "Hidden")
    end
  end

  context "with injected settings" do
    let(:other_org) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[reg_phone]) }
    let(:injected) { ComponentStructs::OrgSearchSettings.new(organization: other_org) }
    let(:options) { super().merge(settings: injected) }

    it "derives columns from the injected settings, not freshly built ones" do
      # the table's own organization has no reg_phone; the injected settings does
      expect(component).to have_css("th.reg_phone_cell", visible: :all)
    end
  end

  context "with every column's feature enabled" do
    let(:enabled_feature_slugs) do
      %w[bike_search avery_export bike_stickers impound_bikes registration_notes registration_sequences
        reg_address reg_extra_registration_number reg_organization_affiliation reg_phone reg_student_id]
    end
    # The panel builds a checkbox per enabled_columns entry, and org--search-column-settings
    # only ever reveals a column whose cell class matches a checked one
    let(:settings) { ComponentStructs::OrgSearchSettings.new(organization:) }

    it "heads one column per settings checkbox, and no others" do
      headers = component.css("th.hideableColumn")
        .map { |th| th["class"].split.find { |klass| klass.end_with?("_cell") } }

      expect(headers).to match_array(settings.enabled_columns)
    end

    it "heads the columns with the shared labels" do
      expect(component).to have_css("th.avery_cell", normalize_ws: true, exact_text: "Avery Exportable")
      expect(component).to have_css("th.propulsion_type_cell", normalize_ws: true, exact_text: "E-vehicle (propulsion)")
      expect(component).to have_css("th.notes_cell", normalize_ws: true,
        exact_text: "Registration Notes · #{organization.short_name}")
    end
  end

  context "with reg_student_id enabled" do
    let(:enabled_feature_slugs) { %w[bike_search reg_student_id] }
    let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: organization) }
    before { bike.current_ownership.update(registration_info: {"student_id" => "JD_4821"}) }

    it "renders the student ID as registered" do
      expect(component).to have_css("td.reg_student_id_cell", exact_text: "JD_4821", normalize_ws: true)
    end
  end

  context "with registration_sequences enabled" do
    let(:enabled_feature_slugs) { %w[bike_search registration_sequences] }
    let(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, propulsion_type: "pedal-assist") }
    let(:unacknowledged_bike) { FactoryBot.create(:bike_organized, creation_organization: organization, propulsion_type: "pedal-assist") }
    let(:bikes) { [bike, unacknowledged_bike] }
    let(:registration_sequence) { FactoryBot.create(:registration_sequence_active, organization:) }
    let!(:acknowledgment) { FactoryBot.create(:registration_sequence_acknowledgment, registration_sequence:, bike:) }

    it "renders when each bike was acknowledged" do
      expect(component).to have_css("th.acknowledgment_cell", visible: :all, normalize_ws: true, exact_text: "Registration sequence acknowledgment")
      expect(component.css("td.acknowledgment_cell .localizeTime").count).to eq 1
    end

    context "with a bike registered elsewhere" do
      let(:other_bike) { FactoryBot.create(:bike, propulsion_type:) }
      let(:bikes) { [other_bike] }
      let(:propulsion_type) { "pedal-assist" }

      it "renders the e-vehicle as hidden" do
        expect(component).to have_css("td.acknowledgment_cell", text: "hidden")
        expect(component).to have_css("td.acknowledgment_cell [role=tooltip]", text: "Hidden because it is not registered", visible: :all)
      end

      context "that isn't an e-vehicle" do
        let(:propulsion_type) { "foot-pedal" }

        it "renders nothing" do
          expect(component).to have_no_css("td.acknowledgment_cell", text: "hidden")
        end
      end
    end
  end

  context "with render_sortable" do
    let(:options) { {organization:, bikes:, render_sortable: true} }

    it "renders sortable header links" do
      expect(component).to have_css("th a.twlink")
    end
  end

  context "with impound_bikes enabled" do
    let(:enabled_feature_slugs) { %w[bike_search impound_bikes] }

    it "renders the impound columns" do
      expect(component).to have_css("th.impound_id_cell", visible: :all, text: "Impound ID")
      expect(component).to have_css("th.impounded_cell", visible: :all, text: "Impounded")
    end
  end

  context "when a bike does not belong to the organization" do
    let(:enabled_feature_slugs) { %w[bike_search reg_phone reg_extra_registration_number] }
    let(:other_org) { FactoryBot.create(:organization) }
    let(:bike) do
      FactoryBot.create(:bike_organized,
        creation_organization: other_org,
        owner_email: "stranger@example.com",
        extra_registration_number: "SECRET-EXTRA",
        phone: "555-555-1212")
    end

    it "redacts every registration field, leaving public columns visible" do
      expect(component).to have_css("tbody tr", count: 1)
      expect(component).to have_text(bike.mnfg_name)
      expect(component).not_to have_text("stranger@example.com")
      expect(component).not_to have_text("555-555-1212")
      expect(component).not_to have_text("SECRET-EXTRA")
      hidden_text = "Hidden because it is not registered with #{organization.short_name}"
      %w[owner_email_cell reg_phone_cell reg_extra_registration_number_cell].each do |cell|
        expect(component).to have_css(".#{cell} em.less-strong", text: "hidden")
        expect(component).to have_css(".#{cell} [role=tooltip]", text: hidden_text, visible: :all)
      end
    end
  end

  let(:cached_record) { bike }
  it_behaves_like("cached_table_rows") { let(:row_cache_key) { "org-#{organization.id}-#{described_class.cache_digest}" } }
end
