require 'spec_helper'

describe Admin::MailSnippetsController do
  describe :index do 
    before do 
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :edit do 
    before do 
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      snippet = FactoryGirl.create(:mail_snippet)
      get :edit, id: snippet.id
    end
    it { should respond_with(:success) }
    it { should render_template(:edit) }
  end
end
