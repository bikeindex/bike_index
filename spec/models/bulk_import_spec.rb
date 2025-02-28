require "rails_helper"

RSpec.describe BulkImport, type: :model do
  describe "kind_humanized" do
    it "is expected" do
      expect(BulkImport.kind_humanized("ascend")).to eq "ascend"
      expect(BulkImport.kind_humanized("organization_import")).to eq "standard"
      expect(BulkImport.kind_humanized("impounded")).to eq "impounded"
      expect(BulkImport.kind_humanized("unorganized")).to eq "unorganized"
    end
  end
  describe "add_file_errors" do
    context "no errors" do
      let!(:bulk_import) { FactoryBot.build(:bulk_import) }
      it "adds a new error" do
        expect(bulk_import.pending?).to be_truthy
        expect(bulk_import.starting_line).to eq 1
        expect(bulk_import.file_errors_with_lines).to be_nil
        bulk_import.add_file_error "HTTP 404"
        bulk_import.reload
        expect(bulk_import.kind).to eq "unorganized"
        expect(bulk_import.finished?).to be_truthy
        expect(bulk_import.file_errors).to eq(["HTTP 404"])
        expect(bulk_import.starting_line).to eq 1 # If error doesn't have a line, it's still 1
        # It doesn't do it again
        bulk_import.add_file_error "HTTP 404"
        expect(bulk_import.reload.file_errors).to eq(["HTTP 404"])
      end
    end
    context "existing errors - unlikely, but worth just to make sure" do
      let(:existing_errors) { {line: [2, "Nobody loves you"], file: "Wrong place wrong time", file_lines: [1]} }
      let!(:bulk_import) { FactoryBot.create(:bulk_import, progress: "ongoing", import_errors: existing_errors, organization: FactoryBot.create(:organization)) }
      it "adds a new error" do
        expect(bulk_import.starting_line).to eq 2
        bulk_import.reload
        expect(bulk_import.file_errors_with_lines).to eq([["Wrong place wrong time", 1]])
        bulk_import.add_file_error "HTTP 404", 101
        bulk_import.reload
        expect(bulk_import.kind).to eq "organization_import"
        expect(bulk_import.progress).to eq "finished"
        expect(bulk_import.line_errors).to eq([2, "Nobody loves you"])
        expect(bulk_import.file_errors).to eq(["Wrong place wrong time", "HTTP 404"])
        expect(bulk_import.file_errors_with_lines).to eq([["Wrong place wrong time", 1], ["HTTP 404", 101]])
        expect(bulk_import.starting_line).to eq 102
      end
    end
  end

  describe "blocking_error?" do
    let(:bulk_import) { BulkImport.new(import_errors: {line: [2, "dddd"]}.as_json, progress: "finished", created_at: Time.current - 1.month) }
    it "is be_falsey" do
      expect(bulk_import.blocking_error?).to be_falsey
    end
    context "file error" do
      let(:bulk_import) { BulkImport.new(import_errors: {file: "dddd"}.as_json) }
      it "is be_falsey" do
        expect(bulk_import.blocking_error?).to be_truthy
      end
    end
    context "pending and more than a minute old" do
      let(:bulk_import) { BulkImport.new(created_at: Time.current - 10.minutes, progress: "pending") }
      it "is truthy" do
        # Fallback because we failed to parse it
        expect(bulk_import.blocking_error?).to be_truthy
      end
    end
  end

  describe "organization_for_ascend_name" do
    let!(:bulk_import) { BulkImport.new }
    before { allow(bulk_import).to receive(:file_filename) { "Bike_Index_Reserve_20190207_-_BIKE_LANE_CHIC.csv" } }
    it "doesn't return anything" do
      expect(bulk_import.organization_for_ascend_name).to be_nil
    end
    context "exact name" do
      let!(:organization) { FactoryBot.create(:organization, pos_kind: "ascend_pos", ascend_name: "BIKE_LANE_CHIC") }
      it "returns the organization" do
        expect(bulk_import.organization_for_ascend_name).to eq organization
      end
    end
    context "close name" do
      let!(:organization) { FactoryBot.create(:organization, pos_kind: "ascend_pos", kind: "bike_shop", ascend_name: "bike lane chic") }
      it "returns the organization" do
        expect(bulk_import.organization_for_ascend_name).to eq organization
      end
    end
    context "close but not name" do
      let!(:organization) { FactoryBot.create(:organization, pos_kind: "ascend_pos", kind: "bike_shop", ascend_name: "bike laning") }
      it "returns the organization" do
        expect(bulk_import.organization_for_ascend_name).to be_nil
      end
    end
  end

  describe "check_ascend_import_processable!" do
    let!(:bulk_import) { FactoryBot.build(:bulk_import_ascend) }
    before { Sidekiq::Job.clear_all }
    it "adds an ascend error, sends email" do
      expect(bulk_import.created_at).to_not be_present # Bulk import is saved
      expect {
        expect(bulk_import.check_ascend_import_processable!).to be_falsey
      }.to change(UnknownOrganizationForAscendImportJob.jobs, :count).by 1
      expect(bulk_import.created_at).to be_present # Bulk import is saved
      expect(bulk_import.kind).to eq "ascend"
      expect(bulk_import.import_errors.to_s).to match(/ascend/)
      expect(bulk_import.import_errors?).to be_truthy
      expect(UnknownOrganizationForAscendImportJob.jobs.map { |j| j["args"] }.flatten).to eq([bulk_import.id])
    end
    context "organization_id already present" do
      let!(:bulk_import) { FactoryBot.build(:bulk_import_ascend, organization_id: 12, import_errors: {ascend: "unable to associate"}) }
      it "returns true" do
        expect(bulk_import.created_at).to_not be_present # Bulk import is saved
        expect(bulk_import.import_errors?).to be_truthy
        expect {
          expect(bulk_import.check_ascend_import_processable!).to be_truthy
        }.to_not change(UnknownOrganizationForAscendImportJob.jobs, :count)
        expect(bulk_import.import_errors?).to be_falsey
        expect(bulk_import.created_at).to_not be_present # Bulk import is not saved
      end
    end
    context "organization with matching ascend_name" do
      let!(:organization) { FactoryBot.create(:organization_with_auto_user, ascend_name: "BIKE_LANE_CHIC") }
      it "sets attributes, removes error and saves (even though worker will save)" do
        bulk_import.send(:add_ascend_import_error!)
        bulk_import.reload
        expect(bulk_import.import_errors?).to be_truthy
        expect(bulk_import.organization_id).to_not be_present
        expect {
          expect(bulk_import.check_ascend_import_processable!).to be_truthy
        }.to_not change(UnknownOrganizationForAscendImportJob.jobs, :count)
        expect(bulk_import.organization_id).to eq organization.id
        expect(bulk_import.creator).to eq organization.auto_user
        expect(bulk_import.reload.organization_id).to be_present
      end
    end
  end
end
