require 'spec_helper'

describe Admin::PaintsController do
  include_context :logged_in_as_super_admin
  describe 'index' do
    it 'renders' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'edit' do
    it 'renders' do
      paint = FactoryGirl.create(:paint)
      get :edit, id: paint.id
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end
end
