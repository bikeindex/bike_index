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

  describe 'new' do
    it 'renders' do
      get :new
      expect(response.code).to eq('200')
      expect(response).to render_template('new')
    end
  end

  describe 'edit' do
    context 'not lock owner' do
      it 'redirects to user_home' do
        lock = FactoryGirl.create(:lock)
        get :edit, id: lock.id

        # changed get from :show to :edit, correct?

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

  describe 'create' do
    include_context :logged_in_as_user
    let(:manufacturer) { FactoryGirl.create(:manufacturer) }
    let(:lock_type) { FactoryGirl.create(:lock_type) }
    let(:lock) { FactoryGirl.create(:lock) } # needed?
    context 'success' do
      it 'redirects you to user_home locks table' do
        lock_params = {
          lock_type_id: lock_type.id,
          manufacturer_id: manufacturer.id,
          manufacturer_other: '',
          has_key: '1',
          has_combination: '0',
          key_serial: '321',
          combination: ''
        }
        pp lock_type.id
        pp '**'
        post :create, lock: lock_params
        user.reload
        lock = user.locks.first
        expect(response).to redirect_to user_home_path(active_tab: 'locks')
        expect(user.locks.count).to eq 1
        expect(lock.key_serial).to eq lock_params[:key_serial]
      end
    end
  end
end
