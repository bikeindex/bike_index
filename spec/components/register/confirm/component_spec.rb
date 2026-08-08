# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::Confirm::Component, type: :component do
  let(:component) { render_inline(described_class.new(b_param:, token: "sometoken", **options)) }
  let(:b_param) { FactoryBot.create(:b_param, params: {bike: {owner_email: "someone@bikeindex.org"}}) }
  let(:options) { {} }

  it "posts the token itself, so a link scanner's GET can't spend it" do
    expect(component).to have_css("form[action='/register/confirm_email'][method='post'][data-controller='auto-submit']")
    expect(component).to have_css("input[name='confirmation_token'][value='sometoken']", visible: :hidden)
    expect(component).to have_css("input[name='b_param_token'][value='#{b_param.id_token}']", visible: :hidden)
  end

  context "auto_submit false" do
    let(:options) { {auto_submit: false} }

    it "leaves the submitting to the reader" do
      expect(component).to have_css("form[action='/register/confirm_email']")
      expect(component).to have_no_css("[data-controller='auto-submit']")
    end
  end
end
