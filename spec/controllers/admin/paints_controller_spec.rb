require 'spec_helper'

describe Admin::PaintController do
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
      paint = FactoryGirl.create(:paint)
      get :edit, id: paint.id 
      end
    it { should respond_with(:success) }
    it { should render_template(:edit) }
    it { should_not set_the_flash }
  end
  
end
