require 'spec_helper'

describe Admin::MailSnippetsController do
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
      snippet = FactoryGirl.create(:mail_snippet)
      get :edit, id: snippet.id
    end
    it { is_expected.to respond_with(:success) }
    it { is_expected.to render_template(:edit) }
  end
end
