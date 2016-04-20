require 'spec_helper'

describe Admin::PaintsController do
  describe 'index' do
    before do
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :index
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:index) }
  end

  describe 'edit' do
    before do
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      paint = FactoryGirl.create(:paint)
      get :edit, id: paint.id 
      end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:edit) }
    it { is_expected.not_to set_the_flash }
  end
  
end
