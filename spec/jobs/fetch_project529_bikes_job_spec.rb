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
end
