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

  it "leads with a frozen view link to the bike, then its photo" do
    expect(component).to have_css("tbody td:first-child a[href='/bikes/#{bike.id}?organization_id=#{organization.to_param}']", text: "View")
    expect(component.css("th").first["class"]).to include("tw:sticky")
    expect(component).to have_css("th:nth-child(2).photo_cell", text: "Photo")
    expect(component).to have_css("tbody td.color_cell", text: bike.primary_frame_color.name)
  end

  context "with a pedal bike and an e-bike" do
    let(:e_bike) { FactoryBot.create(:bike_organized, creation_organization: organization, propulsion_type: "pedal-assist") }
    let(:bikes) { [bike, e_bike] }

    it "leaves pedal blank in the e-vehicle column" do
      expect(bike.propulsion_type).to eq "foot-pedal"
      expect(component.css("td.propulsion_type_cell").map { |td| td.text.strip }).to eq ["", e_bike.propulsion_titleize]
    end
  end

  it "renders plain headers when not sortable" do
    expect(component).to have_css("th", text: "Registered")
    expect(component).not_to have_css("th a")
  end

  # The organization rather than the viewer, so every member reads the one cached row
  context "with a hidden-serial bike registered with the organization" do
    let(:bike) { FactoryBot.create(:bike_organized, :impounded, creation_organization: organization).reload }

    it "reveals the serial to the organization" do
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

    let(:header_cells) do
      component.css("th.hideableColumn").map { |th| th["class"].split.find { |klass| klass.end_with?("_cell") } }
    end

    it "heads one column per settings checkbox, and no others" do
      expect(header_cells).to match_array(settings.enabled_columns)
    end

    it "places the organization's registration fields beside the columns they relate to" do
      expect(header_cells.each_cons(2)).to include(%w[owner_name_cell reg_phone_cell],
        %w[reg_phone_cell reg_student_id_cell], %w[reg_student_id_cell reg_organization_affiliation_cell],
        %w[serial_number_cell reg_extra_registration_number_cell])
      # Placed nowhere, so after the columns every organization has
      expect(header_cells.index("reg_address_cell")).to be > header_cells.index("propulsion_type_cell")
    end

    it "heads the columns with the shared labels" do
      expect(component).to have_css("th.avery_cell", normalize_ws: true, exact_text: "Avery Exportable")
      expect(component).to have_css("th.propulsion_type_cell", normalize_ws: true, exact_text: "E-vehicle (propulsion)")
      expect(component).to have_css("th.notes_cell", normalize_ws: true,
        exact_text: "Registration Notes by #{organization.short_name}")
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
      expect(component).to have_css("th.acknowledgment_cell span[title='Registration sequence acknowledgment at']",
        visible: :all, normalize_ws: true, exact_text: "Reg acknowledged")
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
    end

    # The org's own display_id, which is what its impound records index and their URLs
    # use - not the global record id
    context "with an impounded bike" do
      let!(:impound_record) do
        FactoryBot.create(:impound_record_with_organization, organization:, bike:)
      end

      it "renders the impound record's display_id" do
        expect(bike.reload.status_impounded?).to be true
        expect(impound_record.reload.display_id).to be_present
        expect(impound_record.display_id).to_not eq impound_record.id.to_s
        expect(component.css("td.impound_id_cell").text.strip).to eq impound_record.display_id
      end
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
        expect(component).to have_css(".#{cell} button em.less-strong", text: "hidden")
        expect(component).to have_css(".#{cell} [role=tooltip]", text: hidden_text, visible: :all)
      end
    end
  end

  let(:cached_record) { bike }
  it_behaves_like "cached_table_rows"

  # Which columns render follows the organization's features and fields
  context "with caching", :caching do
    include_context :caching_basic

    def render_table
      with_request_url("/o/#{organization.to_param}/registrations") { render_inline(described_class.new(**options)) }
    end

    it "keys each row to the organization's version" do
      expect(fragments_written { render_table }.first).to include(organization.cache_key_with_version)
      expect(fragments_written { render_table }).to eq([])

      organization.update(name: "Renamed org")
      expect(fragments_written { render_table }.count).to eq 1
    end
  end
end
