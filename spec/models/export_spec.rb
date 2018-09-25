require "spec_helper"

RSpec.describe Export, type: :model do
  let(:organization) { export.organization }

  describe "scope and method for stolen_no_blacklist" do
    let(:export) { FactoryGirl.create(:export, options: { with_blacklist: true, headers: %w[party registered_at] }) }
    it "is with blacklist" do
      expect(export.stolen?).to be_truthy
      expect(export.option?(:with_blacklist)).to be_truthy
      expect(export.option?(:only_serials_and_police_reports)).to be_falsey
      expect(export.description).to eq "Stolen"
      expect(export.headers).to eq(["registered_at"]) # Just checking that we ignore things
      expect(Export.stolen).to eq([export])
    end
  end
  describe "organization" do
    let(:export) { FactoryGirl.create(:export_organization) }
    it "is as expected" do
      expect(export.options).to eq(Export.default_options("organization"))
      expect(export.stolen?).to be_falsey
      expect(export.organization?).to be_truthy
      expect(export.option?("start_at")).to be_falsey
      expect(Export.organization).to eq([export])
      expect(export.bikes_scoped.to_sql).to eq organization.bikes.to_sql
    end
    context "no organization" do
      let(:export) { FactoryGirl.build(:export_organization, organization: nil) }
      it "is invalid without organization" do
        export.save
        expect(export.valid?).to be_falsey
        expect(export.errors.full_messages.to_s).to match(/organization/i)
      end
    end
  end

  describe "tmp_file" do
    let(:export) { FactoryGirl.build(:export, file_format: "csv") }
    it "has the correct format" do
      expect(export.kind).to eq "stolen"
      expect(export.tmp_file.path.to_s).to match(/\.csv\z/)
      export.tmp_file.close
      export.tmp_file.unlink
    end
  end

  describe "assignment" do
    let(:time_start) { "2018-01-30T23:57:56" }
    let(:time_end) { "2018-08-23T23:51:56" }
    let(:target_start) { 1517378276 }
    let(:target_end) { 1535086316 }
    let(:timezone) { "America/Chicago" }
    let(:export) { FactoryGirl.build(:export) }
    it "assigns correctly" do
      export.update_attributes(timezone: timezone, start_at: time_start, end_at: time_end, headers: %w[party registered_at])
      expect(export.start_at.to_i).to be_within(1).of target_start
      expect(export.end_at.to_i).to be_within(1).of target_end
      expect(export.headers).to eq(["registered_at"])
    end
  end

  describe "bikes_scoped" do
    # Pending - we're getting the organization scopes up and running before migrating existing TsvCreator tasks
    # But we eventually want to add stolen tsv's into here
    # context "stolen" do
    #   it "matches existing tsv scopes"
    # end
    context "organization" do
      let(:export) { FactoryGirl.create(:export_organization, file: nil) }
      let(:start_time) { Time.now - 20.hours }
      let(:end_time) { Time.now - 5.minutes }
      it "has the scopes we expect" do
        expect(export.bikes_scoped.to_sql).to eq organization.bikes.to_sql
        export.options = export.options.merge("start_at" => start_time)
        expect(export.bikes_scoped.to_sql).to eq organization.bikes.where("bikes.created_at > ?", export.start_at).to_sql
        export.options = export.options.merge("end_at" => end_time)
        expect(export.bikes_scoped.to_sql).to eq organization.bikes.where(created_at: export.start_at..export.end_at).to_sql
      end
    end
  end
end
