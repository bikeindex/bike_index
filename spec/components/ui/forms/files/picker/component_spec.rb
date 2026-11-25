# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Files::Picker::Component, type: :component do
  let(:options) { {} }
  let(:component) { render_inline(described_class.new(html_options: {id: "picker"}, **options)) }

  it "labels the input it's given, whatever renders above and below" do
    expect(component).to have_css("input#picker[type='file'].tw\\:sr-only")
    expect(component).to have_css("label[for='picker'][data-action='click->ui--forms--files--picker#chooseFile']", text: "Upload")
    expect(component).to have_css("[data-ui--forms--files--picker-target='filename']", text: "No file chosen")
    # decorative -- the label text is what names it
    expect(component).to have_css("label svg[aria-hidden='true']")
    # the frame is always rendered -- only its outline reacts to a drag
    expect(component).to have_css("[data-ui--forms--files--picker-target='dropZone'].tw\\:outline-transparent")
    # nothing accepted, so nothing to photograph
    expect(component).to have_no_css("button[data-action='ui--forms--files--picker#takePicture']")
  end

  # Files::Upload adds its own target to the input - replacing the data would leave the picker unwired,
  # and replacing the class would unhide the input and drop the label's peer focus ring
  it "keeps its own data and classes on the input alongside the caller's" do
    rendered = render_inline(described_class.new(html_options: {id: "x", class: "extra", data: {"ui--forms--files--upload-target": "input"}}))

    expect(rendered).to have_css("input#x[data-ui--forms--files--picker-target='input'][data-ui--forms--files--upload-target='input']")
    expect(rendered).to have_css("input#x[data-action='ui--forms--files--picker#display']")
    expect(rendered).to have_css("input#x.tw\\:peer.tw\\:sr-only.extra")
  end

  it "accepts a string, an array, or nothing" do
    expect(render_inline(described_class.new(html_options: {id: "x"}, accept: "image/png,image/jpeg")))
      .to have_css("input[type='file'][accept='image/png,image/jpeg']")
    expect(render_inline(described_class.new(html_options: {id: "x"}, accept: %w[.png .jpg])))
      .to have_css("input[type='file'][accept='.png,.jpg']")
    expect(render_inline(described_class.new(html_options: {id: "x"})))
      .to have_no_css("input[type='file'][accept]")
  end

  describe "camera" do
    context "when only images are accepted" do
      let(:options) { {accept: ImageUploader.permitted_extensions} }

      it "renders a camera button with the camera icon" do
        expect(component).to have_css("button[data-action='ui--forms--files--picker#takePicture']", text: "Take picture")
        # decorative -- the button text is what names it
        expect(component).to have_css("button svg[aria-hidden='true']")
      end
    end

    context "when a non-image is also accepted" do
      let(:options) { {accept: PdfUploader.permitted_extensions} }

      it "renders no camera button" do
        expect(component).to have_no_css("button[data-action='ui--forms--files--picker#takePicture']")
      end
    end

    context "when forced on for a non-image accept" do
      let(:options) { {accept: ".csv", camera: true} }

      it "renders a camera button" do
        expect(component).to have_css("button[data-action='ui--forms--files--picker#takePicture']", text: "Take picture")
      end
    end

    context "when forced off for an image accept" do
      let(:options) { {accept: "image/*", camera: false} }

      it "renders no camera button" do
        expect(component).to have_no_css("button[data-action='ui--forms--files--picker#takePicture']")
      end
    end
  end
end
