require 'spec_helper'

describe LocksController do
  let(:user) { FactoryGirl.create(:user) }
  before do
    set_current_user(user)
    # We have to create all the lock types.... Could be improved ;)
    ['U-lock', 'Chain with lock', 'Cable', 'Locking skewer', 'Other style'].each do |name|
      LockType.create(name: name)
    end
  end

  describe :index do
    it 'renders' do
      get :index
      expect(response.code).to eq('200')
      expect(response).to render_template('index')
      expect(assigns(:locks)).to be_decorated
    end
  end

  describe :show do
    it 'renders' do
      lock = FactoryGirl.create(:lock, user: user)
      get :show, id: lock.id
      expect(response.code).to eq('200')
      expect(response).to render_template('show')
      expect(assigns(:lock)).to be_decorated
    end
  end

  describe :new do
    it 'renders' do
      get :new
      expect(response.code).to eq('200')
      expect(response).to render_template('new')
    end
  end

  describe :edit do
    context 'not lock owner' do
      it 'redirects to user_home' do
        lock = FactoryGirl.create(:lock)
        get :show, id: lock.id
        expect(response).to redirect_to(:user_home)
      end
    end
    context 'lock owner' do
      it 'renders' do
        lock = FactoryGirl.create(:lock, user: user)
        get :edit, id: lock.id
        expect(response.code).to eq('200')
        expect(response).to render_template('edit')
      end
    end
  end
end
