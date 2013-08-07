require 'spec_helper'

describe BlogsController do

  describe :index do
    before do 
      get :index
    end
    it { should respond_with(:success) }
    it { should render_template(:index) }
  end

  describe :show do 
    before do 
      user = FactoryGirl.create(:user)
      blog = Blog.create(title: "foo title", body: "ummmmm good", user_id: user.id)
      get :show, id: blog.title_slug
    end
    it { should respond_with(:success) }
    it { should render_template(:show) }
  end

end