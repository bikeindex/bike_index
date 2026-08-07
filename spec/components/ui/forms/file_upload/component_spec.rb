# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::FileUpload::Component, type: :component do
  let(:record) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, record, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, **options)) }
  let(:attribute) { :avatar }
  let(:options) { {} }

  it "renders the input, the upload label and the drop frame -- but no camera, and an empty preview" do
    expect(component).to have_css("input#user_avatar[type='file'][name='user[avatar]']")
    expect(component).to have_css("[data-controller='ui--forms--file-upload']")
    expect(component).to have_css("[data-ui--forms--file-upload-target='input']")
    expect(component).to have_css("[data-ui--forms--file-upload-target='filename']", text: "No file chosen")
    expect(component).to have_css("label[data-action='click->ui--forms--file-upload#chooseFile']", text: "Upload")
    # decorative -- the label text is what names it
    expect(component).to have_css("label svg[aria-hidden='true']")
    # the frame is always rendered -- only its outline reacts to a drag
    expect(component).to have_css("[data-ui--forms--file-upload-target='dropZone'].tw\\:outline-transparent")
    # nothing accepted, so nothing to photograph
    expect(component).to have_no_css("button[data-action='ui--forms--file-upload#takePicture']")
    # nothing attached, so the preview ships hidden and srcless, waiting for a pick
    # hidden! because collapse() hides with the important variant, and tw:block is on the same element
    expect(component).to have_css("a[data-ui--forms--file-upload-target='preview'].tw\\:hidden\\! img")
    expect(component).to have_no_css("[data-ui--forms--file-upload-target='preview'][href]")
    expect(component).to have_no_css("img[src]")
  end

  context "with html_options" do
    let(:options) { {html_options: {accept: "image/png", multiple: true}} }

    it "passes options through to the input" do
      expect(component).to have_css("input[type='file'][accept='image/png']")
      expect(component).to have_css("input[multiple]")
    end
  end

  it "accepts a string, an array, or nothing" do
    expect(render_inline(described_class.new(form_builder:, attribute:, accept: "image/png,image/jpeg")))
      .to have_css("input[type='file'][accept='image/png,image/jpeg']")
    expect(render_inline(described_class.new(form_builder:, attribute:, accept: %w[.png .jpg])))
      .to have_css("input[type='file'][accept='.png,.jpg']")
    expect(render_inline(described_class.new(form_builder:, attribute:)))
      .to have_no_css("input[type='file'][accept]")
  end

  describe "direct_upload_url" do
    let(:options) { {direct_upload_url: "/register/direct_uploads?b_param_token=xyz"} }

    # Rendered as an ordinary file field: without JS it posts the bytes, and the controller
    # drops the name only once it's uploading them itself
    it "renders a named field alongside the signed id it will fill" do
      expect(component).to have_css("input[type='file'][name='user[avatar]']")
      expect(component).to have_css("[data-ui--forms--file-upload-url-value='/register/direct_uploads?b_param_token=xyz']")
      expect(component).to have_css("input[type='hidden'][name='user[avatar_signed_id]'][data-ui--forms--file-upload-target='signedId']", visible: :all)
    end

    context "without one" do
      let(:options) { {} }

      it "renders no signed id field" do
        expect(component).to have_no_css("[data-ui--forms--file-upload-target='signedId']", visible: :all)
        expect(component).to have_no_css("[data-ui--forms--file-upload-url-value]:not([data-ui--forms--file-upload-url-value=''])")
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

  describe "camera" do
    context "when only images are accepted" do
      let(:options) { {accept: ImageUploader.permitted_extensions} }

      it "renders a camera button with the camera icon" do
        expect(component).to have_css("button[data-action='ui--forms--file-upload#takePicture']", text: "Take picture")
        # decorative -- the button text is what names it
        expect(component).to have_css("button svg[aria-hidden='true']")
      end
    end

    context "when a non-image is also accepted" do
      let(:options) { {accept: PdfUploader.permitted_extensions} }

      it "renders no camera button" do
        expect(component).to have_no_css("button[data-action='ui--forms--file-upload#takePicture']")
      end
    end

    context "when forced on for a non-image accept" do
      let(:options) { {accept: ".csv", camera: true} }

      it "renders a camera button" do
        expect(component).to have_css("button[data-action='ui--forms--file-upload#takePicture']", text: "Take picture")
      end
    end

    context "when forced off for an image accept" do
      let(:options) { {accept: "image/*", camera: false} }

      it "renders no camera button" do
        expect(component).to have_no_css("button[data-action='ui--forms--file-upload#takePicture']")
      end
    end
  end
end
