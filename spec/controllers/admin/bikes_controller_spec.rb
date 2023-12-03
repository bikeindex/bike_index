require "rails_helper"

# NOTE: put new specs in the request spec, not here.

RSpec.describe Admin::BikesController, type: :controller do
  include_context :logged_in_as_superuser

  describe "update" do
    context "valid return_to url" do
      it "redirects" do
        bike = FactoryBot.create(:bike, serial_number: "og serial")
        session[:return_to] = "/about"
        opts = {
          id: bike.id,
          bike: {serial_number: "ssssssssss"}
        }
        put :update, params: opts
        bike.reload
        expect(bike.serial_number).to eq("ssssssssss")
        expect(response).to redirect_to "/about"
        expect(session[:return_to]).to be_nil
      end
    end
  end

  describe "ignore_duplicate" do
    before do
      request.env["HTTP_REFERER"] = "http://localhost:3000/admin/bikes/missing_manufacturers"
    end
    context "marked ignore" do
      it "duplicates are ignore" do
        duplicate_bike_group = DuplicateBikeGroup.create
        expect(duplicate_bike_group.ignore).to be_falsey
        put :ignore_duplicate_toggle, params: {id: duplicate_bike_group.id}
        duplicate_bike_group.reload

        expect(duplicate_bike_group.ignore).to be_truthy
        expect(response).to redirect_to "http://localhost:3000/admin/bikes/missing_manufacturers"
      end
    end

    context "duplicate group unignore" do
      it "marks a duplicate group unignore" do
        duplicate_bike_group = DuplicateBikeGroup.create(ignore: true)
        expect(duplicate_bike_group.ignore).to be_truthy
        put :ignore_duplicate_toggle, params: {id: duplicate_bike_group.id}
        duplicate_bike_group.reload

        expect(duplicate_bike_group.ignore).to be_falsey
        expect(response).to redirect_to "http://localhost:3000/admin/bikes/missing_manufacturers"
      end
    end
  end
end
