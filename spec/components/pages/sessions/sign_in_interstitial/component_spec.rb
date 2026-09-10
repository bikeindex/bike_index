# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Sessions::SignInInterstitial::Component, type: :component do
  let(:component) { render_inline(described_class.new(url:, fields:, **options)) }
  let(:url) { "/session/sign_in_with_magic_link" }
  let(:fields) { {token: "sometoken", partner: nil} }
  let(:options) { {} }

  it "posts the fields it was given, dropping the blank ones, and waits for a click" do
    expect(component).to have_css("form[action='#{url}'][method='post']")
    expect(component).to have_no_css("form[data-controller]")
    expect(component).to have_css("input[name='token'][value='sometoken']", visible: :hidden)
    expect(component).to have_no_css("input[name='partner']", visible: :hidden)
    expect(component).to have_button("Sign in")
  end

  context "copy passed in" do
    let(:options) { {heading: "Unsubscribing", submit_text: "Unsubscribe"} }

    it "renders it instead of the sign in copy" do
      expect(component).to have_css("h3", text: "Unsubscribing")
      expect(component).to have_button("Unsubscribe")
      expect(component).to have_no_button("Sign in")
    end
  end
end
