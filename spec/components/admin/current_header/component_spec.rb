# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::CurrentHeader::Component, type: :component do
  let(:instance) { described_class.new(**options) }
  let(:options) { {params:, viewing:, kind_humanized:} }
  let(:params) { {} }
  let(:viewing) { nil }
  let(:kind_humanized) { nil }

  context "without header params" do
    let(:component) { render_inline(instance) }

    it "renders nothing when no header params present" do
      expect(component.css("div")).to be_blank
    end
  end

  context "with user_id param" do
    let(:user) { FactoryBot.create(:user) }
    let(:params) { {user_id: user.id} }
    let(:options) { {params:, user:} }

    it "shows user is present" do
      expect(instance.send(:show_user?)).to be true
      expect(instance.send(:user_subject)).to eq(user)
    end
  end

  context "with viewing parameter" do
    let(:params) { {user_id: "123"} }
    let(:viewing) { "Test Items" }

    it "uses custom viewing text" do
      expect(instance.send(:viewing)).to eq("Test Items")
    end
  end

  context "with kind_humanized parameter" do
    let(:params) { {search_kind: "test"} }
    let(:kind_humanized) { "Special Kind" }

    it "uses custom kind_humanized" do
      expect(instance.send(:kind_humanized)).to eq("Special Kind")
    end
  end
end
