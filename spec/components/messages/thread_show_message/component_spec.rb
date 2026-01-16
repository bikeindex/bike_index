# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::ThreadShowMessage::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {marketplace_message:, initial_message:, current_user:} }
  let(:marketplace_message) { FactoryBot.create(:marketplace_message) }
  let(:initial_message) { marketplace_message.initial_message }
  let(:current_user) { initial_message.sender }

  it "renders" do
    expect(marketplace_message.initial_message?).to be_truthy
    expect(component).to have_css("div")
    expect(component).to have_content marketplace_message.body
    expect(component).to have_content "Subject"
    expect(component).to have_content marketplace_message.subject

    component_text = whitespace_normalized_body_text(component.to_html)
    expect(component_text).to match(/Me \(#{current_user.marketplace_message_name}\)/)
    expect(component_text).to match(/to #{marketplace_message.receiver.marketplace_message_name}/)
  end

  context "current_user: receiver" do
    let(:current_user) { initial_message.receiver }
    it "renders" do
      expect(marketplace_message.initial_message?).to be_truthy
      component.to_html
      expect(component).to have_css("div")
      expect(component).to have_content marketplace_message.body
      expect(component).to have_content "Subject"
      expect(component).to have_content marketplace_message.subject
      expect(component).to have_content marketplace_message.sender.marketplace_message_name

      component_text = whitespace_normalized_body_text(component.to_html)
      expect(component_text).to match(/to me \(#{current_user.marketplace_message_name}\)/)
    end
  end

  context "when not initial message" do
    let(:marketplace_message) { FactoryBot.create(:marketplace_message_reply) }

    it "includes subject" do
      expect(marketplace_message.initial_message?).to be_falsey
      expect(component).to have_css("div")
      expect(component).to have_content marketplace_message.body
      expect(component).to_not have_content "Subject"
      expect(component).to_not have_content marketplace_message.subject
    end
  end
end
