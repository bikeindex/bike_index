# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Admin::PublicImages::Uploader::Component, type: :component do
  let(:component) { render_inline(described_class.new(imageable:, list_class: "row")) }
  let!(:public_image) { FactoryBot.create(:public_image, imageable:) }

  context "with a blog" do
    let(:imageable) { FactoryBot.create(:blog) }

    it "names the param PublicImagesController#create finds the blog back by" do
      expect(component).to have_css("[data-ui--forms--file-upload-multi-params-value='{\"blog_id\":#{imageable.id}}']")
      expect(component).to have_css("ul#public_images.row li#image-#{public_image.id}")
    end
  end

  context "with a mail snippet" do
    let(:imageable) { FactoryBot.create(:mail_snippet) }

    it "names the mail_snippet param" do
      expect(component).to have_css("[data-ui--forms--file-upload-multi-params-value='{\"mail_snippet_id\":#{imageable.id}}']")
    end
  end

  # Found by slug rather than id, unlike the others
  context "with an organization" do
    let(:imageable) { FactoryBot.create(:organization) }

    it "names the organization param, carrying the slug" do
      expect(component).to have_css("[data-ui--forms--file-upload-multi-params-value='{\"organization_id\":\"#{imageable.to_param}\"}']")
    end
  end

  context "with an imageable that has no admin page" do
    let(:imageable) { FactoryBot.create(:bike) }

    it "raises rather than uploading something the endpoint can't place" do
      expect { component }.to raise_error(/no public_images param/)
    end
  end
end
