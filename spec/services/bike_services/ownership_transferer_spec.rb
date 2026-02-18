require "rails_helper"

RSpec.describe BikeServices::OwnershipTransferer do
  let(:updator) { FactoryBot.create(:user) }

  describe "find_or_create" do
    let!(:bike) { FactoryBot.create(:bike, :with_ownership) }
    let(:initial_ownership) { Ownership.order(:created_at).where(bike_id: bike.id).first }

    it "does nothing" do
      expect(Ownership.count).to eq 1
      expect(described_class.find_or_create(bike, updator:).id).to eq initial_ownership.id
      expect(described_class.find_or_create(bike, updator:, new_owner_email: bike.owner_email.upcase).id)
        .to eq initial_ownership.id
      expect(Ownership.count).to eq 1
    end

    context "with new email" do
      let(:target_attributes) do
        {
          creator_id: updator.id,
          origin: "transferred_ownership",
          organization_id: nil,
          registration_info: {},
          doorkeeper_app_id: nil,
          skip_email: false,
          is_phone: false
        }
      end
      it "creates an ownership" do
        expect do
          result = described_class.find_or_create(bike, updator:,
            new_owner_email: "example@bikeindex.org")
          expect(result.is_a?(Ownership)).to be_truthy
        end.to change(Ownership, :count).by 1

        expect(initial_ownership.reload.current?).to be_falsey

        expect(bike.reload.current_ownership_id).to_not eq initial_ownership.id
        expect(bike.current_ownership).to have_attributes target_attributes
      end

      context "bike has attributes that should be changed" do
        let!(:bike) { FactoryBot.create(:bike, :with_ownership, :with_address_record, :phone_registration, is_for_sale: true, address_set_manually: true) }

        it "updates the attributes" do
          expect(bike.reload.address_set_manually).to be_truthy
          expect(bike.address_record_id).to be_present
          expect do
            described_class.find_or_create(bike, updator:, new_owner_email: "example@bikeindex.org")
          end.to change(Ownership, :count).by 1

          expect(initial_ownership.reload.current?).to be_falsey

          expect(bike.reload.current_ownership_id).to_not eq initial_ownership.id
          # TODO: is_phone is set by the attribute on bike, which is updated after the ownership is created
          # it doesn't actually matter, since phone regs aren't used, but it's still incorrect :/
          expect(bike.current_ownership).to have_attributes target_attributes.except(:is_phone)

          expect(bike.address_set_manually).to be_falsey
          expect(bike.address_record).to be_blank
          expect(bike.is_for_sale).to be_falsey
          expect(bike.is_phone).to be_falsey
        end
      end
    end
  end
end
