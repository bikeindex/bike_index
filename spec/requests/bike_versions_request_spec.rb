require "rails_helper"

RSpec.describe BikeVersionsController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/bike_versions" }
  let(:bike_version) { FactoryBot.create(:bike_version, owner: current_user, description: "cool bike, boo") }

  describe "index" do
    it "renders" do
      expect(bike_version).to be_present
      get base_url
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
      expect(assigns(:bike_versions).pluck(:id)).to eq([bike_version.id])

      get "#{base_url}?query_items%5B%5D=boo"
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
      expect(assigns(:interpreted_params)).to eq({query: "boo", stolenness: "non"})
      expect(assigns(:bike_versions).pluck(:id)).to eq([bike_version.id])

      get "#{base_url}?query_items%5B%5D=booboo"
      expect(response.code).to eq("200")
      expect(response).to render_template(:index)
      expect(assigns(:bike_versions).pluck(:id)).to eq([])
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{bike_version.to_param}"
      expect(response.code).to eq "200"
      expect(response).to render_template(:show)

      # Hidden
      bike_version.update(visibility: "user_hidden")
      expect(bike_version.authorized?(current_user)).to be_truthy
      get "#{base_url}/#{bike_version.to_param}"
      expect(response.code).to eq "200"
      expect(response).to render_template(:show)
      expect(response.body).to match(/hidden/i)

      # And deleted
      bike_version.update(visibility: "visible_not_related", deleted_at: Time.current)
      expect(bike_version.authorized?(current_user)).to be_falsey
      get "#{base_url}/#{bike_version.to_param}"
      expect(response.status).to eq 404
    end
    context "superadmin" do
      let(:current_user) { FactoryBot.create(:superuser) }
      it "renders, when hidden or deleted" do
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
        expect(response.body).to_not match(/deleted/i)
        expect(response.body).to_not match(/hidden/i)

        # User hidden
        bike_version.update(visibility: "user_hidden")
        expect(bike_version.authorized?(current_user)).to be_truthy
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)
        expect(response.body).to match(/hidden/i)

        # Deleted
        bike_version.update(visibility: "visible_not_related", deleted_at: Time.current)
        expect(bike_version.authorized?(current_user)).to be_truthy
        get "#{base_url}/#{bike_version.to_param}"
        expect(response).to render_template(:show)
        expect(response.body).to match(/deleted/i)
      end
    end
    context "no current_user" do
      let(:current_user) { nil }
      let(:bike_version) { FactoryBot.create(:bike_version) }
      it "renders" do
        expect(bike_version.reload.visibility).to eq "visible_not_related"
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.code).to eq "200"
        expect(response).to render_template(:show)

        # User hidden
        bike_version.update(visibility: "user_hidden")
        expect(bike_version.authorized?(current_user)).to be_falsey
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.status).to eq 404

        # And deleted
        bike_version.update(visibility: "visible_not_related", deleted_at: Time.current)
        expect(bike_version.authorized?(current_user)).to be_falsey
        get "#{base_url}/#{bike_version.to_param}"
        expect(response.status).to eq 404
      end
    end
  end

  describe "create" do
    let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
    it "creates" do
      expect do
        post base_url, params: {bike_id: bike.id}
      end.to change(BikeVersion, :count).by 1
      expect(flash[:success]).to be_present
      new_bike_version = BikeVersion.last
      expect(new_bike_version.owner_id).to eq current_user.id
      expect(new_bike_version.bike_id).to eq bike.id
    end
    context "not users bike" do
      let!(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
      it "does not create" do
        expect(bike.reload.authorized?(current_user)).to be_falsey
        expect do
          post base_url, params: {bike_id: bike.id}
        end.to change(BikeVersion, :count).by 0
        expect(flash[:error]).to be_present
      end
    end
  end

  describe "update" do
    let(:color) { FactoryBot.create(:color) }
    let(:valid_update_params) do
      {
        name: "some new name",
        description: "New description",
        primary_frame_color_id: color.id,
        secondary_frame_color_id: FactoryBot.create(:color).id,
        tertiary_frame_color_id: color.id,
        front_wheel_size_id: FactoryBot.create(:wheel_size).id,
        rear_wheel_size_id: FactoryBot.create(:wheel_size).id,
        rear_gear_type_id: FactoryBot.create(:front_gear_type).id,
        front_gear_type_id: FactoryBot.create(:rear_gear_type).id,
        front_tire_narrow: true,
        handlebar_type: "drop_bar"
      }
    end
    it "updates" do
      expect(current_user.authorized?(bike_version)).to be_truthy
      expect(valid_update_params).to be_present
      og_bike_id = bike_version.bike_id
      bike_version.update(start_at: Time.current, end_at: Time.current)
      patch "#{base_url}/#{bike_version.id}", params: {
        bike_version: valid_update_params.merge(owner_id: current_user.id + 12,
          start_at: "",
          end_at: nil)
      }
      expect(flash[:success]).to be_present
      expect(bike_version.reload).to match_hash_indifferently valid_update_params
      expect(bike_version.owner_id).to eq current_user.id
      expect(bike_version.bike_id).to eq og_bike_id
      expect(bike_version.start_at).to be_blank
      expect(bike_version.end_at).to be_blank
    end
    it "updates with bike param" do
      expect(current_user.authorized?(bike_version)).to be_truthy
      expect(valid_update_params).to be_present

      patch "#{base_url}/#{bike_version.id}", params: {
        edit_template: "accessories",
        bike: valid_update_params.merge(start_at_shown: true,
          start_at: "2018-04-28T11:00",
          end_at_shown: "1",
          end_at: "2021-09-28T11:00",
          timezone: "Pacific Time (US & Canada)")
      }
      expect(flash[:success]).to be_present
      expect(response).to redirect_to("/bike_versions/#{bike_version.id}/edit/accessories")
      expect(bike_version.reload).to match_hash_indifferently valid_update_params
      expect(bike_version.start_at.to_i).to be_within(1).of 1524938400
      expect(bike_version.end_at.to_i).to be_within(1).of 1632852000
    end
    context "update visibility" do
      it "updates visibility" do
        expect(bike_version.reload.visibility).to eq "visible_not_related"
        patch "#{base_url}/#{bike_version.id}", params: {
          bike: {visibility: "user_hidden"}, edit_template: "remove"
        }
        expect(flash[:success]).to be_present
        expect(response).to redirect_to("/bike_versions/#{bike_version.id}/edit/remove")

        expect(bike_version.reload.visibility).to eq "user_hidden"
      end
    end
  end

  describe "delete" do
    it "destroys" do
      og_bike_id = bike_version.bike_id
      expect(BikeVersion.unscoped.count).to eq 1
      expect do
        delete "#{base_url}/#{bike_version.id}"
      end.to change(BikeVersion, :count).by(-1)
      expect(flash[:success]).to be_present
      expect(response).to redirect_to("/bikes/#{og_bike_id}/edit")
      expect(BikeVersion.unscoped.count).to eq 1
    end
  end
end
