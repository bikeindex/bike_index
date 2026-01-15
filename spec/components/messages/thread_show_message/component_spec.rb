# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::ThreadShowMessage::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {marketplace_message:, initial_message:, current_user:} }
  let(:marketplace_message) { FactoryBot.create(:marketplace_message_reply) }
  let(:initial_message) { marketplace_message.initial_message }
  let(:current_user) { initial_message.sender }

  it "renders" do
    expect(marketplace_message.initial_message?).to be_falsey
    expect(component).to have_css("div")
    expect(component).to have_content marketplace_message.body
    expect(component).to_not have_content "Subject"
  end

  context "when initial message" do
    it "includes subject" do
      expect(marketplace_message.initial_message?).to be_falsey
      expect(component).to have_css("div")
      expect(component).to have_content marketplace_message.body
      expect(component).to_not have_content "Subject"
    end
  end
end
