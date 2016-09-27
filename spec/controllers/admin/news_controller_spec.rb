require 'spec_helper'

describe Admin::NewsController, type: :controller do
  let(:subject) { FactoryGirl.create(:blog) }
  include_context :logged_in_as_super_admin

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
        get :edit, id: subject.to_param
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'update' do
    it 'updates available attributes' do
      blog_attrs = { title: 'new title thing stuff', body: '<p>html</p>' }
      put :update, id: subject.to_param, blog: blog_attrs
      subject.reload
      expect(subject.title).to eq blog_attrs[:title]
      expect(subject.body).to eq blog_attrs[:body]
    end
  end
end
