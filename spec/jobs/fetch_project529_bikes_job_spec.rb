require "rails_helper"

RSpec.describe FetchProject529BikesJob, type: :job do
  let(:instance) { described_class.new }

  describe "skip_scheduling?" do
    context "without a Project529Credential" do
      it "is true" do
        expect(ExternalRegistryCredential::Project529Credential.count).to eq 0
        expect(instance.skip_scheduling?).to be_truthy
      end
    end

    context "with a Project529Credential" do
      let!(:credential) { FactoryBot.create(:project529_credential) }
      it "is false" do
        expect(instance.skip_scheduling?).to be_falsey
      end
    end
  end

  context "with a Project529Credential and a stubbed client" do
    let!(:credential) { FactoryBot.create(:project529_credential) }
    before { allow_any_instance_of(ExternalRegistryClient::Project529Client).to receive(:bikes) { ExternalRegistryBike.none } }

    include_context :scheduled_job
    include_examples :scheduled_job_tests
  end
end
