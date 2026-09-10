# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::UserAlerts::PhoneWaitingConfirmation::Component, type: :component do
  let(:user_phone) { UserPhone.new(id: 12, phone: "2018884111") }
  let(:component) { render_inline(described_class.new(user_phone:)) }

  it "doesn't render without a phone" do
    expect(described_class.new(user_phone: nil).render?).to be_falsey
  end

  it "opens the modal with the code form for the phone" do
    # A button, not an anchor - there's no target to link to, it opens the dialog
    expect(component.css("button[commandfor='confirm-phone-number']").text.strip)
      .to eq "Confirm your phone number"
    modal = component.css("dialog#confirm-phone-number")
    expect(modal.text).to include "Verify 201-888-4111"
    form = modal.css("form").first
    expect(form[:action]).to eq "/user_phones/12"
    expect(form.css("input[name='_method']").first[:value]).to eq "patch"
    expect(form.css("input[name='confirmation_code']")).to be_present
  end
end
