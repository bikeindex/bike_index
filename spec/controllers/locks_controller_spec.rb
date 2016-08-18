require 'spec_helper'

describe LocksController do
  include_context :logged_in_as_user
  before do
    # We have to create all the lock types.... Could be improved ;)
    ['U-lock', 'Chain with lock', 'Cable', 'Locking skewer', 'Other style'].each do |name|
      LockType.create(name: name)
    end
  end
  let(:manufacturer) { FactoryGirl.create(:manufacturer) }
  let(:lock) { FactoryGirl.create(:lock) }
  let(:owner_lock) { FactoryGirl.create(:lock, user: user) }
  let(:lock_type) { LockType.last }
  let(:valid_attributes) do
    {
      lock_type_id: lock_type.id,
      manufacturer_id: manufacturer.id,
      manufacturer_other: '',
      has_key: true,
      has_combination: false,
      key_serial: '321',
      combination: ''
    }
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
        get :edit, id: lock.id
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(:user_home)
      end
    end
    context 'lock owner' do
      it 'renders' do
        get :edit, id: owner_lock.id
        expect(response.code).to eq('200')
        expect(response).to render_template('edit')
      end
    end
  end

  describe 'update' do
    context 'not lock owner' do
      it 'redirects to user_home' do
        put :update, id: lock.id, combination: '123'
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(:user_home)
        expect(lock.combination).to_not eq('123')
      end
    end
    context 'lock owner' do
      it 'renders' do
        put :update, id: owner_lock.id, lock: valid_attributes
        owner_lock.reload
        expect(response.code).to eq('200')
        expect(response).to render_template('edit')
        valid_attributes.each do |key, value|
          pp key unless owner_lock.send(key) == value
          expect(owner_lock.send(key)).to eq value
        end
      end
    end
  end

  describe 'create' do
    context 'success' do
      it 'redirects you to user_home locks table' do
        post :create, lock: valid_attributes
        user.reload
        lock = user.locks.first
        expect(response).to redirect_to user_home_path(active_tab: 'locks')
        valid_attributes.each do |key, value|
          pp key unless lock.send(key) == value
          expect(lock.send(key)).to eq value
        end
      end
    end
  end

  describe 'destroy' do
    context 'not lock owner' do
      it 'redirects to user_home' do
        expect(lock).to be_present
        delete :destroy, id: lock.id
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(:user_home)
        expect(lock.reload).to be_truthy
      end
    end
    context 'lock owner' do
      it 'renders' do
        expect(owner_lock).to be_present
        expect do
          delete :destroy, id: owner_lock.id
        end.to change(Lock, :count).by(-1)
        expect(response).to redirect_to user_home_path(active_tab: 'locks')
      end
    end
  end
end
