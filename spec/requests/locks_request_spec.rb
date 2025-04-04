require "rails_helper"

base_url = "/locks"
RSpec.describe LocksController, type: :request do
  include_context :request_spec_logged_in_as_user
  before do
    # We have to create all the lock types.... Could be improved ;)
    ["U-lock", "Chain with lock", "Cable", "Locking skewer", "Other style", "Battery or e-bike key"].each do |name|
      LockType.create(name: name)
    end
  end
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:lock) { FactoryBot.create(:lock) }
  let(:owner_lock) { FactoryBot.create(:lock, user: current_user) }
  let(:lock_type) { LockType.last }
  let(:valid_attributes) do
    {
      lock_type_id: lock_type.id,
      manufacturer_id: manufacturer.id,
      manufacturer_other: "",
      has_key: true,
      has_combination: false,
      key_serial: "321",
      combination: ""
    }
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response.code).to eq("200")
      expect(response).to render_template("new")
    end
  end

  describe "edit" do
    context "not lock owner" do
      it "redirects to my_account" do
        get "#{base_url}/#{lock.id}/edit"
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(:my_account)
      end
    end
    context "lock owner" do
      it "renders" do
        get "#{base_url}/#{owner_lock.id}/edit"
        expect(response.code).to eq("200")
        expect(response).to render_template("edit")
      end
    end
    context "no user" do
      let(:current_user) { false }
      it "redirects to sign_in" do
        get "#{base_url}/#{lock.id}/edit"
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(new_session_path)
      end
      context "unauthenticated_redirect" do
        it "redirects to sign up" do
          get "#{base_url}/#{lock.id}/edit", params: {unauthenticated_redirect: "sign_up"}
          expect(flash).to be_blank
          expect(response).to redirect_to(new_user_path)
        end
      end
    end
  end

  describe "update" do
    context "not lock owner" do
      it "redirects to my_account" do
        put "#{base_url}/#{lock.id}", params: {combination: "123"}
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(:my_account)
        expect(lock.combination).to_not eq("123")
      end
    end
    context "lock owner" do
      it "renders" do
        put "#{base_url}/#{owner_lock.id}", params: {lock: valid_attributes}
        owner_lock.reload
        expect(response.code).to eq("200")
        expect(response).to render_template("edit")
        valid_attributes.each do |key, value|
          pp key unless owner_lock.send(key) == value
          expect(owner_lock.send(key)).to eq value
        end
      end
    end
  end

  describe "create" do
    context "success" do
      it "redirects you to my_account locks table" do
        post base_url, params: {lock: valid_attributes}
        current_user.reload
        lock = current_user.locks.first
        expect(response).to redirect_to my_account_path(active_tab: "locks")
        valid_attributes.each do |key, value|
          pp key unless lock.send(key) == value
          expect(lock.send(key)).to eq value
        end
      end
    end
  end

  describe "destroy" do
    context "not lock owner" do
      it "redirects to my_account" do
        expect(lock).to be_present
        delete "#{base_url}/#{lock.id}"
        expect(flash[:error]).to be_present
        expect(response).to redirect_to(:my_account)
        expect(lock.reload).to be_truthy
      end
    end
    context "lock owner" do
      it "renders" do
        expect(owner_lock).to be_present
        expect {
          delete "#{base_url}/#{owner_lock.id}"
        }.to change(Lock, :count).by(-1)
        expect(response).to redirect_to my_account_path(active_tab: "locks")
      end
    end
  end
end
