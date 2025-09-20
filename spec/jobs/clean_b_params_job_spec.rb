require "rails_helper"

RSpec.describe CleanBParamsJob, type: :job do
  include_context :scheduled_job
  include_examples :scheduled_job_tests

  it "is the correct queue and frequency" do
    expect(described_class.sidekiq_options["queue"]).to eq "low_priority" # overrides default
    expect(described_class.frequency).to be > 23.hours
  end

  describe "perform" do
    let!(:b_param1) { FactoryBot.create(:b_param) }
    let(:bike1) { FactoryBot.create(:bike) }
    let!(:b_param2) { FactoryBot.create(:b_param, created_bike_id: bike1.id) }
    let(:bike2) { FactoryBot.create(:bike) }
    let!(:b_param3) { FactoryBot.create(:b_param, created_bike_id: bike2.id) }
    it "schedules all the workers" do
      b_param3.update_column :updated_at, Time.current - 1.week
      Sidekiq::Job.clear_all
      expect(BParam.count).to eq 3
      described_class.new.perform
      expect(BParam.count).to eq 2
      expect(BParam.pluck(:id)).to match_array([b_param1.id, b_param2.id])
    end
  end
end
