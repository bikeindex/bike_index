require 'spec_helper'

describe Admin::FailedBikesController do
  describe 'index' do
    before do
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :index
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:index) }
  end

  describe 'show' do
    before do
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      b_param = BParam.create(creator_id: user.id)
      get :show, id: b_param.id
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:show) }
  end
end
