# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Code::Inline::Component, type: :component do
  let(:component) { render_inline(described_class.new(text:, **options)) }
  let(:text) { 1987 }
  let(:options) { {} }

  it "renders the value inline at the default size, breaking long words" do
    expect(component).to have_css("code.tw\\:text-sm.tw\\:wrap-break-word", text: "1987")
    expect(component).to_not have_css("code.tw\\:text-xs")
    expect(component).to_not have_css("code.tw\\:break-keep")
  end

  context "with small" do
    let(:options) { {small: true} }

    it "renders only the smaller text size" do
      expect(component).to have_css("code.tw\\:text-xs", text: "1987")
      expect(component).to_not have_css("code.tw\\:text-sm")
    end
  end

  context "with word_break: false" do
    let(:options) { {word_break: false} }

    it "keeps words whole" do
      expect(component).to have_css("code.tw\\:break-keep", text: "1987")
      expect(component).to_not have_css("code.tw\\:wrap-break-word")
    end
  end

  context "with html in the value" do
    let(:text) { "<a href='/x'>x</a>" }

    it "escapes it" do
      expect(component).to_not have_css("code a")
      expect(component.text).to eq text
    end

    context "marked safe" do
      let(:text) { "<a href='/x'>x</a>".html_safe }

      it "renders it" do
        expect(component).to have_css("code a[href='/x']", text: "x")
      end
    end
  end
end
