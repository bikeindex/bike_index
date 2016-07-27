require 'spec_helper'

describe Admin::PaintsController do
  describe 'index' do
    it 'renders' do
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'edit' do
    it 'renders' do
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      paint = FactoryGirl.create(:paint)
      get :edit, id: paint.id
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end
end
