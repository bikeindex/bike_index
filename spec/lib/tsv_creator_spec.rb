require 'spec_helper'

describe TsvCreator do
  describe 'create_manufacturer' do
    it 'makes mnfgs'
  end

  describe 'sent_to_uploader' do
    it 'sends to uploader'
  end

  describe 'create_organization_count' do
    it 'creates tsv with output bikes' do
      ownership = FactoryGirl.create(:organization_ownership)
      organization = ownership.bike.creation_organization
      creator = TsvCreator.new
      target = "#{creator.org_counts_header}#{creator.org_count_row(ownership.bike)}"
      expect_any_instance_of(TsvUploader).to receive(:store!)
      output = creator.create_org_count(organization)
      expect(File.read(output)).to eq(target)
      expect(FileCacheMaintainer.files.is_a?(Array)).to be_truthy
    end
  end

  describe 'enqueue_creation' do
    it 'creates jobs for the TSV creation' do
      expect do
        TsvCreator.enqueue_creation
      end.to change(TsvCreatorWorker.jobs, :size).by(4)

      expect(TsvCreatorWorker.jobs.select { |j| j['args'] == ['create_manufacturer'] }).to be_present
      expect(TsvCreatorWorker.jobs.select { |j| j['args'] == ['create_stolen_with_reports', true] }).to be_present
      expect(TsvCreatorWorker.jobs.select { |j| j['args'] == ['create_stolen', true] }).to be_present
      expect(TsvCreatorWorker.jobs.select { |j| j['args'] == ['create_daily_tsvs'] }).to be_present
    end
  end

  describe 'create_daily_tsvs' do
    it 'calls create_stolen and create_stolen_with_reports with scoped query' do
      stolen_record = FactoryGirl.create(:stolen_record, current: true, tsved_at: nil)
      tsv_creator = TsvCreator.new
      expect(tsv_creator).to receive(:create_stolen_with_reports).with(true, stolen_records: StolenRecord.approveds_with_reports.tsv_today)
      expect(tsv_creator).to receive(:create_stolen).with(true, stolen_records: StolenRecord.approveds.tsv_today)

      tsv_creator.create_daily_tsvs
      expect(tsv_creator.file_prefix).to eq("/spec/fixtures/tsv_creation/#{Time.now.year}_#{Time.now.month}_#{Time.now.day}_")
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_present
    end
  end
end
