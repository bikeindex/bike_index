require 'spec_helper'

describe Admin::NewsController, type: :controller do
  let(:blog) { FactoryGirl.create(:blog) }
  let(:user) { FactoryGirl.create(:admin) }
  before do
    set_current_user(user)
  end

  describe 'index' do
    it 'renders' do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe 'edit' do
    context 'standard' do
      it 'renders' do
        get :edit, id: blog.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'blog update' do
    it 'updates the blog' do
      blog_attrs = { title: 'new title thing stuff', body: '<p>html</p>' }
      put :update, id: blog.to_param, blog: blog_attrs
      blog.reload
      expect(blog.title).to eq blog_attrs[:title]
      expect(blog.body).to eq blog_attrs[:body]
    end
  end
end
