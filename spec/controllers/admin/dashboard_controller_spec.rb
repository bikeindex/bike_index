require 'spec_helper'

describe Admin::DashboardController do
  describe 'index' do
    context 'logged in as admin' do
      include_context :logged_in_as_super_admin
      it 'renders' do
        get :index
        expect(response.code).to eq '200'
        expect(response).to render_template(:index)
      end
    end
    context 'not logged in' do
      it 'redirects' do
        get :index
        expect(response.code).to eq('302')
        expect(response).to redirect_to(root_url)
      end
    end
    context 'non-admin' do
      include_context :logged_in_as_organization_admin
      it 'redirects' do
        get :index
        expect(response.code).to eq('302')
        expect(response).to redirect_to(user_home_url)
      end
    end
    context 'logged in as content admin' do
      it 'redirects' do
        user = FactoryGirl.create(:user, is_content_admin: true)
        set_current_user(user)
        get :index
        expect(response.code).to eq('302')
        expect(response).to redirect_to(admin_news_index_url)
      end
    end
  end

  context 'logged in as admin' do
    include_context :logged_in_as_super_admin
    describe 'invitations' do
      it 'renders' do
        user = FactoryGirl.create(:admin)
        set_current_user(user)
        BParam.create(creator_id: user.id)
        get :invitations
        expect(response.code).to eq '200'
        expect(response).to render_template(:invitations)
      end
    end

    describe 'maintenance' do
      it 'renders' do
        FactoryGirl.create(:manufacturer, name: 'other')
        FactoryGirl.create(:ctype, name: 'other')
        FactoryGirl.create(:handlebar_type, slug: 'other')
        user = FactoryGirl.create(:admin)
        set_current_user(user)
        BParam.create(creator_id: user.id)
        get :maintenance
        expect(response.code).to eq '200'
        expect(response).to render_template(:maintenance)
      end
    end

    describe 'tsvs' do
      it 'renders and assigns tsvs' do
        user = FactoryGirl.create(:admin)
        set_current_user(user)
        t = Time.now
        FileCacheMaintainer.reset_file_info('current_stolen_bikes.tsv', t)
        # tsvs = [{ filename: 'current_stolen_bikes.tsv', updated_at: t.to_i.to_s, description: 'Approved Stolen bikes' }]
        blacklist = %w(1010101 2 4 6)
        FileCacheMaintainer.reset_blacklist_ids(blacklist)
        get :tsvs
        expect(response.code).to eq('200')
        # assigns(:tsvs).should eq(tsvs)
        expect(assigns(:blacklist).include?('2')).to be_truthy
      end
    end

    describe 'update_tsv_blacklist' do
      it 'renders and updates' do
        user = FactoryGirl.create(:admin)
        set_current_user(user)
        ids = "\n1\n2\n69\n200\n22222\n\n\n"
        put :update_tsv_blacklist, blacklist: ids
        expect(FileCacheMaintainer.blacklist).to eq([1, 2, 69, 200, 22222].map(&:to_s))
      end
    end
  end
end
