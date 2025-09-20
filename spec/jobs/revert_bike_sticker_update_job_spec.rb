require "rails_helper"

RSpec.describe RevertBikeStickerUpdateJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let!(:organization) { FactoryBot.create(:organization, :paid) }
    let!(:bike_sticker) { FactoryBot.create(:bike_sticker, organization:) }
    let!(:bike) { FactoryBot.create(:bike) }
    let!(:new_organization) { FactoryBot.create(:organization, :paid) }
    let(:user) { FactoryBot.create(:user, :with_organization, organization: new_organization) }

    it "does nothing if the update doesn't exist" do
      expect { instance.perform(33) }.to_not change(BikeStickerUpdate, :count)
    end

    context "kind: initial_claim" do
      let(:sticker_update_at) { 1.day.ago }
      let(:bike_sticker_update) do
        bike_sticker.claim(bike:, organization: new_organization, user:)
        bike_sticker.update_columns(claimed_at: sticker_update_at, updated_at: sticker_update_at)
        bike_sticker.bike_sticker_updates.last
      end
      let(:target_initial) do
        {
          claimed_at: nil,
          updated_at: Time.current,
          bike_id: nil,
          previous_bike_id: nil,
          organization_id: organization.id,
          secondary_organization_id: nil,
          user_id: nil
        }
      end
      let(:initial_update) do
        {kind: "initial_claim", organization_kind: "other_paid_organization", update_number: 1,
         user_id: user.id, organization_id: new_organization.id}
      end
      it "removes" do
        expect(organization.reload.is_paid).to be_truthy
        expect(new_organization.reload.is_paid).to be_truthy

        expect(bike_sticker_update.reload).to match_hash_indifferently initial_update
        expect(bike_sticker.reload.bike_sticker_updates.count).to eq 1
        expect(bike_sticker.claimed_at).to be_within(1).of sticker_update_at
        expect(bike_sticker.updated_at).to be_within(1).of sticker_update_at
        expect(bike_sticker.bike_id).to eq bike.id
        expect(bike_sticker.organization_id).to eq organization.id
        expect(bike_sticker.secondary_organization_id).to eq new_organization.id
        expect(bike_sticker.previous_bike_id).to be_nil

        expect { instance.perform(bike_sticker_update.id) }.to change(BikeStickerUpdate, :count).by(-1)

        expect(bike_sticker.reload.bike_sticker_updates.count).to eq 0
        expect(bike_sticker).to match_hash_indifferently target_initial
      end

      context "kind: re_claim" do
        let(:initial_claimed_at) { 1.week.ago }
        let(:bike2) { FactoryBot.create(:bike) }
        let(:user2) { FactoryBot.create(:user) }
        let!(:bike_sticker_update_initial) do
          bike_sticker.claim(bike: bike2, organization:, user: user2)
          bike_sticker.update_columns(claimed_at: initial_claimed_at, updated_at: initial_claimed_at)
          bs_update = bike_sticker.bike_sticker_updates.last
          bs_update.update_column(:created_at, initial_claimed_at)
          bs_update
        end

        let(:target_claim) do
          {
            claimed_at: initial_claimed_at,
            updated_at: Time.current,
            bike_id: bike2.id,
            previous_bike_id: nil,
            organization_id: organization.id,
            secondary_organization_id: nil,
            user_id: user2.id
          }
        end
        it "removes" do
          expect(bike_sticker_update.reload).to match_hash_indifferently(kind: "re_claim", update_number: 2)
          expect(bike_sticker.reload.claimed_at).to be_within(1).of sticker_update_at
          expect(bike_sticker.previous_bike_id).to eq bike2.id

          expect { instance.perform(bike_sticker_update.id) }.to change(BikeStickerUpdate, :count).by(-1)

          expect(bike_sticker.reload.bike_sticker_updates.count).to eq 1
          expect(bike_sticker).to match_hash_indifferently target_claim
        end

        context "with a failed claim" do
          let(:bike_sticker_update_fail) do
            bike_sticker.claim(bike: "124124141", organization:, user:)
            bike_sticker.bike_sticker_updates.last
          end
          it "ignores the failed claim" do
            expect(bike_sticker_update_fail.reload).to match_hash_indifferently(kind: "failed_claim", update_number: 2)
            expect(bike_sticker_update.reload).to match_hash_indifferently(kind: "re_claim", update_number: 2)

            expect(bike_sticker.reload.claimed_at).to be_within(1).of sticker_update_at
            expect(bike_sticker.previous_bike_id).to eq bike2.id
            expect(bike_sticker.bike_sticker_updates.count).to eq 3

            expect { instance.perform(bike_sticker_update.id) }.to change(BikeStickerUpdate, :count).by(-1)

            expect(bike_sticker.reload.bike_sticker_updates.count).to eq 2
            expect(bike_sticker).to match_hash_indifferently target_claim
          end
        end

        context "with a following successful claim" do
          let(:user3) { FactoryBot.create(:user) }
          let(:bike3) { FactoryBot.create(:bike) }
          let(:update_time) { 3.hours.ago }
          let(:bike_sticker_update_following) do
            bike_sticker.claim(user: user3, bike: bike3)
            bike_sticker.update(claimed_at: update_time)
            bs_update = bike_sticker.bike_sticker_updates.last
            bs_update.update_column(:created_at, update_time)
            bs_update
          end
          let(:target_updated) do
            {
              claimed_at: update_time,
              bike_id: bike3.id,
              user_id: user3.id,
              previous_bike_id: bike2.id,
              organization_id: organization.id,
              secondary_organization_id: nil
            }
          end
          it "removes but doesn't update the claim" do
            expect(bike_sticker_update.reload).to match_hash_indifferently(kind: "re_claim", update_number: 2)
            expect(bike_sticker_update_following.reload).to match_hash_indifferently(kind: "re_claim", update_number: 3, user: user3)

            expect { instance.perform(bike_sticker_update.id) }.to raise_error(/following claim/i)

            # expect { instance.perform(bike_sticker_update.id) }.to change(BikeStickerUpdate, :count).by(-1)

            # expect(bike_sticker.reload.bike_sticker_updates.count).to eq 2
            # expect(bike_sticker).to match_hash_indifferently target_reclaimed
            # expect(bike_sticker_update_following.reload.update_number).to eq 2
          end
        end

        context "with a following failed claim" do
          let(:user3) { FactoryBot.create(:user) }
          let(:bike3) { FactoryBot.create(:bike) }
          let(:bike_sticker_update_following) do
            bike_sticker.claim_if_permitted(user: user3, bike: bike3)
            bs_update = bike_sticker.bike_sticker_updates.last
            bs_update.update_column(:created_at, 3.hours.ago)
            bs_update
          end
          let(:target_reclaimed) do
            {
              claimed_at: Time.current,
              updated_at: Time.current,
              bike_id: bike3.id,
              previous_bike_id: bike2.id,
              organization_id: organization.id,
              secondary_organization_id: nil,
              user_id: user3.id
            }
          end
          it "calls claim again" do
            expect(bike_sticker_update.reload).to match_hash_indifferently(kind: "re_claim", update_number: 2)
            expect(bike_sticker_update_following.reload).to match_hash_indifferently(kind: "failed_claim", update_number: 3, user: user3)
            expect(bike_sticker.previous_bike_id).to eq bike2.id

            expect(bike_sticker.reload.claimed_at).to be_within(1).of sticker_update_at
            expect(bike_sticker.previous_bike_id).to eq bike2.id
            expect(bike_sticker.bike_sticker_updates.count).to eq 3

            expect { instance.perform(bike_sticker_update.id) }.to raise_error(/following claim/i)

            # expect { instance.perform(bike_sticker_update.id) }.to change(BikeStickerUpdate, :count).by(-1)

            # expect(bike_sticker.reload.bike_sticker_updates.count).to eq 2
            # expect(bike_sticker).to match_hash_indifferently target_reclaimed
          end
        end
      end
    end
  end
end
