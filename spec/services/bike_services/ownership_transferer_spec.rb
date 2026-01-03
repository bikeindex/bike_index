require "rails_helper"

RSpec.describe BikeServices::OwnershipTransferer do
  let(:updator) { FactoryBot.create(:user) }

  describe "create_if_changed" do
    let!(:bike) { FactoryBot.create(:bike, :with_ownership) }
    let(:initial_ownership) { Ownership.order(:created_at).where(bike_id: bike.id).first }

    it "does nothing" do
      expect do
        expect(described_class.create_if_changed(bike, updator:)).to be_nil
      end.to change(Ownership, :count).by 0
    end

    context "with new email" do
      let(:target_attributes) do
        {
          creator_id: updator.id,
          origin: "transferred_ownership",
          organization_id: nil,
          registration_info: {},
          doorkeeper_app_id: nil,
          skip_email: false
        }
      end
      it "creates an ownership" do
        expect do
          result = described_class.create_if_changed(bike, updator:,
            new_owner_email: "example@bikeindex.org")
          expect(result.is_a?(Ownership)).to be_truthy
        end.to change(Ownership, :count).by 1

        expect(initial_ownership.reload.current?).to be_falsey

        expect(bike.reload.current_ownership_id).to_not eq initial_ownership.id
        expect(bike.current_ownership).to match_hash_indifferently target_attributes
      end
    end
  end
end
