require "rails_helper"

RSpec.describe Admin::StolenBikesController, type: :controller do
  render_views

  let(:user) { FactoryBot.create(:admin) }
  before do
    set_current_user(user)
  end

  describe "index" do
    it "renders the index template with stolen bikes" do
      _bike = FactoryBot.create(:bike)
      stolen_bike = FactoryBot.create(:stolen_bike)

      get :index

      expect(response.code).to eq("200")
      expect(response).to render_template("index")
      expect(flash).to_not be_present
      expect(assigns(:bikes)).to match_array([stolen_bike])
    end
  end

  describe "edit" do
    let(:bike) { FactoryBot.create(:stolen_bike) }
    let(:stolen_record) { bike.current_stolen_record }
    it "renders" do
      expect(stolen_record.recovery_link_token).to_not be_present
      get :edit, id: bike.id
      stolen_record.reload

      expect(stolen_record.recovery_link_token).to be_present
      expect(response.code).to eq("200")
      expect(response).to render_template("edit")
      expect(flash).to_not be_present
    end
  end

  describe "update" do
    context "success" do
      it "updates the bike and calls update_ownership and serial_normalizer" do
        expect_any_instance_of(BikeUpdator).to receive(:update_ownership)
        expect_any_instance_of(SerialNormalizer).to receive(:save_segments)
        ownership = FactoryBot.create(:ownership)
        bike = ownership.bike
        put :update, id: bike.id, bike: { serial_number: "stuff" }
        expect(response).to redirect_to(:edit_admin_stolen_bike)
        expect(flash).to be_present
      end
    end
  end
end
