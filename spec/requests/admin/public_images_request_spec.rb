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

      context "with an attached file" do
        let!(:attached_image) { FactoryBot.create(:public_image, :with_attached_file) }

        it "marks it as activestorage and renders its thumbnail" do
          get base_url
          expect(assigns(:collection).pluck(:id)).to include(attached_image.id)
          expect(response.body).to include("ActiveStorage (instead of legacy carrierwave)")
          # image? is carrierwave-only, so the cell has to key off image_url
          expect(attached_image.reload.image?).to be_falsey
          expect(response.body).to include(attached_image.image_url)
          expect(response.body).to include(attached_image.image_url(:small))
        end

        it "sizes it off the blob when search_size is on" do
          get base_url, params: {search_size: true}
          expect(response.status).to eq(200)
          expect(attached_image.reload.image_size).to eq attached_image.file.blob.byte_size
          expect(response.body).to include(ActiveSupport::NumberHelper.number_to_human_size(attached_image.image_size))
        end

        it "filters to only activestorage" do
          get base_url, params: {search_storage: "activestorage"}
          expect(response.status).to eq(200)
          expect(assigns(:collection).pluck(:id)).to eq([attached_image.id])
        end

        it "filters to only carrierwave" do
          get base_url, params: {search_storage: "carrierwave"}
          expect(response.status).to eq(200)
          expect(assigns(:collection).pluck(:id)).to match_array([bike_image.id, blog_image.id, private_image.id])
        end

        it "ignores an unknown storage and charts the filtered scope" do
          get base_url, params: {search_storage: "sqlite", render_chart: true}
          expect(response.status).to eq(200)
          expect(assigns(:collection).pluck(:id)).to include(attached_image.id)
        end
      end

      it "omits the size column unless search_size is on" do
        sized = FactoryBot.create(:public_image, :with_image_file)
        expect(sized.image_size).to be > 0

        get base_url
        expect(response.body).to_not match(/<th>\s*Size\s*<\/th>/)

        get base_url, params: {search_size: true}
        expect(response.body).to match(/<th>\s*Size\s*<\/th>/)
        expect(response.body).to include(ActiveSupport::NumberHelper.number_to_human_size(sized.image_size))
      end

      # Sizing a carrierwave image costs a fog request, so the hidden column mustn't resolve it
      it "doesn't ask for sizes when the column is hidden" do
        expect_any_instance_of(PublicImage).to_not receive(:image_size)
        get base_url
        expect(response.status).to eq(200)
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
