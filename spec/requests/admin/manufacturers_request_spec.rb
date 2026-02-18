require "rails_helper"

RSpec.describe Admin::ManufacturersController, type: :request do
  let(:base_url) { "/admin/manufacturers/" }
  let(:subject) { FactoryBot.create(:manufacturer) }
  include_context :request_spec_logged_in_as_superuser

  let(:permitted_attributes) do
    {
      name: "new name and things",
      slug: "new_name_and_things",
      website: "http://stuff.com",
      frame_maker: true,
      open_year: 1992,
      close_year: 89898,
      description: "new description",
      twitter_name: "cool-name",
      motorized_only: true
    }
  end

  describe "index" do
    it "renders" do
      get base_url
      expect(response.status).to eq(200)
      expect(response).to render_template(:index)
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{subject.slug}"
      expect(response.status).to eq(200)
      expect(response).to render_template(:show)
    end
  end

  describe "edit" do
    context "slug" do
      it "renders" do
        get "#{base_url}/#{subject.slug}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
    context "id" do
      it "renders" do
        get "#{base_url}/#{subject.id}/edit"
        expect(response.status).to eq(200)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe "update" do
    it "updates available attributes" do
      put "#{base_url}/#{subject.to_param}", params: {manufacturer: permitted_attributes}
      expect(flash[:success]).to be_present
      expect(subject.reload).to have_attributes permitted_attributes
    end
  end

  describe "create" do
    it "creates with available attributes" do
      expect(Manufacturer.where(name: "new name and things").count).to eq 0
      expect {
        post base_url, params: {manufacturer: permitted_attributes}
      }.to change(Manufacturer, :count).by 1
      new_manufacturer = Manufacturer.where(name: "new name and things").first
      expect(flash[:success]).to be_present
      expect(new_manufacturer).to have_attributes permitted_attributes
      # permitted_attributes.each { |attribute, val| expect(target.send(attribute)).to eq val }
    end
  end
end
