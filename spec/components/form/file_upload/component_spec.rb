# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::FileUpload::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, **options)) }
  let(:attribute) { :avatar }
  let(:options) { {} }

  it "renders a labelless file input with a filename display" do
    expect(component).to have_css("input[type='file'][name='user[avatar]']")
    expect(component).to have_no_css("label")
    expect(component.to_html).to include("twinput")
    expect(component).to have_css("[data-controller='form--file-upload']")
    expect(component).to have_css("[data-form--file-upload-target='input']")
    expect(component).to have_css("[data-form--file-upload-target='filename']", text: "No file chosen")
    expect(component).to have_text("Choose file")
  end

  context "with custom button_text and placeholder" do
    let(:options) { {button_text: "Browse", placeholder: "Pick an image"} }

    it "uses the provided text" do
      expect(component).to have_text("Browse")
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
end
