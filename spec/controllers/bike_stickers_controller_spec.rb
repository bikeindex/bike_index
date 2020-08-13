require "rails_helper"

RSpec.describe BikeStickersController, type: :controller do
  describe "update" do
    let(:bike_sticker) { FactoryBot.create(:bike_sticker) }
    let(:bike) { FactoryBot.create(:bike) }
    context "no user" do
      it "responds with 401" do
        put :update, params: {id: bike_sticker.code, bike_id: "9"}
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(scanned_bike_path(bike_sticker.code))
      end
    end
    context "user present" do
      include_context :logged_in_as_user
      it "succeeds" do
        expect {
          put :update, params: {id: bike_sticker.code, bike_id: bike.id.to_s}
        }.to change(BikeStickerUpdate, :count).by 1
        expect(flash[:success]).to be_present
        bike_sticker.reload
        expect(bike_sticker.bike).to eq bike
        expect(bike_sticker.bike_sticker_updates.last.kind).to eq "initial_claim"
      end
      context "bikeindex url" do
        it "succeeds" do
          expect {
            put :update, params: {id: bike_sticker.code, bike_id: "https://bikeindex.org/bikes/#{bike.id} "}
          }.to change(BikeStickerUpdate, :count).by 1
          expect(flash[:success]).to be_present
          bike_sticker.reload
          expect(bike_sticker.bike).to eq bike
          expect(bike_sticker.bike_sticker_updates.last.kind).to eq "initial_claim"
        end
      end
      context "bike not found" do
        it "shows error message" do
          expect {
            put :update, params: {id: bike_sticker.code, bike_id: "https://bikeindex.org/bikes/ "}
          }.to change(BikeStickerUpdate, :count).by 1
          expect(flash[:error]).to be_present
          bike_sticker.reload
          expect(bike_sticker.bike).to be_nil
          expect(bike_sticker.user).to be_nil
          expect(bike_sticker.bike_sticker_updates.last.kind).to eq "failed_claim"
        end
      end
      context "code not found" do
        it "responds with flash error" do
          expect {
            put :update, params: {id: "asdffdf", organization_id: "cvxcvcv"}
          }.to_not change(BikeStickerUpdate, :count)
          expect(flash[:error]).to be_present
        end
      end
      context "already claimed bike" do
        let(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_id: bike.id) }
        let(:bike2) { FactoryBot.create(:bike) }
        it "responds with flash error" do
          expect {
            put :update, params: {id: bike_sticker.code, bike_id: "https://bikeindex.org/bikes/#{bike2.id} "}
          }.to change(BikeStickerUpdate, :count).by 1
          expect(flash[:error]).to be_present
          bike_sticker.reload
          expect(bike_sticker.bike).to eq bike
          expect(bike_sticker.bike_sticker_updates.last.kind).to eq "failed_claim"
        end
        context "organized" do
          let(:organization) { FactoryBot.create(:organization) }
          let(:user) { FactoryBot.create(:organization_member, organization: organization) }
          let(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_id: bike.id, organization: organization) }
          it "succeeds" do
            expect {
              put :update, params: {id: bike_sticker.code, bike_id: "  #{bike2.id} "}
            }.to change(BikeStickerUpdate, :count).by 1
            expect(flash[:success]).to be_present
            bike_sticker.reload
            expect(bike_sticker.bike).to eq bike2
            expect(bike_sticker.bike_sticker_updates.last.kind).to eq "initial_claim"
          end
        end
      end
    end
  end
end
