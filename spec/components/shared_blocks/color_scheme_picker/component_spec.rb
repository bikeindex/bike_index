# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::ColorSchemePicker::Component, type: :component do
  let(:component) { render_inline(described_class.new(color_scheme: "dark", url:)) }
  let(:url) { nil }
  let(:radios) { component.css("input[type=radio][name='user[color_scheme]']") }

  it "checks the current scheme, and saves nowhere but the cookie" do
    expect(radios.map { it["value"] }).to eq %w[light dark system]
    expect(radios.select { it["checked"] }.map { it["value"] }).to eq %w[dark]
    expect(radios.map { it["id"] }.compact).to eq []
    expect(component.css("[data-controller=color-scheme]").first.attributes).to_not have_key("data-color-scheme-url-value")
  end

  context "with a url" do
    let(:url) { "/my_account" }
    it "saves to it" do
      expect(component.css("[data-controller=color-scheme]").first["data-color-scheme-url-value"]).to eq url
    end
  end
end
