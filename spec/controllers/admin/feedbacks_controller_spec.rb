require 'spec_helper'

describe Admin::FeedbacksController, type: :controller do
  let(:subject) { FactoryGirl.create(:feedback) }
  include_context :logged_in_as_super_admin

  describe 'index' do
    it 'renders' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'show' do
    it 'renders' do
      get :show, id: subject.to_param
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end
end
