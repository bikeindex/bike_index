require "spec_helper"

describe Admin::PaidFeaturesController, type: :controller do
  let(:subject) { FactoryGirl.create(:paid_feature) }
  include_context :logged_in_as_super_admin
  let(:passed_params) { { amount: 222.22, description: "Some really long description or wahtttt", details_link: "https://example.com" } }
  let(:full_params) { passed_params.merge(kind: "custom_one_time", name: "another name stuff") }

  describe "index" do
    it "renders" do
      get :index
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      get :edit, id: subject.to_param
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "new" do
    it "renders" do
      get :new
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end

  describe "update" do
    let!(:original_name) { subject.name }
    let!(:original_kind) { subject.kind }
    it "updates available attributes" do
      put :update, id: subject.to_param, paid_feature: full_params
      expect(flash[:success]).to be_present
      subject.reload
      full_params.each { |k, v| expect(subject.send(k)).to eq(v) }
    end
    context "locked paid_feature" do
      let(:subject) { FactoryGirl.create(:paid_feature, is_locked: true) }
      it "does not update locked attributes" do
        put :update, id: subject.to_param, paid_feature: full_params
        subject.reload
        passed_params.each { |k, v| expect(subject.send(k)).to eq(v) }
        expect(subject.name).to eq original_name
        expect(subject.kind).to eq original_kind
      end
    end
  end

  describe "create" do
    it "succeeds" do
      expect do
        post :create, paid_feature: full_params
      end.to change(PaidFeature, :count).by 1
      paid_feature = PaidFeature.last
      full_params.each { |k, v| expect(paid_feature.send(k)).to eq(v) }
    end
  end
end
