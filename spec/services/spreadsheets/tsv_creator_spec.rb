require "rails_helper"

RSpec.describe Spreadsheets::TsvCreator do
  let(:instance) { described_class.new }

  describe "create_manufacturer" do
    it "makes mnfgs" do
      # Added lamest test possible in PR#2453
      # NOTE: the code wasn't actually improved in this PR though
      expect(instance.create_manufacturer).to be_present
    end
  end

  describe "create_organization_count" do
    it "creates tsv with output bikes" do
      bike = FactoryBot.create(:bike_organized)
      organization = bike.creation_organization
      target = "#{instance.org_counts_header}#{instance.org_count_row(bike)}"
      expect_any_instance_of(TsvUploader).to receive(:store!)
      expect_any_instance_of(TsvUploader).to receive(:current_path) { "some-file.tsv" }
      output = instance.create_org_count(organization)
      expect(File.read(output)).to eq(target)
      expect(FileCacheMaintainer.files.is_a?(Array)).to be_truthy
    end
  end

  describe "create_daily_tsvs" do
    it "calls create_stolen and create_stolen_with_reports with scoped query" do
      stolen_record = FactoryBot.create(:stolen_record, current: true, tsved_at: nil)
      expect(instance).to receive(:create_stolen_with_reports).with(true, stolen_records: StolenRecord.approveds_with_reports.tsv_today)
      expect(instance).to receive(:create_stolen).with(true, stolen_records: StolenRecord.approveds.tsv_today)

      instance.create_daily_tsvs
      expect(instance.file_prefix).to eq("/spec/fixtures/tsv_creation/#{Time.current.year}_#{Time.current.month}_#{Time.current.day}_")
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_present
    end
  end
end
