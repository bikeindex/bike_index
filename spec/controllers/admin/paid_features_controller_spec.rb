require "spec_helper"

describe Admin::PaidFeaturesController, type: :controller do
  let(:subject) { FactoryBot.create(:paid_feature) }
  include_context :logged_in_as_super_admin
  let(:passed_params) { { amount: 222.22, description: "Some really long description or wahtttt", details_link: "https://example.com", kind: "custom_one_time", name: "another name stuff" } }

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
      put :update, id: subject.to_param, paid_feature: passed_params
      expect(flash[:success]).to be_present
      subject.reload
      passed_params.each { |k, v| expect(subject.send(k)).to eq(v) }
    end
    context "feature_slugs" do
      let(:subject) { FactoryBot.create(:paid_feature) }
      it "does not update feature_slugs" do
        put :update, id: subject.to_param, paid_feature: passed_params.merge(feature_slugs_string: "csv_exports")
        subject.reload
        passed_params.each { |k, v| expect(subject.send(k)).to eq(v) }
        expect(subject.feature_slugs).to eq([])
      end
      context "developer" do
        let(:user) { FactoryBot.create(:admin_developer) }
        it "does not update feature_slugs" do
          put :update, id: subject.to_param, paid_feature: passed_params.merge(feature_slugs_string: "csv_exports, MessagES,geolocated_messages, blarg")
          subject.reload
          passed_params.each { |k, v| expect(subject.send(k)).to eq(v) }
          expect(subject.feature_slugs).to eq(%w[csv_exports messages geolocated_messages])
        end
      end
    end
    context "locked" do
      before { allow_any_instance_of(PaidFeature).to receive(:locked?) { true } }
      it "does not update" do
        put :update, id: subject.to_param, paid_feature: passed_params.merge(feature_slugs_string: "csv_exports")
        expect(flash[:error]).to be_present
        subject.reload
        passed_params.each { |k, v| expect(subject.send(k)).to_not eq(v) }
      end
      context "developer" do
        let(:user) { FactoryBot.create(:admin_developer) }
        it "does not update feature_slugs" do
          put :update, id: subject.to_param, paid_feature: passed_params.merge(feature_slugs_string: "csv_exports, MessagES,geolocated_messages, blarg")
          subject.reload
          passed_params.each { |k, v| expect(subject.send(k)).to eq(v) }
          expect(subject.feature_slugs).to eq(%w[csv_exports messages geolocated_messages])
        end
      end
    end
  end

  describe "create" do
    it "succeeds" do
      expect do
        post :create, paid_feature: passed_params.merge(feature_slugs_string: "csv_exports, show_bulk_import")
      end.to change(PaidFeature, :count).by 1
      paid_feature = PaidFeature.last
      passed_params.each { |k, v| expect(paid_feature.send(k)).to eq(v) }
      expect(paid_feature.feature_slugs).to eq([])
    end
    context "developer" do
      let(:user) { FactoryBot.create(:admin_developer) }
      it "succeeds" do
        expect do
          post :create, paid_feature: passed_params.merge(feature_slugs_string: "csv_exports, show_bulk_import")
        end.to change(PaidFeature, :count).by 1
        paid_feature = PaidFeature.last
        passed_params.each { |k, v| expect(paid_feature.send(k)).to eq(v) }
        expect(paid_feature.feature_slugs).to eq %w[csv_exports show_bulk_import]
      end
    end
  end
end
