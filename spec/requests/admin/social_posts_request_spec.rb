require "rails_helper"

RSpec.describe Admin::SocialPostsController, type: :request do
  let(:subject) { FactoryBot.create(:social_post, kind: "app_post", platform_id: "fake-id-to-skip-validations") }
  let(:base_url) { "/admin/social_posts/" }
  include_context :request_spec_logged_in_as_superuser

  describe "index" do
    it "renders" do
      get base_url
      expect(response).to be_ok
      expect(response).to render_template(:index)
      expect(flash).to be_blank
    end
  end

  describe "show" do
    it "renders" do
      get "#{base_url}/#{subject.platform_id}"
      expect(response).to be_ok
      expect(response).to render_template(:show)
      expect(flash).to be_blank
      expect(assigns(:social_post)).to eq subject
    end
    context "imported_post" do
      let(:subject) { FactoryBot.create(:social_post, kind: "imported_post") }
      it "redirects to edit" do
        subject.reload
        expect(subject.kind).to eq "imported_post"
        get "#{base_url}/#{subject.id}"
        expect(assigns(:social_post)).to eq subject
        expect(response).to redirect_to edit_admin_social_post_path(subject.id)
      end
    end
  end

  describe "edit" do
    it "redirects" do
      subject.reload
      expect(subject.kind).to eq "app_post"
      get "#{base_url}/#{subject.id}/edit"
      expect(response).to redirect_to admin_social_post_path(subject.id)
    end
    context "imported_post" do
      let(:subject) { FactoryBot.create(:social_post, kind: "imported_post") }
      it "renders" do
        get "#{base_url}/#{subject.id}/edit"
        expect(response).to be_ok
        expect(response).to render_template(:edit)
        expect(flash).to be_blank
      end
    end
  end

  describe "new" do
    it "renders" do
      get "#{base_url}/new"
      expect(response).to be_ok
      expect(response).to render_template(:new)
      expect(flash).to be_blank
    end
  end

  describe "create" do
    # it "tweets" do
    #   # TODO: Actually test
    # end
    # context "imported_post" do
    #   it "gets the tweet from twitter" do
    #     # TODO: Actually test
    #   end
    # end
  end

  describe "#destroy" do
    context "given a successful deletion" do
      it "deletes the tweet, redirects to tweet index url with an appropriate flash" do
        post = FactoryBot.create(:social_post)

        delete "#{base_url}/#{post.id}"

        expect(response).to redirect_to(admin_social_posts_url)
        expect(flash[:error]).to be_blank
        expect(flash[:info]).to match("deleted")
      end
    end

    context "given a failed deletion" do
      it "redirects to post edit url with an appropriate flash" do
        post = FactoryBot.create(:social_post)
        allow(post).to receive(:destroy).and_return(false)
        allow(SocialPost).to receive(:friendly_find).with(post.id.to_s).and_return(post)

        delete "#{base_url}/#{post.id}"

        expect(response).to redirect_to(edit_admin_social_post_url)
        expect(flash[:info]).to be_blank
        expect(flash[:error]).to match("Could not delete")
      end
    end
  end
end
