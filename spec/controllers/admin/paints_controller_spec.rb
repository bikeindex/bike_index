require "rails_helper"

RSpec.describe Admin::PaintsController, type: :controller do
  include_context :logged_in_as_super_admin
  describe "index" do
    it "renders" do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      paint = FactoryBot.create(:paint)
      get :edit, params: { id: paint.id }
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end
end
