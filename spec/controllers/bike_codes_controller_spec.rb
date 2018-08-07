require "spec_helper"

describe BikeCodesController do
  describe "update" do
    let(:bike_code) { FactoryGirl.create(:bike_code) }
    let(:bike) { FactoryGirl.create(:bike) }
    context "no user" do
      it "responds with 401" do
        put :update, id: bike_code.code, bike_id: "9"
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(scanned_bike_path(bike_code.code))
      end
    end
    context "user present" do
      include_context :logged_in_as_user
      it "succeeds" do
        put :update, id: bike_code.code, bike_id: "#{bike.id}"
        expect(flash[:success]).to be_present
        bike_code.reload
        expect(bike_code.bike).to eq bike
      end
      context "bikeindex url" do
        it "succeeds" do
          put :update, id: bike_code.code, bike_id: "https://bikeindex.org/bikes/#{bike.id} "
          expect(flash[:success]).to be_present
          bike_code.reload
          expect(bike_code.bike).to eq bike
        end
      end
      context "bike not found" do
        it "shows error message" do
          put :update, id: bike_code.code, bike_id: "https://bikeindex.org/bikes/ "
          expect(flash[:error]).to be_present
          bike_code.reload
          expect(bike_code.bike).to be_nil
          expect(bike_code.user).to be_nil
        end
      end
      context "code not found" do
        it "responds with 404" do
          expect do
            put :update, id: "asdffdf", organization_id: "cvxcvcv"
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
      context "already claimed bike" do
        let(:bike_code) { FactoryGirl.create(:bike_code, bike_id: bike.id) }
        let(:bike2) { FactoryGirl.create(:bike) }
        it "responds with flash error" do
          put :update, id: bike_code.code, bike_id: "https://bikeindex.org/bikes/#{bike2.id} "
          expect(flash[:error]).to be_present
          bike_code.reload
          expect(bike_code.bike).to eq bike
        end
        context "organized" do
          let(:organization) { FactoryGirl.create(:organization) }
          let(:user) { FactoryGirl.create(:organization_member, organization: organization) }
          let(:bike_code) { FactoryGirl.create(:bike_code, bike_id: bike.id, organization: organization) }
          it "succeeds" do
            put :update, id: bike_code.code, bike_id: "  #{bike2.id} "
            expect(flash[:success]).to be_present
            bike_code.reload
            expect(bike_code.bike).to eq bike2
          end
        end
      end
    end
  end
end
