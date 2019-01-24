require "spec_helper"

RSpec.describe BulkImport, type: :model do
  describe "add_file_errors" do
    context "no errors" do
      let!(:bulk_import) { FactoryBot.build(:bulk_import) }
      it "adds a new error" do
        expect(bulk_import.pending?).to be_truthy
        expect(bulk_import.starting_line).to eq 1
        expect(bulk_import.file_import_errors_with_lines).to be_nil
        bulk_import.add_file_error "HTTP 404"
        bulk_import.reload
        expect(bulk_import.finished?).to be_truthy
        expect(bulk_import.file_import_errors).to eq(["HTTP 404"])
        expect(bulk_import.starting_line).to eq 1 # If error doesn't have a line, it's still 1
      end
    end
    context "existing errors - unlikely, but worth just to make sure" do
      let(:existing_errors) { { line: [2, "Nobody loves you"], file:  "Wrong place wrong time", file_lines: [1] } }
      let!(:bulk_import) { FactoryBot.create(:bulk_import, progress: "ongoing", import_errors: existing_errors) }
      it "adds a new error" do
        expect(bulk_import.starting_line).to eq 2
        bulk_import.reload
        expect(bulk_import.file_import_errors_with_lines).to eq([["Wrong place wrong time", 1]])
        bulk_import.add_file_error "HTTP 404", 101
        bulk_import.reload
        expect(bulk_import.progress).to eq "finished"
        expect(bulk_import.line_import_errors).to eq([2, "Nobody loves you"])
        expect(bulk_import.file_import_errors).to eq(["Wrong place wrong time", "HTTP 404"])
        expect(bulk_import.file_import_errors_with_lines).to eq([["Wrong place wrong time", 1], ["HTTP 404", 101]])
        expect(bulk_import.starting_line).to eq 102
      end
    end
  end
end
