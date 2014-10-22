require 'spec_helper'

describe Admin::RecoveriesController do

  describe :index do 
    before do 
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
    it { should_not set_the_flash }
  end

  describe :approve do 
    it "should post a single recovery" do 
      Sidekiq::Testing.fake!
      user = FactoryGirl.create(:user, superuser: true)
      set_current_user(user)
      recovery = FactoryGirl.create(:stolen_record)
      expect {
        post :approve, id: recovery.id
      }.to change(RecoveryNotifyWorker.jobs, :size).by(1)
      # expect(RecoveryNotifyWorker).to have_enqueued_job(recovery.id)
    end

    # it "shouldn't die if we're missing something" do 
    #   user = FactoryGirl.create(:user, admin: true)
    #   sign_in :user, user
    #   request.env["HTTP_REFERER"] = 'http://localhost:1308/admin/products'
    #   product1 = FactoryGirl.create(:product)
    #   product2 = FactoryGirl.create(:product)
    #   product3 = FactoryGirl.create(:product)
    #   tag1 = FactoryGirl.create(:used_tag)
    #   tag2 = FactoryGirl.create(:used_tag, context: 'type')
    #   update_params = {
    #     products_selected: [ product1.id, product2.id ],
    #   }
    #   post :update_tags, update_params
    #   product2.reload.type_list.first.should be_false
    #   product1.reload.occasion_list.first.should be_false
    #   product3.reload.type_list.first.should be_false
    # end
    
    # it "should delete tags if we ask nicely" do 
    #   user = FactoryGirl.create(:user, admin: true)
    #   sign_in :user, user
    #   request.env["HTTP_REFERER"] = 'http://localhost:1308/admin/products'
    #   product1 = FactoryGirl.create(:product)
    #   product2 = FactoryGirl.create(:product)
    #   product3 = FactoryGirl.create(:product)
    #   tag1 = FactoryGirl.create(:used_tag)
    #   tag2 = FactoryGirl.create(:used_tag, context: 'type')
    #   product1.occasion_list << tag1.name
    #   product1.type_list << tag2.name
    #   product2.type_list << tag2.name
    #   product3.occasion_list << tag1.name
    #   update_params = {
    #     tags_selected: [ tag1.id, tag2.id ],
    #     products_selected: { product1.id => product1.id, product2.id => product2.id },
    #     remove_tags: true
    #   }
    #   post :update_tags, update_params
    #   product1.reload.occasion_list.first.should be_false
    #   product1.reload.type_list.first.should be_false
    #   product2.reload.type_list.first.should be_false
    #   product3.occasion_list.first.should eq(tag1.name)
    # end
  end

end
