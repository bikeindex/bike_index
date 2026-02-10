# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Chart::Component, type: :component do
  let(:time_range) { 1.week.ago..Time.current }
  let(:instance) { described_class.new(series: [{name: "Test", data: {}}], time_range:) }

  it "renders" do
    component = render_inline(instance)
    expect(component).to be_present
  end

  context "with payment" do
    let(:start_time) { Time.at(1568052985) }
    let(:payment_time) { start_time + 1.minute }
    let!(:payment) { FactoryBot.create(:payment, created_at: payment_time, amount_cents: 1001) }
    let(:time_range) { start_time..(start_time + 3.minutes) }
    before { Time.zone = "America/Chicago" }

    describe "time_range_counts" do
      let(:target_counts) { {" 1:16 PM" => 0, " 1:17 PM" => 1, " 1:18 PM" => 0, " 1:19 PM" => 0} }
      it "returns the thing with want" do
        expect(described_class.time_range_counts(collection: Payment.all, time_range:)).to eq target_counts
      end
    end
  end
end
