# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeServices::RegisterFlow do
  let(:flow) { described_class.new(page_count: 2, report: :after_details) }

  it "walks its steps in order" do
    expect(flow.steps).to eq %w[1 2 report 3 4 review]
    expect(flow.single_page?).to be_falsey
    expect(flow.acknowledgments?).to be_truthy
    expect(flow.count).to eq 6
    expect(flow.position("report")).to eq 3
    expect(flow.position(2)).to eq 2
    expect(flow.after("report")).to eq "3"
    expect(flow.before("report")).to eq "2"
    # Nothing comes before or after the ends
    expect(flow.before("1")).to be_nil
    expect(flow.after("review")).to be_nil
  end

  context "a report waiting on the confirmation email" do
    let(:flow) { described_class.new(page_count: 2, report: :last) }

    it "comes after the acknowledgments" do
      expect(flow.steps).to eq %w[1 2 3 4 review report]
    end
  end

  context "the single page, without a sequence" do
    let(:flow) { described_class.new(single_page: true) }

    it "is one step" do
      expect(flow.steps).to eq %w[1]
      expect(flow.acknowledgments?).to be_falsey
    end
  end
end
