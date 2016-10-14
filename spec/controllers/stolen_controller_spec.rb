require 'spec_helper'

describe StolenController do
  describe 'index' do
    context 'with subdomain' do
      it 'redirects to no subdomain' do
        @request.host = 'stolen.example.com'
        get :index
        expect(response).to redirect_to stolen_index_url(subdomain: false)
      end
    end
    it 'renders with layout even if text' do
      get :index, format: :text
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(response).to render_with_layout('application_revised')
    end
  end

  describe 'faq' do
    it 'redirects other pages to index' do
      get :show, id: 'faq'
      expect(response).to redirect_to stolen_index_url
    end
  end
end
