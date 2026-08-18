# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageBlock::UserAlerts::UnfinishedRegistration::Component, type: :component do
  let(:b_param) { FactoryBot.create(:b_param_unfinished_registration) }
  let(:component) { render_inline(described_class.new(b_param:)) }

  it "links back into the flow, naming the cycle type" do
    expect(component.text.squish).to eq "Notice Your cargo bike isn't registered yet! Please finish the required steps"
    link = component.css("a").first
    expect(link.text.strip).to eq "finish the required steps"
    expect(link[:href]).to eq "/register?b_param_token=#{b_param.id_token}"
  end

  it "doesn't render without a b_param" do
    expect(described_class.new(b_param: nil).render?).to be_falsey
  end

  context "with the bike created" do
    before { b_param.update(created_bike_id: FactoryBot.create(:bike).id) }

    it "doesn't render" do
      expect(described_class.new(b_param:).render?).to be_falsey
    end
  end
end
