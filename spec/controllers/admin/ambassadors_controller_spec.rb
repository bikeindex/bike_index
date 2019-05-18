require "spec_helper"

describe Admin::AmbassadorsController, type: :controller do
  describe "#index" do
    include_context :logged_in_as_super_admin

    it "renders the index template with paginated ambassadors" do
      FactoryBot.create_list(:ambassador, 3)

      get :index, page: 1, per_page: 2

      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(flash).to_not be_present
      expect(assigns(:page_id)).to eq("admin_ambassadors_index")
      expect(assigns(:ambassadors).count).to eq(2)
    end
  end

  describe "#show" do
    include_context :logged_in_as_super_admin

    it "renders the show template with the found ambassador" do
      ambassador = FactoryBot.create(:ambassador)

      get :show, id: ambassador.id

      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
      expect(flash).to_not be_present
      expect(assigns(:page_id)).to eq("admin_ambassadors_show")
      expect(assigns(:ambassador)).to eq(ambassador)
    end
  end
end
