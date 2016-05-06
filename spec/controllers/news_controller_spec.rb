require 'spec_helper'

describe NewsController do
  context 'legacy' do
    describe 'index' do
      it 'renders' do
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template('index')
      end
    end

    describe 'show' do
      let(:user) { FactoryGirl.create(:user) }
      let(:blog) { Blog.create(title: 'foo title', body: 'ummmmm good', user_id: user.id, old_title_slug: 'an-older-title') }
      context 'title slug' do
        it 'renders' do
          get :show, id: blog.title_slug
          expect(response.status).to eq(200)
          expect(response).to render_template('show')
        end
      end
      context 'old title slug' do
        it 'renders' do
          get :show, id: blog.old_title_slug
          expect(response.status).to eq(200)
          expect(response).to render_template('show')
        end
      end
      context 'id' do
        it 'renders' do
          get :show, id: blog.id
          expect(response.status).to eq(200)
          expect(response).to render_template('show')
        end
      end
    end
  end

  context 'revised' do
    describe 'index' do
      it 'renders' do
        get :index
        expect(response.status).to eq(200)
        expect(response).to render_template('index')
        expect(response).to render_with_layout('application_revised')
      end
    end

    describe 'show' do
      let(:user) { FactoryGirl.create(:user) }
      let(:blog) { Blog.create(title: 'foo title', body: 'ummmmm good', user_id: user.id, old_title_slug: 'an-older-title') }
      it 'renders' do
        get :show, id: blog.title_slug
        expect(response.status).to eq(200)
        expect(response).to render_template('show')
        expect(response).to render_with_layout('application_revised')
      end
    end
  end
end
