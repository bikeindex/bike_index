require 'spec_helper'

describe TsvCreator do
  
  describe :create_manufacturer do 
    it "makes mnfgs"
  end

  describe :sent_to_uploader do 
    it "sends to uploader" 
  end

  describe :create_organization_count do 
    it "creates tsv with output bikes" do 
      ownership = FactoryGirl.create(:organization_ownership)
      organization = ownership.bike.creation_organization
      creator = TsvCreator.new
      target = "#{creator.org_counts_header}#{creator.org_count_row(ownership.bike)}"
      TsvUploader.any_instance.should_receive(:store!)
      output = creator.create_org_count(organization)
      expect(File.read(output)).to eq(target)
      expect(FileCacheMaintainer.files.kind_of?(Array)).to be_true
    end
  end

  describe :enqueue_creation do 
    it "creates jobs for the TSV creation" do 
      expect{
        TsvCreator.enqueue_creation
      }.to change(TsvCreatorWorker.jobs, :size).by(4)

      expect(TsvCreatorWorker.jobs.select{ |j| j['args'] == ['create_manufacturer']}).to be_present
      expect(TsvCreatorWorker.jobs.select{ |j| j['args'] == ['create_stolen_with_reports', true]}).to be_present
      expect(TsvCreatorWorker.jobs.select{ |j| j['args'] == ['create_stolen', true]}).to be_present
      expect(TsvCreatorWorker.jobs.select{ |j| j['args'] == ['create_daily_tsvs']}).to be_present
    end
  end

  describe :create_daily_tsvs do 
    it "calls create_stolen and create_stolen_with_reports with scoped query" do 
      stolen_record = FactoryGirl.create(:stolen_record, current: true, tsved_at: nil)
      tsv_creator = TsvCreator.new
      tsv_creator.should_receive(:create_stolen_with_reports).with(true, stolen_records: StolenRecord.approveds_with_reports.tsv_today)
      tsv_creator.should_receive(:create_stolen).with(true, stolen_records: StolenRecord.approveds.tsv_today)
      
      tsv_creator.create_daily_tsvs
      expect(tsv_creator.file_prefix).to eq("/spec/fixtures/tsv_creation/#{Time.now.year}_#{Time.now.month}_#{Time.now.day}_")
      stolen_record.reload
      expect(stolen_record.tsved_at).to be_present
    end
  end

end