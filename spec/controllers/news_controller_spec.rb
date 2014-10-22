require 'spec_helper'

describe NewsController do

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
  
  describe :show do 
    # It should render the blog if the old title slug matches
    before do
      user = FactoryGirl.create(:user)
      blog = Blog.create(title: "foo title", body: "ummmmm good", user_id: user.id, old_title_slug: "an-older-title")
      get :show, id: blog.old_title_slug
    end
    it { should respond_with(:success) }
    it { should render_template(:show) }
  end

  describe :show do 
    # It should render the blog if the id matches
    before do
      user = FactoryGirl.create(:user)
      blog = Blog.create(title: "foo title", body: "ummmmm good", user_id: user.id, old_title_slug: "an-older-title")
      get :show, id: blog.id
    end
    it { should respond_with(:success) }
    it { should render_template(:show) }
  end

end
