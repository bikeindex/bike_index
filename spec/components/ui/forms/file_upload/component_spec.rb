# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::FileUpload::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, **options)) }
  let(:attribute) { :avatar }
  let(:options) { {} }

  it "renders the input, label and collapsed drop zone -- but no camera or thumbnail" do
    expect(component).to have_css("input#user_avatar[type='file'][name='user[avatar]']")
    expect(component).to have_css("label[for='user_avatar']", text: "Choose file")
    expect(component).to have_css("[data-controller='form--file-upload']")
    expect(component).to have_css("[data-form--file-upload-target='input']")
    expect(component).to have_css("[data-form--file-upload-target='filename']", text: "No file chosen")
    expect(component).to have_css("label[data-action='click->form--file-upload#chooseFile']")
    expect(component).to have_css("[data-form--file-upload-target='dropZone'].tw\\:hidden", text: "Drop a file here")
    # the full string: a typo in either handler name would leave the highlight inert
    expect(component).to have_css("[data-form--file-upload-target='dropZone'][data-action='drop->form--file-upload#drop dragenter->form--file-upload#highlightDropZone dragleave->form--file-upload#unhighlightDropZone']")
    # nothing accepted, so nothing to photograph; nothing attached, so nothing to preview
    expect(component).to have_no_css("button[data-action='form--file-upload#takePicture']")
    expect(component).to have_no_css("img")
  end

  context "with multiple" do
    let(:options) { {multiple: true} }

    it "sets the input attribute and pluralizes the drop zone text" do
      expect(component).to have_css("input[type='file'][multiple]")
      expect(component).to have_css("[data-form--file-upload-target='dropZone']", text: "Drop files here")
    end
  end

  context "with custom button_text, camera_text and placeholder" do
    let(:options) { {accept: "image/*", button_text: "Browse", camera_text: "Use camera", placeholder: "Pick an image"} }

    it "uses the provided text" do
      expect(component).to have_css("label[for='user_avatar']", text: "Browse")
      expect(component).to have_css("button[data-action='form--file-upload#takePicture']", text: "Use camera")
      expect(component).to have_css("[data-form--file-upload-target='filename']", text: "Pick an image")
    end
  end

  context "with html_options" do
    let(:options) { {html_options: {accept: "image/png", multiple: true}} }

    it "passes options through to the input" do
      expect(component).to have_css("input[type='file'][accept='image/png']")
      expect(component).to have_css("input[multiple]")
    end
  end

  context "with accept" do
    context "as a string" do
      let(:options) { {accept: "image/png,image/jpeg"} }

      it "sets the accept attribute" do
        expect(component).to have_css("input[type='file'][accept='image/png,image/jpeg']")
      end
    end

    context "as an array" do
      let(:options) { {accept: %w[.png .jpg]} }

      it "joins into the accept attribute" do
        expect(component).to have_css("input[type='file'][accept='.png,.jpg']")
      end
    end

    context "when omitted" do
      it "renders no accept attribute" do
        expect(component).to have_no_css("input[type='file'][accept]")
      end
    end
  end

  describe "thumbnail of what's already attached" do
    let(:fixture) { Rails.root.join("spec/fixtures/bike.jpg") }

    context "with a CarrierWave uploader" do
      let(:user) { Organization.new(avatar: File.open(fixture)) }
      let(:attribute) { :avatar }

      it "previews AvatarUploader's thumb version, linked to the full size" do
        expect(component).to have_css("a[href$='/bike.jpg'] img[src$='/thumb_bike.jpg'][alt='Avatar']")
      end
    end

    context "with an ActiveStorage attachment" do
      # persisted: a blob has no signed_id, and so no URL, until it's saved
      let(:user) { FactoryBot.create(:registration_sequence_page) }
      let(:attribute) { :image }

      before { user.image.attach(io: File.open(fixture), filename: "bike.jpg", content_type: "image/jpeg") }

      # no versions to pick from, so the preview is the attachment itself
      it "previews the attachment, linking to the same url" do
        expect(component).to have_css("img[alt='Image'][src='#{user.image_url}']")
        expect(component).to have_css("a[href='#{user.image_url}'] img")
      end
    end
  end

  describe "camera" do
    context "when only images are accepted" do
      let(:options) { {accept: ImageUploader.permitted_extensions} }

      it "renders a camera button, hidden for fine pointers" do
        expect(component).to have_css("button[data-action='form--file-upload#takePicture'].tw\\:pointer-fine\\:hidden", text: "Take picture")
        # decorative -- the button text is what names it
        expect(component).to have_css("button svg[aria-hidden='true']")
      end
    end

    context "when a non-image is also accepted" do
      let(:options) { {accept: PdfUploader.permitted_extensions} }

      it "renders no camera button" do
        expect(component).to have_no_css("button[data-action='form--file-upload#takePicture']")
      end
    end

    context "when forced on for a non-image accept" do
      let(:options) { {accept: ".csv", camera: true} }

      it "renders a camera button" do
        expect(component).to have_css("button[data-action='form--file-upload#takePicture']", text: "Take picture")
      end
    end

    context "when forced off for an image accept" do
      let(:options) { {accept: "image/*", camera: false} }

      it "renders no camera button" do
        expect(component).to have_no_css("button[data-action='form--file-upload#takePicture']")
      end
    end
  end
end
