# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sessions::SignInInterstitial::Component, type: :component do
  let(:component) { render_inline(described_class.new(url:, fields:, **options)) }
  let(:url) { "/session/sign_in_with_magic_link" }
  let(:fields) { {token: "sometoken", partner: nil} }
  let(:options) { {} }

  it "posts the fields it was given, dropping the blank ones" do
    expect(component).to have_css("form[action='#{url}'][method='post'][data-controller='auto-submit']")
    expect(component).to have_css("input[name='token'][value='sometoken']", visible: :hidden)
    expect(component).to have_no_css("input[name='partner']", visible: :hidden)
    expect(component).to have_button("Sign in")
  end

  context "auto_submit false" do
    let(:options) { {auto_submit: false} }

    it "leaves the submitting to the reader" do
      expect(component).to have_css("form[action='#{url}']")
      expect(component).to have_no_css("[data-controller='auto-submit']")
    end
  end
end
