require "spec_helper"

describe BulkImportWorker do
  let(:subject) { BulkImportWorker }
  let(:instance) { subject.new }
  it { is_expected.to be_processed_in :afterward }
  let(:bulk_import) { FactoryGirl.create(:bulk_import) }

  let(:sample_csv_lines) do
    [
      %w[manufacturer model year color email serial],
      ["Trek", "Roscoe 8", "2019", "Silver", "test@bikeindex.org", "xyz_test"],
      ["Surly", "Midnight Special", "2018", "White", "test2@bikeindex.org", "example"]
    ]
  end
  let(:csv_lines) { sample_csv_lines }
  let(:csv_string) { csv_lines.map { |r| r.join(",") }.join("\n") }

  describe "perform" do
    context "file 404s" do
      let!(:bulk_import) { FactoryGirl.create(:bulk_import, file_url: "https://bikeindex.org/not_a_location") }
      it "adds a file error" do
        VCR.use_cassette("BulkImportWorker-file-404") do
          instance.perform(bulk_import.id)
          bulk_import.reload
          expect(bulk_import.file_import_errors.to_s).to match(/404/)
        end
      end
    end
    context "bulk import already processed" do
      let(:bulk_import) { FactoryGirl.create(:bulk_import, progress: "finished") }
      it "returns true" do
        allow_any_instance_of(BulkImport).to receive(:file) { csv_string }
        expect(instance).to_not receive(:register_bike)
        instance.perform(bulk_import.id)
      end
    end
    context "valid" do
      it "registers some bikes"

    end
  end

  context "with assigned bulk import" do
    before { instance.bulk_import = bulk_import }
    describe "process_csv" do
      context "without a header" do
        let(:csv_lines) { sample_csv_lines.slice(1, 2) }
        it "adds a file error" do
          expect(instance).to_not receive(:register_bike)
          instance.process_csv(csv_string)
          bulk_import.reload
          expect(bulk_import.file_import_errors.to_s).to match(/invalid csv headers/i)
        end
      end
      context "with an invalid header" do
        let(:csv_lines) { [%w[manufacturer email name color]] + sample_csv_lines.slice(1, 2) }
        it "adds a file error" do
          expect(instance).to_not receive(:register_bike)
          instance.process_csv(csv_string)
          bulk_import.reload
          expect(bulk_import.file_import_errors.to_s).to match(/invalid csv headers/i)
        end
      end
      context "with a failed row" do
        it "adds a row error"
      end
      context "with two valid bikes" do
        let(:target1) { instance.row_to_b_param_hash(sample_csv_lines[0].map(&:to_sym).zip(csv_lines[1]).to_h) }
        let(:target2) { instance.row_to_b_param_hash(sample_csv_lines[0].map(&:to_sym).zip(csv_lines[2]).to_h) }
        xit "calls register bike with the valid bikes" do
          expect(instance).to receive(:register_bike).with(target1)
          expect(instance).to receive(:register_bike).with(target2)
          instance.process_csv(csv_string)
          bulk_import.reload
          expect(bulk_import.import_errors).to_not be_present
        end
      end
    end

    describe "row_to_b_param_hash" do
      let(:row) { sample_csv_lines[0].map(&:to_sym).zip(csv_lines[1]).to_h }
      let(:target) do
        {
          owner_email: row[:email],
          manufacturer_id: "Trek",
          is_bulk: true,
          color: "Silver",
          serial_number: row[:serial],
          year: row[:year],
          frame_model: "Roscoe 8",
          send_email: true,
          creation_organization_id: nil
        }
      end
      describe "row_to_b_param_hash" do
        context "some extra bits" do
          it "returns the hash we want" do
            row_hash = row.merge(hidden: true, another_thing: "912913")
            expect(instance.row_to_b_param_hash(row_hash)[:bike]).to eq target
          end
        end
        context "with organization" do
          let(:organization) { FactoryGirl.create(:organization) }
          let!(:bulk_import) { FactoryGirl.create(:bulk_import, organization: organization, no_notify: true) }
          it "registers with organization" do
            expect(instance.row_to_b_param_hash(row)[:bike]).to eq target.merge(send_email: false, creation_organization_id: organization.id)
          end
        end
      end
    end

    describe "register bike" do
      let(:organization) { FactoryGirl.create(:organization) }
      let!(:bulk_import) { FactoryGirl.create(:bulk_import, organization: organization) }
      let!(:manufacturer) { FactoryGirl.create(:manufacturer, name: "Surly") }
      let!(:color) { FactoryGirl.create(:color, name: "White") }
      let(:row) { sample_csv_lines[0].map(&:to_sym).zip(csv_lines[2]).to_h }
      it "registers a bike" do
        expect(Bike.count).to eq 0
        expect do
          instance.register_bike(instance.row_to_b_param_hash(row))
        end.to change(Bike, :count).by 1
        bike = Bike.last

        expect(bike.owner_email).to eq row[:email]
        expect(bike.manufacturer).to eq manufacturer
        expect(bike.serial_number).to eq row[:serial]
        expect(bike.frame_model).to eq "Midnight Special"
        expect(bike.primary_frame_color).to eq color
        expect(bike.creation_organization).to eq organization

        creation_state = bike.creation_state
        expect(creation_state.is_bulk).to be_truthy
        expect(creation_state.origin).to eq "bulk_import_worker"
        expect(creation_state.creator).to eq bulk_import.user
        expect(creation_state.organization).to eq organization
      end
    end
  end
end
