require 'spec_helper'

describe Admin::RecoveriesController do

  describe :index do 
    before do 
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
    it { should_not set_the_flash }
  end

  describe :approve do 
    it "posts a single recovery" do 
      Sidekiq::Testing.fake!
      user = FactoryGirl.create(:admin)
      set_current_user(user)
      recovery = FactoryGirl.create(:stolen_record)
      expect {
        post :approve, id: recovery.id
      }.to change(RecoveryNotifyWorker.jobs, :size).by(1)
      # expect(RecoveryNotifyWorker).to have_enqueued_job(recovery.id)
    end
   
  end
end
