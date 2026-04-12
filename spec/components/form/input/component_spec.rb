# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::Input::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) { render_inline(described_class.new(form_builder:, attribute:, kind:, html_options:)) }
  let(:attribute) { :name }
  let(:kind) { :text_field }
  let(:html_options) { {} }

  it "renders a text field" do
    expect(component).to have_css("input[type='text'][name='user[name]']")
    expect(component.to_html).to include("twinput")
  end

  context "when text_area" do
    let(:kind) { :text_area }

    it "renders a textarea" do
      expect(component).to have_css("textarea[name='user[name]']")
    end
  end

  context "when email_field" do
    let(:kind) { :email_field }
    let(:attribute) { :email }

    it "renders an email input" do
      expect(component).to have_css("input[type='email'][name='user[email]']")
    end
  end

  context "when number_field" do
    let(:kind) { :number_field }

    it "renders a number input" do
      expect(component).to have_css("input[type='number']")
    end
  end

  context "when invalid kind" do
    let(:kind) { :password_field }

    it "falls back to text_field" do
      expect(component).to have_css("input[type='text']")
    end
  end

  context "with html_options" do
    let(:html_options) { {placeholder: "Enter name"} }

    it "passes options through" do
      expect(component).to have_css("input[placeholder='Enter name']")
    end
  end
end
