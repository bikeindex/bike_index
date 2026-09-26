# frozen_string_literal: true

require "rails_helper"

RSpec.describe BikeServices::RegisterFlow do
  let(:flow) { described_class.new(steps: %w[1 2 report 3 review]) }

  it "walks its steps in order" do
    expect(flow.single_page?).to be_falsey
    expect(flow.acknowledgments?).to be_truthy
    expect(flow.count).to eq 5
    expect(flow.position("report")).to eq 3
    expect(flow.position(2)).to eq 2
    expect(flow.after("report")).to eq "3"
    expect(flow.before("report")).to eq "2"
    # Nothing comes before or after the ends
    expect(flow.before("1")).to be_nil
    expect(flow.after("review")).to be_nil
  end

  context "the single page, without a sequence" do
    let(:flow) { described_class.new(steps: %w[1], single_page: true) }

    it "is one step" do
      expect(flow.single_page?).to be_truthy
      expect(flow.acknowledgments?).to be_falsey
      expect(flow.count).to eq 1
    end
  end
end
