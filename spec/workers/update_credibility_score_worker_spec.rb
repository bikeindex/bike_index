require "rails_helper"

RSpec.describe UpdateCredibilityScoreWorker, type: :job do
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  describe "perform" do
    let(:bike) { FactoryBot.create(:bike) }
    it "schedules all the workers" do
      expect(bike.reload.credibility_score).to be_nil
      described_class.new.perform(bike.id)
      expect(bike.reload.credibility_score).to eq 50
    end
  end
end
