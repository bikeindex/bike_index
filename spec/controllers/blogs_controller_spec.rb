require 'spec_helper'

describe BlogsController do
  describe 'index' do
    it 'redirects' do
      get :index
      expect(response).to redirect_to(news_index_url)
    end
  end

  describe 'show' do
    it 'redirects' do
      user = FactoryGirl.create(:user)
      blog = Blog.create(title: 'foo title', body: 'ummmmm good', user_id: user.id)
      get :show, id: blog.title_slug
      expect(response).to redirect_to(news_url(blog.title_slug))
    end
  end
end
