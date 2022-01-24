require "rails_helper"

RSpec.describe CreateStolenGeojsonWorker, type: :job do
  let(:instance) { described_class.new }
  include_context :scheduled_worker
  include_examples :scheduled_worker_tests

  describe "perform" do
    let!(:bike) { FactoryBot.create(:stolen_bike) }
    it "creates geojson file" do
      instance.perform
    end
  end
end
