require "rails_helper"

RSpec.describe OrganizationExportWorker, type: :job do
  let(:subject) { OrganizationExportWorker }
  let(:instance) { subject.new }
  let(:export) { FactoryBot.create(:export_organization, progress: "pending", file: nil) }
  let(:organization) { export.organization }
  let(:black) { FactoryBot.create(:color, name: "Black") } # Because we use it as a default color
  let(:trek) { FactoryBot.create(:manufacturer, name: "Trek") }
  let(:bike) { FactoryBot.create(:bike_organized, manufacturer: trek, primary_frame_color: black, creation_organization: organization) }
  let(:bike_values) do
    [
      "http://test.host/bikes/#{bike.id}",
      bike.created_at.utc,
      "Trek",
      nil,
      "Black",
      bike.serial_number,
      nil
    ]
  end
  let(:csv_string) { csv_lines.map { |r| instance.comma_wrapped_string(r) }.join }
  let(:csv_lines) { [export.written_headers, bike_values] }

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
        let(:user) { FactoryBot.create(:admin) }
        let(:export) { FactoryBot.create(:export_avery, progress: "pending", file: nil, bike_code_start: "a1111 ", user: user) }
        let(:bike_for_avery_og) do
          FactoryBot.create(:bike_organized,
            manufacturer: trek,
            primary_frame_color: black,
            creation_organization: organization,
            creation_registration_info: {
              street: "102 Washington Pl",
              city: "State College",
              state: "PA",
              zipcode: "16801",
              user_name: "Maya Skripal"
            })
        end
        # Force unmemoize - TODO: might not be necessary
        let!(:bike_for_avery) { Bike.find(bike_for_avery_og.id) }
        let!(:bike_not_avery) do
          FactoryBot.create(:bike_organized,
            manufacturer: trek,
            primary_frame_color: black,
            creation_organization: organization,
            creation_registration_info: {
              street: "",
              city: "State College",
              state: "PA",
              zipcode: "16801",
              user_name: "George Washington"
            })
        end
        let(:csv_lines) do
          # We modify the headers during processing to separate the address into multiple fields
          [
            %w[owner_name address city state zipcode assigned_sticker],
            ["Maya Skripal", "102 Washington Pl", "State College", "PA", "16801", "A 111 1"]
          ]
        end
        let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, code: "a1111") }
        let!(:state) { FactoryBot.create(:state, name: "Pennsylvania", abbreviation: "PA", country: Country.united_states) }
        include_context :geocoder_real
        it "exports only bike with name, email and address" do
          bike.reload
          expect(bike_sticker.claimed?).to be_falsey
          export.update(file_format: "csv") # Manually switch to csv so that we can parse it more easily :/
          expect(organization.bikes.pluck(:id)).to match_array([bike.id, bike_for_avery.id, bike_not_avery.id])
          expect(Export.with_bike_sticker_code(bike_sticker).pluck(:id)).to eq([])
          expect(export.avery_export?).to be_truthy
          expect(export.headers).to eq Export::AVERY_HEADERS
          VCR.use_cassette("organization_export_worker-avery") do
            expect(bike_for_avery.registration_address_source).to eq "initial_creation"
            bike_for_avery.update(updated_at: Time.current)
            expect(bike_for_avery.reload.avery_exportable?).to be_truthy
            expect(bike_for_avery.address_hash.except("country", "latitude", "longitude")).to eq bike_for_avery.registration_address
            # We need to be exporting via registration_address - NOT address_hash - so manually blank it, just to make sure
            bike_for_avery.update_column :street, nil
            expect(bike_for_avery.address_hash.except("country", "latitude", "longitude")).to eq bike_for_avery.registration_address.merge(street: nil)
            bike_for_avery
            instance.perform(export.id)
            # Check this in here so the vcr geocoder records at the correct place
            expect(bike_not_avery.registration_address["street"].present?).to be_falsey
          end
          export.reload
          expect(export.progress).to eq "finished"
          expect(export.rows).to eq 1 # The bike without a user_name and address isn't exported
          expect(export.file.read).to eq(csv_string)
          # NOTE: This header needs to stay exactly the same or the avery export will break
          expect(export.written_headers).to eq(%w[owner_name address city state zipcode assigned_sticker])
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
      let(:export) { FactoryBot.create(:export_organization, progress: "pending", file: nil, options: {headers: Export::PERMITTED_HEADERS, bike_code_start: "fff"}) }
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
      let(:bike_values) do
        [
          "http://test.host/bikes/#{bike.id}",
          bike.created_at.utc,
          "Sweet manufacturer &lt;&gt;&lt;&gt;&gt;&lt;\\",
          "\",,,\"<script>XSSSSS</script>",
          "Black, #{secondary_color.name}",
          bike.serial_number,
          nil,
          "Bike",
          nil,
          "cool extra serial",
          nil, # Since user isn't part of organization. TODO: Currently not implemented
          email,
          "George Smith",
          nil # assigned_sticker
        ]
      end
      let(:target_csv_line) { "\"http://test.host/bikes/#{bike.id}\",\"#{bike.created_at.utc}\",\"Sweet manufacturer &lt;&gt;&lt;&gt;&gt;&lt;\",\"\\\",,,\\\"<script>XSSSSS</script>\",\"Black, #{secondary_color.name}\",\"#{bike.serial_number}\",\"\",\"Bike\",\"\",\"cool extra serial\",\"\",\"#{email}\",\"George Smith\",\"\"" }
      it "exports with all the header values" do
        expect(bike.reload.owner_name).to eq "George Smith"
        instance.perform(export.id)
        export.reload
        expect(export.progress).to eq "finished"
        generated_csv_string = export.file.read
        # NOTE: this only seems to fail on the mac version of nokogiri, see PR#2366
        # Ensure we actually match the exact thing with correct escaping
        pp "HERHERHER"
        pp generated_csv_string.split("\n").last
        pp target_csv_line
        expect(generated_csv_string.split("\n").last).to eq target_csv_line
        # And matching the whole thing
        expect(generated_csv_string).to eq(csv_string)
        expect(export.rows).to eq 1
      end
    end
    context "special headers" do
      let(:enabled_feature_slugs) { ["csv_exports"] }
      let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: enabled_feature_slugs) }
      let(:user) { FactoryBot.create(:organization_member, organization: organization) }
      let(:export) { FactoryBot.create(:export_organization, organization: organization, progress: "pending", file: nil, user: user, options: export_options) }
      let(:registration_info) do
        {street: "717 Market St",
         zipcode: "94103",
         city: "San Francisco",
         state: "CA",
         phone: "717.742.3423",
         organization_affiliation: "community_member",
         student_id: "XX9999"}
      end
      let!(:bike) { FactoryBot.create(:bike_organized, creation_organization: organization, extra_registration_number: "cool extra serial", creation_registration_info: registration_info) }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, code: "ff333333") }
      let!(:state) { FactoryBot.create(:state, name: "California", abbreviation: "CA", country: Country.united_states) }
      let(:target_address) { registration_info.except(:phone, :organization_affiliation, :student_id).as_json }
      include_context :geocoder_real

      context "assigning stickers" do
        let(:export_options) { {headers: %w[link phone extra_registration_number address organization_affiliation student_id], bike_code_start: "ff333333"} }
        let(:target_headers) { %w[link phone extra_registration_number organization_affiliation student_id address city state zipcode assigned_sticker] }
        let(:bike_values) { ["http://test.host/bikes/#{bike.id}", "7177423423", "cool extra serial", "community_member", "XX9999", "717 Market St", "San Francisco", "CA", "94103", "FF 333 333"] }
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

            expect(bike.registration_address(true)).to eq target_address
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
            expect(bike_line).to eq "\"community_member\""

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
        let(:enabled_feature_slugs) { OrganizationFeature::REG_FIELDS + ["bike_stickers"] }
        let(:export_options) { {headers: Export.permitted_headers(organization)} }
        let(:target_row) do
          {
            link: "http://test.host/bikes/#{bike.id}",
            registered_at: bike.created_at.utc,
            manufacturer: bike.mnfg_name,
            model: nil,
            color: "Black",
            serial: bike.serial_number,
            is_stolen: nil,
            vehicle_type: "Bike",
            thumbnail: nil,
            extra_registration_number: "cool extra serial",
            registered_by: nil,
            owner_email: bike.owner_email,
            owner_name: nil,
            bike_sticker: "FF 333 333",
            organization_affiliation: "community_member",
            phone: "7177423423",
            student_id: "XX9999",
            address: "717 Market St",
            city: "San Francisco",
            state: "CA",
            zipcode: "94103"
          }
        end
        it "returns the expected values" do
          VCR.use_cassette("geohelper-formatted_address_hash2", match_requests_on: [:path]) do
            bike_sticker.claim(user: user, bike: bike)
            bike_sticker.reload
            expect(bike_sticker.claimed?).to be_truthy
            expect(bike_sticker.bike).to eq bike
            expect(bike_sticker.user).to eq user
            expect(export.assign_bike_codes?).to be_falsey
            expect(export.headers).to eq Export.permitted_headers("include_paid")
            expect(bike.reload.user&.id).to be_blank
            expect(bike.owner_name).to eq nil
            expect(bike.phone).to eq "7177423423"
            expect(bike.extra_registration_number).to eq "cool extra serial"
            expect(bike.organization_affiliation).to eq "community_member"
            expect(bike.registration_address(true)).to eq target_address
            expect(bike.registration_address_source).to eq "initial_creation"
            instance.perform(export.id)
          end
          export.reload
          expect(instance.export_headers).to eq export.written_headers
          expect(instance.export_headers).to match_array target_row.keys.map(&:to_s)
          expect(export.progress).to eq "finished"
          generated_csv_string = export.file.read
          bike_line = generated_csv_string.split("\n").last
          expect(bike_line.split(",").count).to eq target_row.keys.count
          expect(bike_line).to eq instance.comma_wrapped_string(target_row.values).strip
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
            creation_organization_id: organization.id
          }
        end
        let!(:partial_registration) { BParam.create(params: {bike: partial_reg_attrs}, origin: "embed_partial") }
        let(:target_partial_row) do
          {
            link: nil,
            registered_at: partial_registration.created_at.utc,
            manufacturer: "Other",
            model: nil,
            color: "Black",
            serial: nil,
            is_stolen: nil,
            vehicle_type: nil,
            thumbnail: nil,
            extra_registration_number: nil,
            registered_by: nil,
            owner_email: "something@stuff.com",
            owner_name: nil,
            organization_affiliation: nil,
            student_id: nil,
            phone: nil,
            bike_sticker: nil,
            address: nil,
            city: nil,
            state: nil,
            zipcode: nil,
            partial_registration: true
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
          expect(instance.export_headers).to match_array target_partial_row.keys.map(&:to_s)
          expect(export.progress).to eq "finished"
          generated_csv_string = export.file.read
          expect(generated_csv_string.split("\n").count).to eq 2
          incomplete_line = generated_csv_string.split("\n").last
          expect(incomplete_line.split(",").count).to eq target_partial_row.keys.count
          expect(incomplete_line).to eq instance.comma_wrapped_string(target_partial_row.values).strip
          expect(export.exported_bike_ids).to eq([])
        end
        context "partial registrations and complete registration only" do
          let(:export_options) { {headers: Export.permitted_headers(organization), partial_registrations: true} }
          let(:target_full_row) do
            {
              link: "http://test.host/bikes/#{bike.id}",
              registered_at: bike.created_at.utc,
              manufacturer: bike.mnfg_name,
              model: nil,
              color: "Black",
              serial: bike.serial_number,
              is_stolen: nil,
              vehicle_type: "Bike",
              thumbnail: nil,
              extra_registration_number: "cool extra serial",
              registered_by: nil,
              owner_email: bike.owner_email,
              owner_name: nil,
              bike_sticker: nil,
              organization_affiliation: "community_member",
              phone: "7177423423",
              student_id: "XX9999",
              address: "717 Market St",
              city: "San Francisco",
              state: "CA",
              zipcode: "94103",
              partial_registration: nil
            }
          end
          it "returns expected values" do
            VCR.use_cassette("geohelper-formatted_address_hash2", match_requests_on: [:path]) do
              bike.reload
              expect(bike.registration_address_source).to eq "initial_creation"
              expect(bike.registration_address(true).except("latitude", "longitude")).to eq target_address
              expect(bike.registration_address).to eq target_address
            end
            instance.perform(export.id)
            export.reload
            expect(instance.export_headers).to eq export.written_headers
            expect(export.written_headers).to match_array target_full_row.keys.map(&:to_s)
            expect(export.incompletes_scoped.pluck(:id)).to eq([partial_registration.id])
            expect(instance.export_headers).to match_array target_partial_row.keys.map(&:to_s)
            expect(export.progress).to eq "finished"
            generated_csv_string = export.file.read
            expect(generated_csv_string.split("\n").count).to eq 3
            bike_line = generated_csv_string.split("\n")[1]
            expect(bike_line.split(",").count).to eq target_full_row.keys.count
            expect(bike_line).to eq instance.comma_wrapped_string(target_full_row.values).strip

            incomplete_line = generated_csv_string.split("\n").last
            expect(incomplete_line.split(",").count).to eq target_partial_row.keys.count
            expect(incomplete_line).to eq instance.comma_wrapped_string(target_partial_row.values).strip
            expect(export.exported_bike_ids).to eq([bike.id])
          end
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
    end
  end
end
