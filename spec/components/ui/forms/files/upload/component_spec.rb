# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Files::Upload::Component, type: :component do
  let(:record) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, record, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, **options)) }
  let(:attribute) { :avatar }
  let(:options) { {} }

  it "renders the builder's field, labelled, and an empty preview" do
    expect(component).to have_css("input#user_avatar[type='file'][name='user[avatar]']")
    expect(component).to have_css("label[for='user_avatar']", text: "Upload")
    # nothing attached, so the preview ships hidden and srcless, waiting for a pick
    # hidden! because collapse() hides with the important variant, and tw:block is on the same element
    expect(component).to have_css("a[data-ui--forms--files--upload-target='preview'].tw\\:hidden\\! img")
    expect(component).to have_no_css("[data-ui--forms--files--upload-target='preview'][href]")
    expect(component).to have_no_css("img[src]")
  end

  # A bare input tag renders the same, but leaves the form url-encoded - so the file never posts
  it "renders through the form builder, which makes the form multipart" do
    component

    expect(form_builder.multipart).to be true
  end

  context "with html_options" do
    let(:options) { {html_options: {accept: "image/png", multiple: true}} }

    it "passes options through to the input" do
      expect(component).to have_css("input[type='file'][accept='image/png']")
      expect(component).to have_css("input[multiple]")
    end
  end

  describe "direct_upload_url" do
    let(:options) { {direct_upload_url: "/register/direct_uploads?b_param_token=xyz"} }

    # Rendered as an ordinary file field: without JS it posts the bytes, and the controller
    # drops the name only once it's uploading them itself
    it "renders a named field alongside the signed id it will fill" do
      expect(component).to have_css("input[type='file'][name='user[avatar]']")
      expect(component).to have_css("[data-ui--forms--files--upload-url-value='/register/direct_uploads?b_param_token=xyz']")
      expect(component).to have_css("input[type='hidden'][name='user[avatar_signed_id]'][data-ui--forms--files--upload-target='signedId']", visible: :all)
    end

    context "without one" do
      let(:options) { {} }

      it "renders no signed id field" do
        expect(component).to have_no_css("[data-ui--forms--files--upload-target='signedId']", visible: :all)
        expect(component).to have_no_css("[data-ui--forms--files--upload-url-value]:not([data-ui--forms--files--upload-url-value=''])")
      end
    end
  end

  describe "thumbnail of what's already attached" do
    let(:fixture) { Rails.root.join("spec/fixtures/bike.jpg") }

    context "with a CarrierWave uploader" do
      let(:record) { Organization.new(avatar: File.open(fixture)) }

      it "previews AvatarUploader's thumb version, linked to the full size" do
        expect(component).to have_css("a[href$='/bike.jpg'] img[src$='/thumb_bike.jpg'][alt='Avatar']")
      end
    end

    context "with an ActiveStorage attachment" do
      # persisted: a blob has no signed_id, and so no URL, until it's saved
      let(:record) { FactoryBot.create(:registration_sequence_page) }
      let(:attribute) { :image }

      before { record.image.attach(io: File.open(fixture), filename: "bike.jpg", content_type: "image/jpeg") }

      # no versions to pick from, so the preview is the attachment itself
      it "previews the attachment, linking to the same url" do
        expect(component).to have_css("a[href='#{record.image_url}'] img[alt='Image'][src='#{record.image_url}']")
      end
    end
  end
end
