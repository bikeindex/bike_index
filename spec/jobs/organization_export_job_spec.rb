require "rails_helper"

RSpec.describe OrganizationExportJob, type: :job do
  let(:subject) { OrganizationExportJob }
  let(:instance) { subject.new }
  let(:export) { FactoryBot.create(:export_organization, progress: "pending", file: nil) }
  let(:organization) { export.organization }
  let(:black) { Color.black }
  let(:trek) { FactoryBot.create(:manufacturer, name: "Trek") }
  let(:bike) { FactoryBot.create(:bike_organized, manufacturer: trek, primary_frame_color: black, creation_organization: organization) }
  let(:bike_row_hash) do
    {
      thumbnail: nil,
      registered_at: bike.created_at.utc,
      status: "",
      manufacturer: "Trek",
      model: nil,
      color: "Black",
      owner_email: bike.owner_email,
      owner_name: nil,
      registration_method: "web"
    }
  end
  let(:bike_values) { bike_row_hash.values }
  let(:csv_lines) { [export.written_headers, bike_values] }
  let(:csv_string) { csv_lines.map { |r| instance.comma_wrapped_string(r) }.join }

  def csv_line_to_hash(line_str, headers:)
    line = line_str.gsub(/\A"/, "").gsub(/"\z/, "").split('","')
      .map { |v| v.blank? ? nil : v }
    headers.map(&:to_sym).zip(line).to_h
  end

  describe "perform" do
    context "success" do
      before do
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        expect(export.file.present?).to be_falsey
      end
      it "does the thing we expect" do
        instance.perform(export.id)
        export.reload
        expect(export.progress).to eq "finished"
        generated_line_hash = csv_line_to_hash(export.file.read.split("\n").last, headers: export.written_headers)
        expect(generated_line_hash.keys).to eq bike_row_hash.keys # has to match the order!
        expect(generated_line_hash).to match_hash_indifferently(bike_row_hash)
        # Putting it all together
        expect(export.file.read).to eq(csv_string)
        expect(export.rows).to eq 1
      end
      context "xlsx format" do
        let(:export) { FactoryBot.create(:export_organization, progress: "pending", file: nil, file_format: "xlsx") }
        it "exports" do
          instance.perform(export.id)
          export.reload
          expect(export.progress).to eq "finished"
          expect(export.file.read).to be_present
          expect(export.rows).to eq 1
          expect(export.exported_bike_ids).to eq([bike.id])
        end
      end
      context "avery export" do
        let(:user) { FactoryBot.create(:superuser) }
        let(:export) { FactoryBot.create(:export_avery, progress: "pending", file: nil, bike_code_start: "a1111 ", user: user) }
        let(:bike_for_avery_og) do
          FactoryBot.create(:bike_organized,
            manufacturer: trek,
            primary_frame_color: black,
            creation_organization: organization,
            creation_registration_info: {
              street: "102 Washington Pl",
              street_2: "Apt Party",
              city: "State College",
              region_string: "PA",
              postal_code: "16801",
              user_name: "Maya Skripal"
            })
        end
        # Force unmemoize - TODO: might not be necessary
        let(:bike_for_avery) { Bike.find(bike_for_avery_og.id) }
        let(:bike_not_avery) do
          FactoryBot.create(:bike_organized,
            manufacturer: trek,
            primary_frame_color: black,
            creation_organization: organization,
            creation_registration_info: {
              street: "",
              city: "State College",
              region_string: "PA",
              postal_code: "16801",
              user_name: "George Washington"
            })
        end
        let(:csv_lines) do
          # We modify the headers during processing to separate the address into multiple fields
          [
            %w[owner_name address address_2 city state zipcode assigned_sticker],
            ["Maya Skripal", "102 Washington Pl", "Apt Party", "State College", "PA", "16801", "A 111 1"]
          ]
        end
        let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, code: "a1111") }
        let!(:state) { FactoryBot.create(:state, :find_or_create, name: "Pennsylvania", abbreviation: "PA", country: Country.united_states) }
        include_context :geocoder_real
        it "exports only bike with name, email and address" do
          VCR.use_cassette("organization_export_worker-avery") do
            expect(bike_not_avery.reload.current_ownership.address_record.street).to be_blank
            expect(bike_for_avery_og.reload.current_ownership.address_record.street).to be_present
            expect(bike_for_avery_og.current_ownership.address_record.street_2).to eq "Apt Party"
            bike.reload
            expect(bike_sticker.claimed?).to be_falsey
            export.update(file_format: "csv") # Manually switch to csv so that we can parse it more easily :/
            expect(organization.bikes.pluck(:id)).to match_array([bike.id, bike_for_avery.id, bike_not_avery.id])
            expect(Export.with_bike_sticker_code(bike_sticker).pluck(:id)).to eq([])
            expect(export.avery_export?).to be_truthy
            expect(export.headers).to eq Export::HEADERS_FOR_AVERY_EXPORT

            expect(BikeServices::CalculateLocation.registration_address_source(bike_for_avery)).to eq "initial_creation"
            bike_for_avery.update(updated_at: Time.current)
            expect(bike_for_avery.reload.avery_exportable?).to be_truthy
            expect(bike_for_avery.address_hash_legacy.except("country")).to eq bike_for_avery.registration_address.except("country", "address_record_id")
            bike_for_avery
            instance.perform(export.id)
            # Check this in here so the vcr geocoder records at the correct place
            expect(bike_not_avery.reload.registration_address["street"].present?).to be_falsey
            expect(bike_not_avery.avery_exportable?).to be_falsey
          end

          export.reload
          expect(export.progress).to eq "finished"
          expect(export.rows).to eq 1 # The bike without a user_name and address isn't exported
          expect(export.file.read).to eq(csv_string)
          # NOTE: This header needs to stay exactly the same or the avery export will break
          expect(export.written_headers).to eq(%w[owner_name address address_2 city state zipcode assigned_sticker])
          expect(export.bike_stickers_assigned).to eq(["A1111"])
          expect(export.bike_codes_removed?).to be_falsey
          expect(Export.with_bike_sticker_code(bike_sticker.code).pluck(:id)).to eq([export.id])
          bike_sticker.reload
          expect(bike_sticker.claimed?).to be_truthy
          expect(bike_sticker.bike).to eq bike_for_avery
          expect(bike_sticker.user).to eq export.user
          expect(bike_sticker.claimed_at).to be_within(1.second).of Time.current

          expect(bike_sticker.bike_sticker_updates.count).to eq 1
          bike_sticker_update = bike_sticker.bike_sticker_updates.first
          expect(bike_sticker_update.kind).to eq "initial_claim"
          expect(bike_sticker_update.creator_kind).to eq "creator_export"
          expect(bike_sticker_update.organization_kind).to eq "primary_organization"
          expect(bike_sticker_update.user).to eq user
          expect(bike_sticker_update.bike).to eq bike_for_avery
          expect(bike_sticker_update.organization_id).to eq organization.id
          expect(bike_sticker_update.export_id).to eq export.id
        end
      end
    end
    context "bulk import already processed" do
      let(:export) { FactoryBot.create(:export, progress: "finished") }
      it "returns true" do
        instance.perform(export.id)
      end
    end
    context "no bikes" do
      let(:csv_lines) { [export.headers] }
      let(:export) { FactoryBot.create(:export_organization, progress: "pending", file: nil, end_at: Time.current - 1.week) }
      it "finishes export" do
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        instance.perform(export.id)
        export.reload
        expect(export.progress).to eq "finished"
        expect(export.file.read).to eq(csv_string)
        expect(export.rows).to eq 0
      end
    end

    context "all unpaid headers" do
      # Setting up what we have, rather than waiting on everything
      # Also - test that it doesn't explode if unable to assign stickers
      let(:export) { FactoryBot.create(:export_organization, progress: "pending", file: nil, options: {headers: Export.permitted_headers(Organization.new), bike_code_start: "fff"}) }
      let(:secondary_color) { FactoryBot.create(:color) }
      let(:email) { "testly@bikeindex.org" }
      let!(:bike) do
        FactoryBot.create(:bike_organized,
          :with_ownership_claimed,
          creation_organization: organization,
          manufacturer: Manufacturer.other,
          frame_model: '",,,\"<script>XSSSSS</script>',
          year: 2001,
          manufacturer_other: "Sweet manufacturer <><>><\\",
          primary_frame_color: Color.black,
          extra_registration_number: "cool extra serial",
          secondary_frame_color: secondary_color,
          creator: FactoryBot.create(:user_confirmed, name: "other person"),
          user: FactoryBot.create(:user, name: "George Smith", email: email),
          owner_email: email)
      end
      # let!(:ownership) { FactoryBot.create(:ownership, bike: bike, creator: FactoryBot.create(:user_confirmed, name: "other person"), user: FactoryBot.create(:user, name: "George Smith", email: "testly@bikeindex.org")) }
      let(:bike_row_hash) do
        {
          thumbnail: nil,
          registered_at: bike.created_at.utc.to_s,
          status: nil, # no status
          manufacturer: "Sweet manufacturer &lt;&gt;&lt;&gt;&gt;&lt;",
          model: "\\\",,,\\\"<script>XSSSSS</script>",
          color: "Black, #{secondary_color.name}",
          owner_email: email,
          owner_name: "George Smith",
          registration_method: "web",
          link: "http://test.host/bikes/#{bike.id}",
          updated_at: bike.reload.updated_by_user_fallback.utc.to_s,
          serial: bike.serial_number,
          vehicle_type: "Bike",
          propulsion_type: nil,
          occurred_at: nil,
          assigned_sticker: nil
        }
      end
      let(:bike_values) { bike_row_hash.values }
      let(:target_csv_line) { instance.comma_wrapped_string(bike_values).gsub(/\n\z/, "") }

      it "exports with all the header values" do
        expect(bike.reload.owner_name).to eq "George Smith"
        instance.perform(export.id)
        export.reload
        expect(export.progress).to eq "finished"
        generated_csv_string = export.file.read
        line_hash = csv_line_to_hash(generated_csv_string.split("\n").last, headers: export.written_headers)
        expect(line_hash.keys).to eq bike_row_hash.keys # has to match the order!
        expect(line_hash).to match_hash_indifferently(bike_row_hash)
        # written_csv_line = export.written_headers.zip(generated_csv_string.split("\n").last)
        # NOTE: this only seems to fail on the mac version of nokogiri, see PR#2366
        # Ensure we actually match the exact thing with correct escaping
        expect(generated_csv_string.split("\n").last).to eq target_csv_line
        # And matching the whole thing
        expect(generated_csv_string).to eq(csv_string)
        expect(export.rows).to eq 1
      end
    end

    context "registration_method" do
      let(:export) { FactoryBot.create(:export_organization, progress: "pending", file: nil, options: {headers: %w[registration_method]}) }
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, creation_state_origin: "embed_partial") }

      # The column is the component's copy, not the raw kind
      it "exports the kind's label" do
        expect(bike.reload.creation_kind).to eq :embed_partial
        instance.perform(export.id)
        expect(export.reload.file.read.split("\n").last).to eq instance.comma_wrapped_string(["old landing page"]).chomp
      end
    end

    context "special headers" do
      let(:enabled_feature_slugs) { ["csv_exports"] }
      let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }
      let(:user) { FactoryBot.create(:organization_user, organization: organization) }
      let(:export) { FactoryBot.create(:export_organization, organization: organization, progress: "pending", file: nil, user: user, options: export_options) }
      let(:registration_info) do
        {street: "717 Market St",
         postal_code: "94103",
         city: "San Francisco",
         region_string: "CA",
         latitude: 40.7143528,
         longitude: -74.0059731,
         phone: "717.742.3423",
         organization_affiliation: "community_member",
         student_id: "XX9999"}
      end
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, extra_registration_number: "cool extra serial", creation_registration_info: registration_info, cycle_type: "cargo", propulsion_type: "pedal-assist") }
      let!(:state) { FactoryBot.create(:state_california) }
      let(:target_address) { registration_info.except(:phone, :organization_affiliation, :student_id, :region_string, :postal_code).merge(street_2: nil, state: "CA", zipcode: "94103").as_json }
      include_context :geocoder_real # Include to verify that it isn't called except when expected

      context "with sticker" do
        let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, code: "ff333333") }
        context "assigning stickers" do
          let(:export_options) { {headers: %w[link phone extra_registration_number address organization_affiliation student_id], bike_code_start: "ff333333"} }
          let(:target_headers) { %w[link phone extra_registration_number organization_affiliation student_id address address_2 city state zipcode assigned_sticker] }
          let(:bike_values) { ["http://test.host/bikes/#{bike.id}", "7177423423", "cool extra serial", "Community member", "XX9999", "717 Market St", "", "San Francisco", "CA", "94103", "FF 333 333"] }
          it "returns the expected values" do
            expect(export.reload.avery_export?).to be_falsey
            VCR.use_cassette("geohelper-formatted_address_hash", match_requests_on: [:path]) do
              bike.reload
              bike_sticker.reload
              expect(bike_sticker.claimed?).to be_falsey
              expect(bike.phone).to eq "7177423423"
              expect(bike.extra_registration_number).to eq "cool extra serial"
              expect(bike.organization_affiliation).to eq "community_member"
              expect(export.assign_bike_codes?).to be_truthy

              expect(bike.registration_address(true).except("country")).to eq target_address
              instance.perform(export.id)
            end
            export.reload
            expect(instance.export_headers).to eq target_headers
            expect(export.progress).to eq "finished"
            generated_csv_string = export.file.read
            bike_line = generated_csv_string.split("\n").last
            expect(bike_line.split(",").count).to eq target_headers.count
            expect(bike_line).to eq instance.comma_wrapped_string(bike_values).strip

            bike_sticker.reload
            expect(bike_sticker.claimed?).to be_truthy
            expect(bike_sticker.bike).to eq bike
            expect(bike_sticker.user).to eq user
          end
        end
        context "header only organization_affiliation" do
          let(:target_headers) { %w[organization_affiliation] }
          let(:export_options) { {headers: target_headers} }
          it "returns the expected values" do
            VCR.use_cassette("geohelper-formatted_address_hash", match_requests_on: [:path]) do
              bike_sticker.reload
              expect(bike_sticker.claimed?).to be_falsey
              instance.perform(export.id)
              export.reload
              expect(instance.export_headers).to eq target_headers
              expect(export.progress).to eq "finished"
              generated_csv_string = export.file.read
              bike_line = generated_csv_string.split("\n").last
              expect(bike_line.split(",").count).to eq target_headers.count
              expect(bike_line).to eq "\"Community member\""

              bike_sticker.reload
              expect(bike_sticker.claimed?).to be_falsey
            end
          end
        end
        context "header only student_id" do
          let(:target_headers) { %w[student_id] }
          let(:export_options) { {headers: target_headers} }
          it "returns the expected values" do
            bike_sticker.reload
            expect(bike_sticker.claimed?).to be_falsey
            expect(bike.student_id).to eq "XX9999"
            VCR.use_cassette("geohelper-formatted_address_hash", match_requests_on: [:path]) do
              instance.perform(export.id)
              export.reload
              expect(instance.export_headers).to eq target_headers
              expect(export.progress).to eq "finished"
              generated_csv_string = export.file.read
              bike_line = generated_csv_string.split("\n").last
              expect(bike_line.split(",").count).to eq target_headers.count
              expect(bike_line).to eq "\"XX9999\""

              bike_sticker.reload
              expect(bike_sticker.claimed?).to be_falsey
            end
          end
        end
        context "including every available field + stickers" do
          let(:enabled_feature_slugs) { OrganizationFeature::REG_FIELDS + %w[avery_export bike_stickers impound_bikes registration_notes registration_sequences show_partial_registrations] }
          let(:export_options) { {headers: Export.permitted_headers(organization)} }
          let!(:bike_organization_note) { FactoryBot.create(:bike_organization_note, bike:, organization:, body: "Sold at the fall swap") }
          let(:acknowledged_at) { Time.current - 1.day }
          let!(:registration_sequence_acknowledgment) do
            FactoryBot.create(:registration_sequence_acknowledgment, bike:, acknowledged_at:,
              registration_sequence: FactoryBot.create(:registration_sequence_active, organization:))
          end
          let(:bike_row_hash) do
            {
              thumbnail: nil,
              registered_at: bike.created_at.utc.to_s,
              status: nil,
              manufacturer: bike.mnfg_name,
              model: nil,
              color: "Black",
              owner_email: bike.owner_email,
              owner_name: nil,
              registration_method: "web",
              bike_sticker: "FF 333 333",
              link: "http://test.host/bikes/#{bike.id}",
              updated_at: bike.reload.updated_by_user_fallback.utc.to_s,
              serial: bike.serial_number,
              vehicle_type: "Cargo Bike",
              propulsion_type: "Pedal Assist",
              occurred_at: nil,
              extra_registration_number: "cool extra serial",
              organization_affiliation: "Community member",
              phone: "7177423423",
              student_id: "XX9999",
              organization_notes: "Sold at the fall swap",
              impound_id: nil,
              acknowledged_at: acknowledged_at.utc.to_s,
              address: "717 Market St",
              address_2: nil,
              city: "San Francisco",
              state: "CA",
              zipcode: "94103"
            }
          end
          it "returns the expected values" do
            VCR.use_cassette("geohelper-formatted_address_hash2", match_requests_on: [:path]) do
              expect(organization.reload.enabled_feature_slugs).to eq enabled_feature_slugs.sort
              bike_sticker.claim(user: user, bike: bike)
              bike_sticker.reload
              expect(bike_sticker.claimed?).to be_truthy
              expect(bike_sticker.bike).to eq bike
              expect(bike_sticker.user).to eq user
              expect(export.assign_bike_codes?).to be_falsey
              expect(bike.reload.user&.id).to be_blank
              expect(bike.owner_name).to eq nil
              expect(bike.phone).to eq "7177423423"
              expect(bike.extra_registration_number).to eq "cool extra serial"
              expect(bike.organization_affiliation).to eq "community_member"
              expect(bike.registration_address(true).except("country")).to eq target_address
              expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "initial_creation"
              instance.perform(export.id)
            end
            export.reload
            expect(Export.permitted_headers(organization)).to match_array(bike_row_hash.keys.map(&:to_s) - %w[address_2 city state zipcode])
            expect(instance.export_headers).to eq export.written_headers
            expect(instance.export_headers).to match_array bike_row_hash.keys.map(&:to_s)
            expect(export.progress).to eq "finished"
            generated_csv_string = export.file.read.force_encoding("UTF-8")

            line_hash = csv_line_to_hash(generated_csv_string.split("\n").last, headers: export.written_headers)
            expect(line_hash.keys).to eq bike_row_hash.keys # again, order is CRITICAL
            expect(line_hash).to match_hash_indifferently(bike_row_hash)
            expect(generated_csv_string).to eq csv_string
          end
        end
      end

      context "header only organization_notes" do
        let(:target_headers) { %w[organization_notes] }
        let(:export_options) { {headers: target_headers} }
        let!(:bike_organization_note) { FactoryBot.create(:bike_organization_note, bike:, organization:, body: "Sold at the fall swap") }
        let!(:other_organization_note) { FactoryBot.create(:bike_organization_note, bike:, organization: FactoryBot.create(:organization), body: "Not this org") }
        it "returns the note from the export's organization" do
          instance.perform(export.id)
          export.reload
          expect(instance.export_headers).to eq target_headers
          expect(export.progress).to eq "finished"
          expect(export.file.read.split("\n").last).to eq "\"Sold at the fall swap\""
        end
      end

      context "with partial registrations, every available field without sticker" do
        let(:enabled_feature_slugs) { OrganizationFeature::REG_FIELDS + %w[bike_stickers show_partial_registrations] }
        let(:export_options) { {headers: Export.permitted_headers(organization), partial_registrations: "only"} }
        let(:partial_reg_attrs) do
          {
            manufacturer_id: Manufacturer.other.id,
            primary_frame_color_id: Color.black.id,
            owner_email: "something@stuff.com",
            creation_organization_id: organization.id,
            cycle_type: "e-Skateboard"
          }
        end
        let!(:partial_registration) { BParam.create(params: {bike: partial_reg_attrs}, origin: "embed_partial") }
        let(:target_partial_row) do
          {
            thumbnail: nil,
            registered_at: partial_registration.created_at.utc.to_s,
            status: nil,
            manufacturer: "Other",
            model: nil,
            color: "Black",
            owner_email: "something@stuff.com",
            owner_name: nil,
            registration_method: nil,
            bike_sticker: nil,
            link: nil,
            updated_at: nil,
            serial: nil,
            vehicle_type: "e-Personal Mobility Device",
            propulsion_type: nil,
            occurred_at: nil,
            extra_registration_number: nil,
            organization_affiliation: nil,
            phone: nil,
            student_id: nil,
            address: nil,
            address_2: nil,
            city: nil,
            state: nil,
            zipcode: nil,
            partial_registration: "true"
          }
        end
        it "returns expected values" do
          expect(partial_registration.manufacturer&.name).to eq("Other")
          expect(export.bikes_scoped.pluck(:id)).to eq([])
          expect(organization.incomplete_b_params.pluck(:id)).to eq([partial_registration.id])
          expect(export.incompletes_scoped.pluck(:id)).to eq([partial_registration.id])
          instance.perform(export.id)
          export.reload
          expect(instance.export_headers).to eq export.written_headers
          expect(export.progress).to eq "finished"
          generated_csv_string = export.file.read.force_encoding("UTF-8")
          expect(generated_csv_string.split("\n").count).to eq 2

          line_hash = csv_line_to_hash(generated_csv_string.split("\n").last, headers: export.written_headers)
          expect(line_hash.keys).to eq target_partial_row.keys # again, order is CRITICAL
          expect(line_hash).to match_hash_indifferently(target_partial_row)

          target_csv_string = [export.written_headers, target_partial_row.values].map { |r| instance.comma_wrapped_string(r) }.join
          expect(generated_csv_string).to eq target_csv_string
          expect(export.exported_bike_ids).to eq([])
        end
        context "partial registrations and complete registration only" do
          let(:export_options) { {headers: Export.permitted_headers(organization), partial_registrations: true} }
          let(:target_complete_row) do
            {
              thumbnail: nil,
              registered_at: bike.created_at.utc.to_s,
              status: nil,
              manufacturer: bike.mnfg_name,
              model: nil,
              color: "Black",
              owner_email: bike.owner_email,
              owner_name: nil,
              registration_method: "web",
              bike_sticker: nil,
              link: "http://test.host/bikes/#{bike.id}",
              updated_at: bike.reload.updated_by_user_fallback.utc.to_s,
              serial: bike.serial_number,
              vehicle_type: "e-Personal Mobility Device",
              propulsion_type: "Pedal Assist",
              occurred_at: nil,
              extra_registration_number: "cool extra serial",
              organization_affiliation: "Community member",
              phone: "7177423423",
              student_id: "XX9999",
              address: "717 Market St",
              address_2: nil,
              city: "San Francisco",
              state: "CA",
              zipcode: "94103",
              partial_registration: nil
            }
          end
          it "returns expected values" do
            VCR.use_cassette("geohelper-formatted_address_hash2", match_requests_on: [:path]) do
              bike.reload.update(cycle_type: "personal-mobility")
              expect(BikeServices::CalculateLocation.registration_address_source(bike)).to eq "initial_creation"
              expect(bike.registration_address(true).except("country")).to eq target_address
              expect(bike.registration_address.except("country")).to eq target_address
            end
            instance.perform(export.id)
            export.reload
            expect(instance.export_headers).to eq export.written_headers
            expect(export.incompletes_scoped.pluck(:id)).to eq([partial_registration.id])
            expect(instance.export_headers).to match_array target_partial_row.keys.map(&:to_s)
            expect(export.progress).to eq "finished"
            generated_csv_string = export.file.read.force_encoding("UTF-8")
            expect(generated_csv_string.split("\n").count).to eq 3

            complete_line_hash = csv_line_to_hash(generated_csv_string.split("\n")[1], headers: export.written_headers)
            expect(complete_line_hash.keys).to eq target_complete_row.keys # again, order is CRITICAL
            expect(complete_line_hash).to match_hash_indifferently(target_complete_row)

            partial_line_hash = csv_line_to_hash(generated_csv_string.split("\n").last, headers: export.written_headers)
            expect(partial_line_hash.keys).to eq target_partial_row.keys # again, order is CRITICAL
            expect(partial_line_hash).to match_hash_indifferently(target_partial_row)
            # Verify cycle_type is EXACTLY the same (including capitalization)
            expect(partial_line_hash[:vehicle_type]).to eq complete_line_hash[:vehicle_type]

            expect(export.exported_bike_ids).to eq([bike.id])

            target_csv_string = [export.written_headers, target_complete_row.values, target_partial_row.values]
              .map { |r| instance.comma_wrapped_string(r) }.join

            expect(generated_csv_string).to eq target_csv_string
            expect(export.exported_bike_ids).to eq([bike.id])
          end
        end
        context "register flow partial registration, past step 2" do
          let(:state) { FactoryBot.create(:state_california) }
          let(:step_2_attrs) do
            {frame_model: "Big Dummy", serial_number: "XXX-1234", user_name: "Sally Owner", phone: "7177423423",
             extra_registration_number: "extra-1", organization_affiliation: "student", student_id: "S1234",
             status: "status_stolen", address_record_attributes: {street: "1 Shields Ave", city: "Davis",
                                                                  region_record_id: state.id, postal_code: "95616", country_id: Country.united_states.id}}
          end
          let!(:partial_registration) do
            BParam.create(params: {bike: partial_reg_attrs.merge(step_2_attrs)}, origin: "register_flow_organized")
          end
          it "exports the step 2 details" do
            expect(export.incompletes_scoped.pluck(:id)).to eq([partial_registration.id])
            instance.perform(export.id)
            export.reload
            line_hash = csv_line_to_hash(export.file.read.force_encoding("UTF-8").split("\n").last, headers: export.written_headers)
            expect(line_hash).to match_hash_indifferently(target_partial_row.merge(
              model: "Big Dummy", serial: "XXX-1234", owner_name: "Sally Owner", phone: "7177423423",
              extra_registration_number: "extra-1", organization_affiliation: "student", student_id: "S1234",
              status: "stolen", address: "1 Shields Ave", city: "Davis", state: "CA", zipcode: "95616"
            ))
          end
        end
      end

      context "impounded" do
        let(:enabled_feature_slugs) { %w[impound_bikes] }
        let(:export_options) { {headers: Export.permitted_headers(organization), impounded_bikes: true} }
        let(:impounded_at) { Time.current - 3.days }
        let!(:impound_record) { FactoryBot.create(:impound_record_with_organization, bike:, organization:, impounded_at:) }
        let!(:bike_not_impounded) { FactoryBot.create(:bike_organized, creation_organization: organization) }
        let!(:partial_registration) { BParam.create(params: {bike: {creation_organization_id: organization.id}}, origin: "embed_partial") }
        let(:target_impound_row) do
          {
            thumbnail: nil,
            registered_at: bike.created_at.utc.to_s,
            status: "impounded",
            manufacturer: bike.mnfg_name,
            model: nil,
            color: "Black",
            owner_email: bike.owner_email,
            owner_name: nil,
            registration_method: "web",
            link: "http://test.host/bikes/#{bike.id}",
            updated_at: bike.reload.updated_by_user_fallback.utc.to_s,
            serial: bike.serial_number,
            vehicle_type: "Cargo Bike",
            propulsion_type: "Pedal Assist",
            occurred_at: impounded_at.utc.to_s,
            impound_id: impound_record.display_id
          }
        end
        it "returns impound values" do
          expect(bike.reload.occurred_at.round).to eq impounded_at.round
          expect(bike.status).to eq "status_impounded"
          expect(organization.incomplete_b_params.pluck(:id)).to eq([partial_registration.id])
          expect(export.bikes_scoped.pluck(:id)).to eq([bike.id])
          instance.perform(export.id)
          export.reload
          expect(instance.export_headers).to eq export.reload.written_headers
          expect(export.headers.count).to eq target_impound_row.keys.count
          expect(export.headers.sort).to eq target_impound_row.keys.map(&:to_s).sort
          expect(export.progress).to eq "finished"
          generated_csv_string = export.file.read.force_encoding("UTF-8")
          expect(generated_csv_string.split("\n").count).to eq 2

          line_hash = csv_line_to_hash(generated_csv_string.split("\n").last, headers: export.written_headers)
          expect(line_hash.keys).to eq target_impound_row.keys # again, order is CRITICAL
          expect(line_hash).to match_hash_indifferently(target_impound_row)

          target_csv_string = [export.written_headers, target_impound_row.values].map { |r| instance.comma_wrapped_string(r) }.join
          expect(generated_csv_string).to eq target_csv_string
          expect(export.exported_bike_ids).to eq([bike.id])
        end
      end
    end
  end

  context "with assigned export" do
    before { instance.export = export }

    describe "bike_to_row" do
      context "default" do
        it "returns the hash we want" do
          expect(instance.bike_to_row(bike)).to eq bike_values
        end
      end

      context "with a bike the organization impounded that's registered elsewhere" do
        let(:organization) do
          FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[csv_exports impound_bikes reg_address reg_phone])
        end
        let(:export) { FactoryBot.create(:export_organization, organization:, options: {headers: %w[link owner_email owner_name phone address], impounded_bikes: true}) }
        let(:impound_user) { FactoryBot.create(:organization_user, organization:) }
        let(:bike_elsewhere) do
          FactoryBot.create(:bike, :with_ownership, :with_address_record, owner_email: "elsewhere@example.com",
            creation_registration_info: {user_name: "Someone Else", phone: "7177423423"})
        end
        let!(:impound_record) { FactoryBot.create(:impound_record, organization:, user: impound_user, bike: bike_elsewhere) }
        let!(:impound_record_registered) { FactoryBot.create(:impound_record, organization:, user: impound_user, bike:) }

        it "blanks its owner's details, as the registrations table hides them" do
          expect(bike_elsewhere.reload.phone).to eq "7177423423"
          expect(bike_elsewhere.owner_name).to eq "Someone Else"
          expect(bike_elsewhere.registration_address["street"]).to be_present
          expect(export.bikes_scoped.pluck(:id)).to match_array([bike.id, bike_elsewhere.id])
          expect(instance.bike_to_row(bike_elsewhere)).to eq(["http://test.host/bikes/#{bike_elsewhere.id}", *Array.new(8)])
          # The organization's own registration keeps them
          expect(instance.bike_to_row(bike)[1]).to eq bike.owner_email
          # ...and one impounded after the export started is hidden too
          bike_impounded_later = FactoryBot.create(:impound_record, organization:, user: impound_user).bike
          expect(instance.bike_to_row(bike_impounded_later)[1]).to be_nil
        end

        context "assigning stickers" do
          let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization:, code: "ff333333") }
          let(:export) do
            FactoryBot.create(:export_organization, organization:, user: impound_user,
              options: {headers: %w[link], impounded_bikes: true, bike_code_start: "ff333333"})
          end

          it "doesn't claim one onto it, which would register it with the organization" do
            expect(instance.bike_to_row(bike_elsewhere)).to eq(["http://test.host/bikes/#{bike_elsewhere.id}", nil])
            expect(bike_sticker.reload.claimed?).to be_falsey
            expect(bike_elsewhere.reload.organized?(organization)).to be_falsey
            expect(instance.bike_to_row(bike).last).to eq "FF 333 333"
          end
        end
      end
    end
  end
end
