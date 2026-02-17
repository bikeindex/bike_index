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
      expect(assigns(:collection).pluck(:id)).to eq([superuser_ability.id])
    end
  end

  describe "edit" do
    it "renders" do
      get "#{base_url}/#{superuser_ability.id}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "update" do
    it "updates" do
      expect(superuser_ability.reload.su_options).to eq([])
      put "#{base_url}/#{superuser_ability.id}", params: {
        no_always_show_credibility: 1,
        no_hide_spam: 1
      }
      superuser_ability.reload
      expect(superuser_ability.reload.su_options).to eq(%w[no_always_show_credibility no_hide_spam])
    end
  end
end
