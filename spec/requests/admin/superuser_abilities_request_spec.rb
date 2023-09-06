require "rails_helper"

base_url = "/admin/superuser_abilities"
RSpec.describe Admin::SuperuserAbilitiesController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let(:user_subject) { FactoryBot.create(:user) }
  let!(:superuser_ability) { SuperuserAbility.create(user: user_subject) }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:superuser_abilities)).to eq([])
    end
  end

  describe "edit" do
    it "renders" do
      get "#{base_url}/#{superuser_ability.id}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end
end
