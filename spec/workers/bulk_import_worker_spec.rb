require "spec_helper"

describe BulkImportWorker do
  let(:subject) { BulkImportWorker }
  let(:instance) { subject.new }
  it { is_expected.to be_processed_in :afterward }
  let(:organization) { FactoryGirl.create(:organization) }

  let(:csv_lines) do
    [
      %w[manufacturer model year color email serial],
      ["Trek", "Roscoe 8", "2019", "Silver", "test@bikeindex.org", "xyz_test"],
      ["Surly", "Midnight Special", "2018", "White", "test2@bikeindex.org", "example"]
    ]
  end

  describe "perform" do
    context "file 404s" do
      let!(:bulk_import) { FactoryGirl.create(:bulk_import, file_url: "https://bikeindex.org/not_a_location") }
      it "adds a file error" do
        VCR.use_cassette("BulkImportWorker-file-404") do
          instance.perform(bulk_import.id)
          bulk_import.reload
          expect(bulk_import.file_import_errors).to match(/404/)
          pp bulk_import.import_errors
        end
      end
    end
  end

  describe "process_csv"
    let(:bulk_import) { FactoryGirl.create(:bulk_import) }
    before { subject.bulk_import = bulk_import }
    context "without a header" do
      # it "adds a file error" do
      #   pp csv_lines, csv_lines.slice(1,2)
      #   expect do
      #   end.to_not change(Bike, :count)
      #   bulk_import.reload
      #   expect(bulk_import.file_import_errors).to match(/)
      # end
    end
    context "with an invalid header" do
    end
    context "with a failed row" do
      it "adds a row error"
    end
  end

  describe "perform" do
    it "registers multiple bikes" do
    end
    context "bulk import already exists" do
      let!(:bulk_import) { FactoryGirl.create(:bulk_import, organization: organization) }
      xit "returns the existing bulk import" do
        expect(instance.perform(bulk_import.file_url, organization.id)).to eq bulk_import
      end
    end
  end
end
