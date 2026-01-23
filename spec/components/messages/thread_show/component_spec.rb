# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::ThreadShow::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {marketplace_messages:, initial_message:, current_user:, can_send_message:, marketplace_listing:} }
  let(:marketplace_message) { FactoryBot.create(:marketplace_message) }
  let(:initial_message) { marketplace_message&.initial_message }
  let(:marketplace_listing) { marketplace_message.marketplace_listing }
  let(:current_user) { initial_message.sender }
  let(:can_send_message) { true }
  let(:marketplace_messages) { marketplace_message.messages_in_thread }

  it "buyer" do
    expect(marketplace_message.initial_message?).to be_truthy
    expect(component).to have_css("div")
    expect(component).to have_content marketplace_message.body
    expect(component).to have_content "Subject"
    expect(component).to have_button "Send message"

    component_text = whitespace_normalized_body_text(component.to_html)
    expect(component_text)
      .to match(/Me \(#{current_user.marketplace_message_name}\) to #{marketplace_message.receiver.marketplace_message_name}/)
    expect(component_text).to_not match(/bike sold to/)
  end

  context "sending initial message" do
    let(:marketplace_messages) { MarketplaceMessage.none }
    let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, :for_sale) }
    let(:current_user) { FactoryBot.create(:user_confirmed) }
    let(:marketplace_message) { nil }
    it "renders" do
      expect(component).to have_css("div")
      expect(component).to have_content "Subject"
      expect(component).to have_button "Send message"

      component_text = whitespace_normalized_body_text(component.to_html)
      expect(component_text).to_not match " to "
      expect(component_text).to_not match(/bike sold to/)
    end
  end

  context "current_user: receiver" do
    let(:current_user) { initial_message.receiver }
    it "renders" do
      expect(marketplace_message.initial_message?).to be_truthy
      component.to_html
      expect(component).to have_css("div")
      expect(component).to have_content marketplace_message.body
      expect(component).to have_content "Subject"
      expect(component).to have_button "Send message"
      expect(component).to have_content marketplace_message.subject
      expect(component).to have_content marketplace_message.sender.marketplace_message_name

      component_text = whitespace_normalized_body_text(component.to_html)
      expect(component_text).to match(/to me \(#{current_user.marketplace_message_name}\)/)
      expect(component_text).to match(/bike sold to/)
    end
  end

  context "when not initial message" do
    let(:marketplace_message) { FactoryBot.create(:marketplace_message_reply) }
    let(:user_ids) do
      [marketplace_message.sender_id, marketplace_message.receiver_id, initial_message.sender_id,
        initial_message.receiver_id, marketplace_listing.seller_id]
    end

    it "includes subject" do
      expect(marketplace_message.initial_message?).to be_falsey
      # Sanity check
      expect(user_ids.uniq).to match_array([marketplace_message.sender_id, marketplace_message.receiver_id])
      expect(marketplace_message.sender_id).to eq marketplace_listing.seller_id
      expect(initial_message.sender_id).to eq current_user.id
      expect(component).to have_css("div")
      expect(component).to have_content marketplace_message.body
      expect(component).to have_content "Subject"
      expect(component).to have_button "Send message"

      component_text = whitespace_normalized_body_text(component.to_html)
      expect(component_text)
        .to match(/Me \(#{current_user.marketplace_message_name}\) to #{initial_message.receiver.marketplace_message_name}/)
      expect(component_text).to_not match(/bike sold to/)
    end

    context "with can_send_message: false" do
      let(:current_user) { initial_message.receiver }
      let(:can_send_message) { false }

      it "includes subject" do
        expect(marketplace_message.initial_message?).to be_falsey
        expect(component).to have_css("div")
        expect(component).to have_content marketplace_message.body
        expect(component).to have_content "Subject"
        expect(component).to_not have_button "Send message"

        component_text = whitespace_normalized_body_text(component.to_html)
        expect(component_text)
          .to match(/#{marketplace_message.receiver.marketplace_message_name} to me \(#{current_user.marketplace_message_name}\)/)
        expect(component_text).to match(/bike sold to/)
      end
    end
  end
end
