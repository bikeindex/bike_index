require "rails_helper"

RSpec.describe Admin::PublicImagesController, type: :request do
  let(:base_url) { "/admin/public_images" }

  context "logged_in_as_superuser" do
    include_context :request_spec_logged_in_as_superuser

    let(:blog) { FactoryBot.create(:blog, title: "Some blog post") }
    let!(:bike_image) { FactoryBot.create(:public_image, kind: "photo_of_serial") }
    let!(:blog_image) { FactoryBot.create(:public_image, imageable: blog) }
    let!(:private_image) { FactoryBot.create(:public_image, is_private: true) }

    describe "index" do
      it "renders, including private images" do
        get base_url
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
        expect(assigns(:collection).pluck(:id)).to match_array([bike_image.id, blog_image.id, private_image.id])
        # The imageable name, linked to the imageable's admin page
        expect(response.body).to include("Some blog post")
        expect(response.body).to include(admin_news_path(blog))
      end

      it "renders the chart" do
        get base_url, params: {render_chart: true}
        expect(response.status).to eq(200)
        expect(response).to render_template(:index)
      end

      it "sorts by imageable_type" do
        get base_url, params: {sort: "imageable_type", direction: "asc"}
        expect(response.status).to eq(200)
        expect(assigns(:collection).pluck(:imageable_type)).to eq(%w[Bike Bike Blog])
      end

      context "with search_imageable_type" do
        it "filters" do
          get base_url, params: {search_imageable_type: "Blog"}
          expect(response.status).to eq(200)
          expect(assigns(:collection).pluck(:id)).to eq([blog_image.id])
        end

        it "ignores unknown types" do
          get base_url, params: {search_imageable_type: "User"}
          expect(assigns(:collection).pluck(:id)).to match_array([bike_image.id, blog_image.id, private_image.id])
        end
      end

      context "with search_kind" do
        it "filters" do
          get base_url, params: {search_kind: "photo_of_serial"}
          expect(response.status).to eq(200)
          expect(assigns(:collection).pluck(:id)).to eq([bike_image.id])
        end
      end

      context "with search_private" do
        it "filters to only private images" do
          get base_url, params: {search_private: true}
          expect(response.status).to eq(200)
          expect(assigns(:collection).pluck(:id)).to eq([private_image.id])
        end
      end
    end
  end

  context "logged_in_as_user" do
    include_context :request_spec_logged_in_as_user

    it "blocks non-superusers" do
      get base_url
      expect(response).to_not render_template(:index)
    end
  end
end
