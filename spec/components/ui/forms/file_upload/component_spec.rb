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

  it "renders the input, both labels and the drop frame -- but no camera or thumbnail" do
    expect(component).to have_css("input#user_avatar[type='file'][name='user[avatar]']")
    expect(component).to have_css("[data-controller='form--file-upload']")
    expect(component).to have_css("[data-form--file-upload-target='input']")
    expect(component).to have_css("[data-form--file-upload-target='filename']", text: "No file chosen")
    expect(component).to have_css("label[data-action='click->form--file-upload#chooseFile']")
    # both wordings ship, and the pointer media query picks one (see the system spec)
    expect(component).to have_css("label span", text: "Click or drop to choose file")
    expect(component).to have_css("label span", text: "Choose file")
    # the frame is always rendered -- only its border reacts to a drag
    expect(component).to have_css("[data-form--file-upload-target='dropZone'].tw\\:border-transparent")
    # nothing accepted, so nothing to photograph; nothing attached, so nothing to preview
    expect(component).to have_no_css("button[data-action='form--file-upload#takePicture']")
    expect(component).to have_no_css("img")
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
        expect(component).to have_css("button[data-action='form--file-upload#takePicture']", text: "Take picture")
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
