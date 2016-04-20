require 'spec_helper'

describe StolenController do
  describe 'index' do
    context 'no subdomain' do
      before do
        get :index
      end
      it { is_expected.to respond_with(:success) }
      it { is_expected.to render_template(:index) }
    end
    context 'with subdomain' do
      it 'redirects to no subdomain' do
        @request.host = 'stolen.example.com'
        get :index
        expect(response).to redirect_to stolen_index_url(subdomain: false)
      end
    end
  end

  describe 'faq' do
    it 'redirects other pages to index' do
      get :show, id: 'faq'
      expect(response).to redirect_to stolen_index_url
    end
  end
end
