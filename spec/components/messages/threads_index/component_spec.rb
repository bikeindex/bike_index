# frozen_string_literal: true

require "rails_helper"

RSpec.describe Messages::ThreadsIndex::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:component) { render_inline(instance) }
  let(:options) { {marketplace_message:, current_user:} }
  let(:marketplace_message) { FactoryBot.create(:marketplace_message, sender: current_user) }
  let(:current_user) { FactoryBot.create(:user) }

  it "renders" do
    expect(component).to be_present
  end

  context "with deleted item and user" do
    before do
      marketplace_message.item.destroy
      marketplace_message.receiver.destroy
    end
    it "renders" do
      expect(component).to be_present
    end
  end

  describe "#sender_display_html" do
    let(:sender_display_html) { instance.send(:sender_display_html) }
    let(:other_name) { marketplace_message.receiver.name }
    let(:target) { "<span>To: #{other_name}</span>" }
    it "returns html" do
      expect(sender_display_html).to eq target
    end

    context "when the receiver" do
      let(:marketplace_message) { FactoryBot.build(:marketplace_message, receiver: current_user) }
      let(:other_name) { marketplace_message.sender.name }
      let(:target) { "<strong class=\"tw:font-bold\">#{other_name}</strong>" }
      it "returns html" do
        expect(sender_display_html).to eq target
      end
    end

    context "when a reply" do
      let(:marketplace_message) { FactoryBot.create(:marketplace_message_reply, receiver: current_user) }
      let(:target) do
        "<span>me, <strong class=\"tw:font-bold\">#{marketplace_message.sender.name}</strong><span class=\"tw:opacity-65\"> 2</span></span>"
      end
      it "returns html" do
        expect(marketplace_message.initial_record.sender_id).to eq current_user.id
        expect(sender_display_html).to eq target
      end

      context "when 2 messages to sender" do
        let(:marketplace_message_pre) { FactoryBot.create(:marketplace_message, sender: current_user) }
        let(:marketplace_message) { FactoryBot.create(:marketplace_message_reply, initial_record: marketplace_message_pre, sender: current_user) }
        let(:target) do
          "<span>To: #{other_name}<span class=\"tw:opacity-65\"> 2</span></span>"
        end
        it "is the target" do
          expect(marketplace_message_pre.sender_id).to eq current_user.id
          expect(marketplace_message.sender_id).to eq current_user.id
          expect(marketplace_message_pre.receiver_id).to eq marketplace_message.receiver_id
          expect(sender_display_html).to eq target
        end
      end
    end

    context "when multiple replies" do
      let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, seller: current_user) }
      let(:initial_record) { FactoryBot.create(:marketplace_message, marketplace_listing:) }
      let!(:marketplace_message_pre) { FactoryBot.create(:marketplace_message_reply, receiver: current_user, initial_record:) }
      let(:marketplace_message) { FactoryBot.create(:marketplace_message_reply, sender: current_user, initial_record:) }
      let(:target) do
        "<span>#{other_name}... <strong class=\"tw:font-bold\">me</strong><span class=\"tw:opacity-65\"> 3</span></span>"
      end
      it "returns html" do
        expect(marketplace_message_pre.receiver_id).to eq current_user.id
        expect(marketplace_message.sender_id).to eq current_user.id
        expect(marketplace_message.receiver_id).to eq marketplace_message_pre.sender_id
        expect(marketplace_message.messages_prior.pluck(:id)).to eq([initial_record.id, marketplace_message_pre.id])
        expect(sender_display_html).to eq target
      end

      context "even more replies" do
        let(:seller) { FactoryBot.create(:user) }
        let(:marketplace_listing) { FactoryBot.create(:marketplace_listing, seller:) }
        let(:initial_record) { FactoryBot.create(:marketplace_message, marketplace_listing:, sender: current_user) }
        let!(:marketplace_message_pre_2) { FactoryBot.create(:marketplace_message_reply, sender: current_user, initial_record:) }
        let(:target) do
          "<span>me, #{other_name}... <strong class=\"tw:font-bold\">me</strong><span class=\"tw:opacity-65\"> 4</span></span>"
        end
        it "returns html" do
          expect(marketplace_message.reload.messages_prior.pluck(:id)).to eq([initial_record.id, marketplace_message_pre.id, marketplace_message_pre_2.id])
          expect(sender_display_html).to eq target
        end
      end
    end
  end
end
