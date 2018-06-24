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

  describe "process_csv" do
    before { instance.bulk_import = bulk_import }
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
      let(:target1) { sample_csv_lines[0].map(&:to_sym).zip(csv_lines[1]).to_h }
      let(:target2) { sample_csv_lines[0].map(&:to_sym).zip(csv_lines[2]).to_h }
      it "calls register bike with the valid bikes" do
        expect(instance).to receive(:register_bike).with(target1)
        expect(instance).to receive(:register_bike).with(target2)
        instance.process_csv(csv_string)
        bulk_import.reload
        expect(bulk_import.import_errors).to_not be_present
      end
    end
  end

  describe "register bike" do
    before { instance.bulk_import = bulk_import }
    let(:row) { sample_csv_lines[0].map(&:to_sym).zip(csv_lines[1]).to_h }
    context "with some extra bits" do
      it "registers a bike" do
        expect(Bike.count).to eq 0
        expect do
          instance.register_bike(row.merge(hidden: true, another_thing: '912913'))
        end.to change(Bike, :count).by 1
        bike = Bike.last
        expect(bike.hidden).to be_falsey
        row.each do |k, v|
          pp k unless bike.send(k).to_s == v.to_s
          expect(bike.send(k).to_s).to eq v.to_s
        end
        creation_state = Bike.creation_state
        expect(creation_state.is_bulk).to be_truthy
        # expect(creation_state.csv).to be_truthy
      end
    end
    context "no_notify true" do
      let(:organization) { FactoryGirl.create(:organization) }
      let!(:bulk_import) { FactoryGirl.create(:bulk_import, organization: organization, no_notify: true) }
      xit "registers a bike without sending email" do
        expect do
          instance.register_bike(row)
        end.to change(Bike, :count).by 1
        bike = Bike.last
        expect(bike.hidden).to be_falsey
        row.each do |k, v|
          pp k unless bike.send(k).to_s == v.to_s
          expect(bike.send(k).to_s).to eq v.to_s
        end
        creation_state = Bike.creation_state
        expect(creation_state.is_bulk).to be_truthy
        # expect(creation_state.csv).to be_truthy
      end
    end
  end
end
