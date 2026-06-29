# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::FileUpload::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, html_options:)) }
  let(:attribute) { :avatar }
  let(:html_options) { {} }

  it "renders a labelless file input" do
    expect(component).to have_css("input[type='file'][name='user[avatar]']")
    expect(component).to have_no_css("label")
    expect(component.to_html).to include("twinput")
    expect(component.to_html).to include("tw:cursor-pointer")
  end

  context "with html_options" do
    let(:html_options) { {accept: "image/png", multiple: true} }

    it "passes options through" do
      expect(component).to have_css("input[type='file'][accept='image/png']")
      expect(component).to have_css("input[multiple]")
    end

    context "when overriding class" do
      let(:html_options) { {class: "custom-upload"} }

      it "replaces the default class" do
        expect(component).to have_css("input.custom-upload")
        expect(component.to_html).to_not include("twinput")
      end
    end
  end
end
