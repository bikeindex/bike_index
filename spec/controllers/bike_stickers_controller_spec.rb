require "rails_helper"

RSpec.describe BikeStickersController, type: :controller do
  describe "update" do
    let(:bike_sticker) { FactoryBot.create(:bike_sticker) }
    let(:bike) { FactoryBot.create(:bike) }
    context "no user" do
      it "responds with 401" do
        put :update, id: bike_sticker.code, bike_id: "9"
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(scanned_bike_path(bike_sticker.code))
      end
    end
    context "user present" do
      include_context :logged_in_as_user
      it "succeeds" do
        put :update, id: bike_sticker.code, bike_id: "#{bike.id}"
        expect(flash[:success]).to be_present
        bike_sticker.reload
        expect(bike_sticker.bike).to eq bike
      end
      context "bikeindex url" do
        it "succeeds" do
          put :update, id: bike_sticker.code, bike_id: "https://bikeindex.org/bikes/#{bike.id} "
          expect(flash[:success]).to be_present
          bike_sticker.reload
          expect(bike_sticker.bike).to eq bike
        end
      end
      context "bike not found" do
        it "shows error message" do
          put :update, id: bike_sticker.code, bike_id: "https://bikeindex.org/bikes/ "
          expect(flash[:error]).to be_present
          bike_sticker.reload
          expect(bike_sticker.bike).to be_nil
          expect(bike_sticker.user).to be_nil
        end
      end
      context "code not found" do
        it "responds with flash error" do
          put :update, id: "asdffdf", organization_id: "cvxcvcv"
          expect(flash[:error]).to be_present
        end
      end
      context "already claimed bike" do
        let(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_id: bike.id) }
        let(:bike2) { FactoryBot.create(:bike) }
        it "responds with flash error" do
          put :update, id: bike_sticker.code, bike_id: "https://bikeindex.org/bikes/#{bike2.id} "
          expect(flash[:error]).to be_present
          bike_sticker.reload
          expect(bike_sticker.bike).to eq bike
        end
        context "organized" do
          let(:organization) { FactoryBot.create(:organization) }
          let(:user) { FactoryBot.create(:organization_member, organization: organization) }
          let(:bike_sticker) { FactoryBot.create(:bike_sticker, bike_id: bike.id, organization: organization) }
          it "succeeds" do
            put :update, id: bike_sticker.code, bike_id: "  #{bike2.id} "
            expect(flash[:success]).to be_present
            bike_sticker.reload
            expect(bike_sticker.bike).to eq bike2
          end
        end
      end
    end
  end
end
