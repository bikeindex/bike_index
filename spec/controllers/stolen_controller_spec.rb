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
    context 'legacy' do
      it 'renders with application_updated layout' do
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(response).to render_with_layout('application_updated')
      end
    end
    context 'revised' do
      it 'renders with revised_layout' do
        allow(controller).to receive(:revised_layout_enabled?) { true }
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(response).to render_with_layout('application_revised')
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
