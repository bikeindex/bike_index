require "spec_helper"

describe OrganizationExportWorker do
  let(:subject) { OrganizationExportWorker }
  let(:instance) { subject.new }
  let(:export) { FactoryGirl.create(:export_organization, progress: "pending", file: nil) }
  let(:organization) { export.organization }
  let(:black) { FactoryGirl.create(:color, name: "Black") } # Because we use it as a default color
  let(:trek) { FactoryGirl.create(:manufacturer, name: "Trek") }
  let(:bike) { FactoryGirl.create(:creation_organization_bike, manufacturer: trek, primary_frame_color: black, organization: organization) }
  let(:basic_values) do
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

  describe "perform" do
    context "success" do
      let(:csv_lines) { [export.headers, basic_values] }
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
        let(:export) { FactoryGirl.create(:export_organization, progress: "pending", file: nil, file_format: "xlsx") }
        it "exports" do
          instance.perform(export.id)
          export.reload
          expect(export.progress).to eq "finished"
          expect(export.file.read).to be_present
          expect(export.rows).to eq 1
        end
      end
      context "avery export" do
        let(:export) { FactoryGirl.create(:export_avery, progress: "pending", file: nil) }
        it "exports, does not include bike that is missing name and email" do
          expect(export.avery_export?).to be_truthy
          instance.perform(export.id)
          export.reload
          expect(export.progress).to eq "finished"
          expect(export.file.read.strip.split(/\n/).count).to eq 1 # Only has the headers exported, no bikes
          expect(export.rows).to eq 0 # Also has correct count
        end
      end
    end
    context "bulk import already processed" do
      let(:export) { FactoryGirl.create(:export, progress: "finished") }
      it "returns true" do
        expect(instance).to_not receive(:create_csv)
        instance.perform(export.id)
      end
    end
    context "no bikes" do
      let(:csv_lines) { [export.headers] }
      let(:export) { FactoryGirl.create(:export_organization, progress: "pending", file: nil, end_at: Time.now - 1.week) }
      it "finishes export" do
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        instance.perform(export.id)
        export.reload
        expect(export.progress).to eq "finished"
        expect(export.file.read).to eq(csv_string)
        expect(export.rows).to eq 0
      end
    end

    context "all headers" do
      # Setting up what we have, rather than waiting on everything
      let(:export) { FactoryGirl.create(:export_organization, progress: "pending", file: nil, options: { headers: Export::PERMITTED_HEADERS }) }
      let(:secondary_color) { FactoryGirl.create(:color) }
      let(:email) { "testly@bikeindex.org" }
      let(:bike) do
        FactoryGirl.create(:creation_organization_bike,
                           organization: organization,
                           manufacturer: Manufacturer.other,
                           frame_model: '",,,\"<script>XSSSSS</script>',
                           year: 2001,
                           manufacturer_other: "Sweet manufacturer <><>><\\",
                           primary_frame_color: Color.black,
                           additional_registration: "cool extra serial",
                           secondary_frame_color: secondary_color,
                           owner_email: email)
      end
      let!(:ownership) { FactoryGirl.create(:ownership, bike: bike, creator: FactoryGirl.create(:confirmed_user, name: "other person"), user: FactoryGirl.create(:user, name: "George Smith", email: "testly@bikeindex.org")) }
      let(:csv_lines) { [export.headers, fancy_bike_values] }
      let(:fancy_bike_values) do
        [
          "http://test.host/bikes/#{bike.id}",
          bike.created_at.utc,
          "Sweet manufacturer &lt;&gt;&lt;&gt;&gt;",
          "\",,,\"<script>XSSSSS</script>",
          "Black, #{secondary_color.name}",
          bike.serial_number,
          nil,
          nil,
          nil, # Since user isn't part of organization. TODO: Currently not implemented
          nil,
          email,
          "George Smith",
          "George Smith" # Because of user_name_with_fallback
        ]
      end
      let(:target_csv_line) { "\"http://test.host/bikes/#{bike.id}\",\"#{bike.created_at.utc}\",\"Sweet manufacturer &lt;&gt;&lt;&gt;&gt;\",\"\\\",,,\\\"<script>XSSSSS</script>\",\"Black, #{secondary_color.name}\",\"#{bike.serial_number}\",\"\",\"\",\"\",\"\",\"#{email}\",\"George Smith\",\"George Smith\"" }
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
      let(:special_bike_values) do
        [
          "http://test.host/bikes/#{bike.id}",
          "717.742.3423",
          "cool extra serial",
          "717 Market St",
          "San Francisco",
          "CA",
          "94103"
        ]
      end
      let(:export) { FactoryGirl.create(:export_organization, progress: "pending", file: nil, options: { headers: %w[link phone additional_registration_number registration_address] }) }
      let(:paid_feature) { FactoryGirl.create(:paid_feature, amount_cents: 10_000, name: "CSV Exports", feature_slugs: ["csv_exports"]) }
      let(:invoice) { FactoryGirl.create(:invoice_paid, amount_due: 0) }
      let!(:b_param) { FactoryGirl.create(:b_param, created_bike_id: bike.id, params: { bike: { address: "717 Market St, SF", phone: "717.742.3423" } }) }
      let(:target_headers) { %w[link phone additional_registration_number address city state zipcode] }
      let(:bike) { FactoryGirl.create(:creation_organization_bike, organization: organization, additional_registration: "cool extra serial") }
      include_context :geocoder_real
      it "returns the expected values" do
        expect(bike.phone).to eq "717.742.3423"
        expect(bike.additional_registration).to eq "cool extra serial"
        VCR.use_cassette("geohelper-formatted_address_hash") do
          instance.perform(export.id)
        end
        export.reload
        expect(instance.export_headers).to eq target_headers
        expect(export.progress).to eq "finished"
        generated_csv_string = export.file.read
        expect(generated_csv_string.split("\n").last).to eq instance.comma_wrapped_string(special_bike_values).strip
      end
    end
  end

  context "with assigned export" do
    before { instance.export = export }

    describe "bike_to_row" do
      context "default" do
        it "returns the hash we want" do
          expect(instance.bike_to_row(bike)).to eq basic_values
        end
      end
    end
  end
end
