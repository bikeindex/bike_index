require "rails_helper"

RSpec.describe PublicImagesController, type: :request do
  include_context :request_spec_logged_in_as_user_if_present
  let(:base_url) { "/public_images" }

  describe "create" do
    let(:current_user) { FactoryBot.create(:admin) }
    context "bike" do
      let(:ownership) { FactoryBot.create(:ownership) }
      let(:bike) { ownership.bike }
      let!(:current_user) { ownership.creator }
      context "valid owner" do
        it "creates an image" do
          bike.update_column :updated_at, Time.current - 1.hour
          Sidekiq::Worker.clear_all
          post base_url, params: {bike_id: bike.id, public_image: {name: "cool name"}, format: :js}
          expect(AfterBikeSaveWorker.jobs.count).to eq 1
          AfterBikeSaveWorker.drain
          expect(bike.reload.updated_at).to be_within(1).of Time.current
          expect(bike.public_images.first.name).to eq "cool name"
        end
        context "user hidden" do
          it "creates an image" do
            bike.update(marked_user_hidden: true)
            bike.update_column :updated_at, Time.current - 1.hour
            expect(bike.reload.user_hidden).to be_truthy
            expect(bike.thumb_path).to be_blank
            Sidekiq::Worker.clear_all
            post base_url, params: {bike_id: bike.id, public_image: {name: "cool name"}, format: :js}
            expect(AfterBikeSaveWorker.jobs.count).to eq 1
            AfterBikeSaveWorker.drain
            expect(bike.reload.updated_at).to be_within(1).of Time.current
            expect(bike.public_images.first.name).to eq "cool name"
          end
        end
      end
      context "org authorized" do
        let(:current_organization) { FactoryBot.create(:organization) }
        let!(:current_user) { FactoryBot.create(:organization_user, organization: current_organization) }
        let(:bike) { FactoryBot.create(:bike_organized, :with_ownership_claimed, creation_organization: current_organization) }
        it "creates an image" do
          bike.reload
          expect(bike.can_edit_claimed_organizations.pluck(:id)).to eq([current_organization.id])
          expect(bike.authorized?(current_user)).to be_truthy
          Sidekiq::Worker.clear_all
          expect {
            post base_url, params: {bike_id: bike.id, public_image: {name: "cool name"}, format: :js}
          }.to change(PublicImage, :count).by 1
          bike.reload
          expect(bike.public_images.first.name).to eq "cool name"
          expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id, false, true)
        end
      end
      context "no user" do
        let(:current_user) { nil }
        it "does not create an image" do
          expect {
            post base_url, params: {bike_id: bike.id, public_image: {name: "cool name"}, format: :js}
            expect(response.code).to eq("401")
          }.to change(PublicImage, :count).by 0
        end
      end
    end
    context "bike_version" do
      let(:bike_version) { FactoryBot.create(:bike_version, owner: current_user) }
      context "valid owner" do
        it "creates an image" do
          bike_version.update_column :updated_at, Time.current - 1.hour
          Sidekiq::Worker.clear_all
          post base_url, params: {bike_id: bike_version.id, imageable_type: "BikeVersion",
                                  public_image: {name: "cool name"}, format: :js}
          expect(AfterBikeSaveWorker.jobs.count).to eq 0
          expect(bike_version.reload.updated_at).to be_within(1).of Time.current
          expect(bike_version.public_images.first.name).to eq "cool name"
        end
        context "user hidden" do
          it "creates an image" do
            bike_version.update(visibility: "user_hidden")
            expect(bike_version.thumb_path).to be_blank
            Sidekiq::Worker.clear_all
            post base_url, params: {bike_id: bike_version.id, imageable_type: "BikeVersion",
                                    public_image: {name: "cool name"}, format: :js}
            expect(AfterBikeSaveWorker.jobs.count).to eq 0
            expect(bike_version.reload.updated_at).to be_within(1).of Time.current
            expect(bike_version.public_images.first.name).to eq "cool name"
            expect(bike_version.public_images.first.is_private).to be_falsey
          end
        end
      end
    end
    context "blog" do
      let(:blog) { FactoryBot.create(:blog) }
      let(:file) { Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, "/spec/fixtures/bike.jpg"))) }
      context "admin authorized" do
        it "creates an image" do
          post base_url, params: {blog_id: blog.id, public_image: {name: "cool name", image: file}, format: :js}
          expect(JSON.parse(response.body)).to be_present
          blog.reload
          expect(blog.public_images.first.name).to eq "cool name"
        end
        context "sent from uppy" do
          it "creates an image" do
            post base_url, params: {blog_id: blog.id, upload_plugin: "uppy", name: "cool name", image: file, format: :js}
            public_image = PublicImage.last
            expect(JSON.parse(response.body)).to be_present
            blog.reload
            expect(blog.public_images).not_to be_empty
            expect(blog.public_images.first.name).to eq "cool name"
            expect(public_image.imageable).to eq(blog)
          end
        end
        context "blog_id not given" do
          it "creates an image" do
            expect {
              post base_url, params: {blog_id: "", public_image: {name: "cool name", image: file}, format: :js}
            }.to change(PublicImage, :count).by 1
            expect(JSON.parse(response.body)).to be_present
          end
        end
      end
      context "not admin" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "does not create an image" do
          expect {
            post base_url, params: {blog_id: blog.id, public_image: {name: "cool name", image: file}, format: :js}
            expect(response.code).to eq("401")
          }.to change(PublicImage, :count).by 0
        end
      end
    end
    context "organization" do
      let(:current_organization) { FactoryBot.create(:organization) }
      context "admin authorized" do
        it "creates an image" do
          post base_url, params: {organization_id: current_organization.to_param, public_image: {name: "cool name"}, format: :js}
          current_organization.reload
          expect(current_organization.public_images.first.name).to eq "cool name"
        end
      end
      context "not admin" do
        let(:current_user) { FactoryBot.create(:organization_admin, organization: current_organization) }
        it "does not create an image" do
          expect {
            post base_url, params: {organization_id: current_organization.to_param, public_image: {name: "cool name"}, format: :js}
            expect(response.code).to eq("401")
          }.to change(PublicImage, :count).by 0
        end
      end
    end
    context "mail_snippet" do
      let(:mail_snippet) { FactoryBot.create(:mail_snippet) }
      let(:file) { Rack::Test::UploadedFile.new(File.open(File.join(Rails.root, "/spec/fixtures/bike.jpg"))) }
      context "admin authorized" do
        it "creates an image" do
          post base_url, params: {mail_snippet_id: mail_snippet.to_param, public_image: {name: "cool name", image: file}, format: :js}
          mail_snippet.reload
          expect(mail_snippet.public_images.first.name).to eq "cool name"
        end
        context "sent from uppy" do
          it "creates an image" do
            post base_url, params: {mail_snippet_id: mail_snippet.id, upload_plugin: "uppy", name: "cool name", image: file, format: :js}
            public_image = PublicImage.last
            expect(JSON.parse(response.body)).to be_present
            mail_snippet.reload
            expect(mail_snippet.public_images).not_to be_empty
            expect(mail_snippet.public_images.first.name).to eq "cool name"
            expect(public_image.imageable).to eq(mail_snippet)
          end
        end
      end
      context "not admin" do
        let(:current_user) { FactoryBot.create(:user_confirmed) }
        it "does not create an image" do
          expect {
            post base_url, params: {organization_id: mail_snippet.to_param, public_image: {name: "cool name"}, format: :js}
            expect(response.code).to eq("401")
          }.to change(PublicImage, :count).by 0
        end
      end
    end
  end

  describe "destroy" do
    let(:mail_snippet) { FactoryBot.create(:mail_snippet) }
    context "mail_snippet" do
      it "rejects the destroy" do
        public_image = FactoryBot.create(:public_image,
          imageable_type: "MailSnippet",
          imageable: mail_snippet)
        public_image.reload
        expect {
          delete "#{base_url}/#{public_image.id}"
        }.not_to change(PublicImage, :count)
        expect(flash).to be_present
      end
    end
    describe "bike" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }
      it "allows the destroy of public_image" do
        bike = FactoryBot.create(:bike, :with_ownership_claimed, user: current_user)
        public_image = FactoryBot.create(:public_image, imageable: bike)
        bike.reload
        expect(bike.authorized?(current_user)).to be_truthy
        expect {
          delete "#{base_url}/#{public_image.id}"
        }.to change(PublicImage, :count).by(-1)
      end
      context "owner and hidden bike" do
        it "allows the destroy" do
          bike.update(marked_user_hidden: true)
          expect(bike.reload.user_hidden?).to be_truthy
          expect(bike.authorized?(current_user)).to be_truthy
          expect {
            delete "#{base_url}/#{public_image.id}?edit_template=redirect_page"
          }.to change(PublicImage, :count).by(-1)
          expect(response).to redirect_to(edit_bike_path(bike, edit_template: "redirect_page"))
        end
      end
      context "non owner" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
        it "rejects the destroy" do
          expect(bike.authorized?(current_user)).to be_falsey
          expect {
            delete "#{base_url}/#{public_image.id}"
          }.not_to change(PublicImage, :count)
        end
      end
    end
    describe "bike_version" do
      let(:current_user) { FactoryBot.create(:user_confirmed) }
      let(:bike_version) { FactoryBot.create(:bike_version, owner: current_user) }
      let!(:public_image) { FactoryBot.create(:public_image, imageable: bike_version) }
      context "with owner" do
        it "allows the destroy of public_image" do
          expect(bike_version.reload.authorized?(current_user)).to be_truthy
          expect {
            delete "#{base_url}/#{public_image.id}"
          }.to change(PublicImage, :count).by(-1)
          expect(response).to redirect_to(edit_bike_version_path(bike_version))
        end
        context "owner and hidden bike" do
          it "allows the destroy" do
            bike_version.update(visibility: "user_hidden")
            expect(bike_version.reload.authorized?(current_user)).to be_truthy
            expect {
              delete "#{base_url}/#{public_image.id}?edit_template=redirect_page&imageable_type=BikeVersion"
            }.to change(PublicImage, :count).by(-1)
            expect(response).to redirect_to(edit_bike_version_path(bike_version, edit_template: "redirect_page"))
          end
        end
      end
      context "non owner" do
        let(:bike_version) { FactoryBot.create(:bike_version) }
        it "rejects the destroy" do
          expect(bike_version.reload.authorized?(current_user)).to be_falsey
          expect {
            delete "#{base_url}/#{public_image.id}"
          }.not_to change(PublicImage, :count)
        end
      end
    end
  end

  describe "show" do
    let(:user) { nil }
    it "renders" do
      public_image = FactoryBot.create(:public_image)
      get "#{base_url}/#{public_image.id}"
      expect(response.code).to eq("200")
      expect(response).to render_template("show")
      expect(flash).to_not be_present
    end
    context "private" do
      let(:public_image) { FactoryBot.create(:public_image, is_private: true) }
      it "redirects" do
        get "#{base_url}/#{public_image.id}"
        expect(response.status).to eq 404
      end
    end
  end

  context "with bike" do
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed, user: current_user) }
    let!(:public_image) { FactoryBot.create(:public_image, imageable: bike) }

    describe "edit" do
      it "renders" do
        expect(bike.authorized?(current_user)).to be_truthy
        get "#{base_url}/#{public_image.id}/edit"
        expect(response.code).to eq("200")
        expect(response).to render_template("edit")
        expect(flash).to_not be_present
      end
      context "not owner" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
        it "redirects" do
          expect(bike.authorized?(current_user)).to be_falsey
          get "#{base_url}/#{public_image.id}/edit"
          expect(response).to redirect_to bike_path(bike)
        end
      end
    end

    describe "update" do
      it "updates things and go back to editing the bike" do
        expect(bike.reload.owner).to eq(current_user)
        expect {
          put "#{base_url}/#{public_image.id}", params: {public_image: {name: "Food"}}
        }.to change(AfterBikeSaveWorker.jobs, :count).by(1)
        expect(response).to redirect_to(edit_bike_url(bike))
        expect(public_image.reload.name).to eq("Food")
      end
      context "not owner" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
        it "does not update" do
          og_name = public_image.name
          expect(bike.authorized?(current_user)).to be_falsey
          expect {
            put "#{base_url}/#{public_image.id}", params: {public_image: {name: "Food"}}
          }.to change(AfterBikeSaveWorker.jobs, :count).by(0)
          expect(public_image.reload.name).to eq(og_name)
        end
      end
      context "kind" do
        it "updates" do
          expect(public_image.kind).to eq "photo_uncategorized"
          expect {
            patch "#{base_url}/#{public_image.id}", params: {kind: "photo_of_user_with_bike"}
          }.to change(AfterBikeSaveWorker.jobs, :count).by(1)
          expect(public_image.reload.kind).to eq("photo_of_user_with_bike")
          # And changing from a non-default kind
          put "#{base_url}/#{public_image.id}", params: {kind: "photo_of_serial"}
          expect(public_image.reload.kind).to eq("photo_of_serial")
        end
      end
    end

    describe "is_private" do
      # This is a legacy endpoint. Should be moved into update, but I'm not sure if there are other places where it's used
      # ... and it's currently working, so leaving it 2020-12
      context "is_private true" do
        it "marks image private" do
          expect(bike.reload.owner).to eq(current_user)
          Sidekiq::Worker.clear_all
          post "#{base_url}/#{public_image.id}/is_private", params: {is_private: "true"}
          public_image.reload
          expect(public_image.is_private).to be_truthy
          expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id, false, true)
        end
      end
      context "is_private false" do
        let(:public_image) { FactoryBot.create(:public_image, imageable: bike, is_private: true) }
        it "marks bike not private" do
          expect(bike.reload.owner).to eq(current_user)
          Sidekiq::Worker.clear_all
          post "#{base_url}/#{public_image.id}/is_private", params: {is_private: false}
          public_image.reload
          expect(public_image.is_private).to be_falsey
          expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id, false, true)
        end
      end
      context "non owner" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
        it "does not update" do
          post "#{base_url}/#{public_image.id}/is_private", params: {is_private: "true"}
          expect(public_image.is_private).to be_falsey
        end
      end
    end

    describe "order" do
      let(:other_ownership) { FactoryBot.create(:ownership) }
      let(:public_image_1) { FactoryBot.create(:public_image, imageable: bike) }
      let(:public_image_2) { FactoryBot.create(:public_image, imageable: bike, listing_order: 2) }
      let(:public_image_3) { FactoryBot.create(:public_image, imageable: bike, listing_order: 3) }
      let(:public_image_other) { FactoryBot.create(:public_image, imageable: other_ownership.bike, listing_order: 0) }

      it "updates the listing order" do
        expect([public_image_1, public_image_2, public_image_3, public_image_other]).to be_present
        expect(public_image_other.listing_order).to eq 0
        expect(public_image_3.listing_order).to eq 3
        expect(public_image_2.listing_order).to eq 2
        expect(public_image_1.listing_order).to be < 2
        list_order = [public_image_3.id, public_image_1.id, public_image_other.id, public_image_2.id]
        Sidekiq::Worker.clear_all
        post "#{base_url}/order", params: {list_of_photos: list_order.map(&:to_s)}

        expect(public_image_3.reload.listing_order).to eq 1
        expect(public_image_2.reload.listing_order).to eq 4
        expect(public_image_1.reload.listing_order).to eq 2
        expect(public_image_other.reload.listing_order).to eq 0
        expect(AfterBikeSaveWorker).to have_enqueued_sidekiq_job(bike.id, false, true)
      end
    end
  end
end
