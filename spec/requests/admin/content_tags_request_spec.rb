require "rails_helper"

base_url = "/admin/content_tags"
RSpec.describe Admin::ContentTagsController, type: :request do
  include_context :request_spec_logged_in_as_superuser
  let!(:subject) { FactoryBot.create(:content_tag) }
  let(:valid_params) { {name: "New name", priority: 12, description: "pppp ffff cccccc"} }

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "edit" do
    it "renders" do
      get "#{base_url}/#{subject.to_param}/edit"
      expect(response.status).to eq(200)
      expect(response).to render_template(:edit)
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response.status).to eq(200)
      expect(response).to render_template(:new)
    end
  end

  describe "update" do
    let!(:original_name) { subject.name }
    it "updates available attributes" do
      put "#{base_url}/#{subject.to_param}", params: {content_tag: valid_params}
      expect(flash[:success]).to be_present
      subject.reload
      valid_params.each { |k, v| expect(subject.send(k)).to eq(v) }
    end
  end

  describe "create" do
    it "succeeds" do
      expect {
        post base_url, params: {content_tag: valid_params}
      }.to change(ContentTag, :count).by 1
      content_tag = ContentTag.last
      valid_params.each { |k, v| expect(content_tag.send(k)).to eq(v) }
    end
  end
end
