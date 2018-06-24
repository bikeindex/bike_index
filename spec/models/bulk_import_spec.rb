require "spec_helper"

RSpec.describe BulkImport, type: :model do
  describe "add_file_errors" do
    context "no errors" do
      let!(:bulk_import) { FactoryGirl.build(:bulk_import) }
      it "adds a new error" do
        expect(bulk_import.pending?).to be_truthy
        bulk_import.add_file_error "HTTP 404"
        bulk_import.reload
        expect(bulk_import.finished?).to be_truthy
        expect(bulk_import.file_import_errors).to eq(["HTTP 404"])
      end
    end
    context "existing errors - unlikely, but worth just to make sure" do
      let(:existing_errors) { { line: [2, "Nobody loves you"], file:  "Wrong place wrong time" } }
      let!(:bulk_import) { FactoryGirl.create(:bulk_import, progress: "ongoing", import_errors: existing_errors) }
      it "adds a new error" do
        bulk_import.reload
        bulk_import.add_file_error "HTTP 404"
        bulk_import.reload
        expect(bulk_import.progress).to eq "finished"
        expect(bulk_import.line_import_errors).to eq([2, "Nobody loves you"])
        expect(bulk_import.file_import_errors).to eq(["Wrong place wrong time", "HTTP 404"])
      end
    end
  end
end
