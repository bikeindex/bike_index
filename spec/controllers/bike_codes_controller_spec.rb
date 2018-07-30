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
      it "works" do
        put :update, id: bike_code.code, bike_id: "#{bike.id}"
        expect(flash[:success]).to be_present
        bike_code.reload
        expect(bike_code.bike).to eq bike
      end
      context "bikeindex url" do
        it "works" do
          put :update, id: bike_code.code, bike_id: "https://bikeindex.org/bikes/#{bike.id} "
          expect(flash[:success]).to be_present
          bike_code.reload
          expect(bike_code.bike).to eq bike
        end
      end
      # context "not found" do
      #   it "responds with 404" do
      #     put :update, id: "asdffdf", organization_id: "cvxcvcv"
      #     expect(response[:code]).to eq 404
      #   end
      # end
      # context "already claimed bike" do
      #   it "responds with flash error" do

      #   end
      # end
      # context "user part of organization" do

      # end
    end
  end
end
