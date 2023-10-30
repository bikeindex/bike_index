require "rails_helper"

RSpec.describe ModelAttestation, type: :model do
  describe "factory" do
    let(:model_attestation) { FactoryBot.create(:model_attestation) }
    it "is valid" do
      expect(model_attestation).to be_valid
    end
  end
end
