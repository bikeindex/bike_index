require "rails_helper"

RSpec.describe OrganizationExportWorker, type: :job do
  let(:subject) { OrganizationExportWorker }
  let(:instance) { subject.new }
  let(:export) { FactoryBot.create(:export_organization, progress: "pending", file: nil) }
  let(:organization) { export.organization }
  let(:black) { FactoryBot.create(:color, name: "Black") } # Because we use it as a default color
  let(:trek) { FactoryBot.create(:manufacturer, name: "Trek") }
  let(:bike) { FactoryBot.create(:creation_organization_bike, manufacturer: trek, primary_frame_color: black, organization: organization) }
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
        let(:bike_for_avery) { FactoryBot.create(:creation_organization_bike, manufacturer: trek, primary_frame_color: black, organization: organization) }
        let!(:b_param) do
          FactoryBot.create(:b_param, created_bike_id: bike_for_avery.id,
                                      params: {bike: {address: "102 Washington Pl, State College",
                                                      user_name: "Maya Skripal"}})
        end
        let(:bike_not_avery) { FactoryBot.create(:creation_organization_bike, manufacturer: trek, primary_frame_color: black, organization: organization) }
        let!(:b_param_partial) do
          FactoryBot.create(:b_param, created_bike_id: bike_not_avery.id,
                                      params: {bike: {address: "State College, PA",
                                                      user_name: "George Washington"}})
        end
        let(:csv_lines) do
          # We modify the headers during processing to separate the address into multiple fields
          [
            %w[owner_name address city state zipcode assigned_sticker],
            ["Maya Skripal", "102 Washington Pl", "State College", "PA", "16801", "A 111 1"]
          ]
        end
        let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, code: "a1111") }
        include_context :geocoder_real
        it "exports only bike with name, email and address" do
          expect(bike_sticker.claimed?).to be_falsey
          export.update_attributes(file_format: "csv") # Manually switch to csv so that we can parse it more easily :/
          expect(organization.bikes.pluck(:id)).to match_array([bike.id, bike_for_avery.id, bike_not_avery.id])
          expect(Export.with_bike_sticker_code(bike_sticker).pluck(:id)).to eq([])
          expect(export.avery_export?).to be_truthy
          expect(export.headers).to eq Export::AVERY_HEADERS
          VCR.use_cassette("organization_export_worker-avery") do
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
      let(:bike) do
        FactoryBot.create(:creation_organization_bike,
          organization: organization,
          manufacturer: Manufacturer.other,
          frame_model: '",,,\"<script>XSSSSS</script>',
          year: 2001,
          manufacturer_other: "Sweet manufacturer <><>><\\",
          primary_frame_color: Color.black,
          extra_registration_number: "cool extra serial",
          secondary_frame_color: secondary_color,
          owner_email: email)
      end
      let!(:ownership) { FactoryBot.create(:ownership, bike: bike, creator: FactoryBot.create(:user_confirmed, name: "other person"), user: FactoryBot.create(:user, name: "George Smith", email: "testly@bikeindex.org")) }
      let(:bike_values) do
        [
          "http://test.host/bikes/#{bike.id}",
          bike.created_at.utc,
          "Sweet manufacturer &lt;&gt;&lt;&gt;&gt;",
          "\",,,\"<script>XSSSSS</script>",
          "Black, #{secondary_color.name}",
          bike.serial_number,
          nil,
          nil,
          "cool extra serial",
          nil, # Since user isn't part of organization. TODO: Currently not implemented
          email,
          "George Smith",
          nil # assigned_sticker
        ]
      end
      let(:target_csv_line) { "\"http://test.host/bikes/#{bike.id}\",\"#{bike.created_at.utc}\",\"Sweet manufacturer &lt;&gt;&lt;&gt;&gt;\",\"\\\",,,\\\"<script>XSSSSS</script>\",\"Black, #{secondary_color.name}\",\"#{bike.serial_number}\",\"\",\"\",\"cool extra serial\",\"\",\"#{email}\",\"George Smith\",\"\"" }
      it "exports with all the header values" do
        instance.perform(export.id)
        export.reload
        expect(export.progress).to eq "finished"
        generated_csv_string = export.file.read
        # Ensure we actually match the exact thing with correct escaping
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
      let!(:b_param) { FactoryBot.create(:b_param, created_bike_id: bike.id, params: b_param_params) }
      let(:b_param_params) { {bike: {address: "717 Market St, SF", phone: "717.742.3423", organization_affiliation: "community_member"}} }
      let(:bike) { FactoryBot.create(:creation_organization_bike, organization: organization, extra_registration_number: "cool extra serial") }
      let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization: organization, code: "ff333333") }
      let!(:state) { FactoryBot.create(:state, name: "California", abbreviation: "CA", country: Country.united_states) }
      let(:target_address) { {street: "717 Market St", city: "San Francisco", state: "CA", zipcode: "94103", country: "US", latitude: 37.7870205, longitude: -122.403928}.as_json }
      include_context :geocoder_real

      context "assigning stickers" do
        let(:export_options) { {headers: %w[link phone extra_registration_number address organization_affiliation], bike_code_start: "ff333333"} }
        let(:target_headers) { %w[link phone extra_registration_number organization_affiliation address city state zipcode assigned_sticker] }
        let(:bike_values) { ["http://test.host/bikes/#{bike.id}", "7177423423", "cool extra serial", "community_member", "717 Market St", "San Francisco", "CA", "94103", "FF 333 333"] }
        it "returns the expected values" do
          bike_sticker.reload
          expect(bike_sticker.claimed?).to be_falsey
          expect(bike.phone).to eq "7177423423"
          expect(bike.extra_registration_number).to eq "cool extra serial"
          expect(bike.organization_affiliation).to eq "community_member"
          expect(export.assign_bike_codes?).to be_truthy

          VCR.use_cassette("geohelper-formatted_address_hash", match_requests_on: [:path]) do
            expect(bike.registration_address).to eq target_address
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
            thumbnail: nil,
            extra_registration_number: "cool extra serial",
            registered_by: nil,
            owner_email: bike.owner_email,
            owner_name: nil,
            organization_affiliation: "community_member",
            phone: "7177423423",
            sticker: "FF 333 333",
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
            expect(bike.phone).to eq "7177423423"
            expect(bike.extra_registration_number).to eq "cool extra serial"
            expect(bike.organization_affiliation).to eq "community_member"
            expect(bike.registration_address).to eq target_address
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
            thumbnail: nil,
            extra_registration_number: nil,
            registered_by: nil,
            owner_email: "something@stuff.com",
            owner_name: nil,
            organization_affiliation: nil,
            phone: nil,
            sticker: nil,
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
              thumbnail: nil,
              extra_registration_number: "cool extra serial",
              registered_by: nil,
              owner_email: bike.owner_email,
              owner_name: nil,
              organization_affiliation: "community_member",
              phone: "7177423423",
              sticker: nil,
              address: nil,
              city: nil,
              state: nil,
              zipcode: nil,
              partial_registration: nil
            }
          end
          it "returns expected values" do
            instance.perform(export.id)
            export.reload
            expect(instance.export_headers).to eq export.written_headers
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
