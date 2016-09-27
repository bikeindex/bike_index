require 'spec_helper'

describe Admin::MailSnippetsController do
  include_context :logged_in_as_super_admin

  describe 'index' do
    it 'renders without_organizations mail_snippets' do
      FactoryGirl.create(:organization_mail_snippet)
      mail_snippet = FactoryGirl.create(:mail_snippet)
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
      expect(assigns(:mail_snippets)).to eq([mail_snippet])
    end
  end

  describe 'edit' do
    context 'organization_mail_snippet' do
      let(:mail_snippet) { FactoryGirl.create(:organization_mail_snippet) }
      it 'redirects' do
        expect do
          get :edit, id: mail_snippet.id
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
    context 'non organized' do
      let(:mail_snippet) { FactoryGirl.create(:mail_snippet) }
      it 'renders' do
        get :edit, id: mail_snippet.id
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
  end
end
