# frozen_string_literal: true

require "rails_helper"

RSpec.describe MemberBadge::Component, type: :component do
  let(:options) { {level:} }
  let(:level) { nil }
  let(:component) { render_inline(described_class.new(**options)) }

  it "doesn't renders" do
    expect(described_class.new(**options).render?).to be_falsey
  end

  context "basic" do
    let(:level) { "basic" }
    it "renders" do
      expect(component).to be_present
    end
  end

  context "plus" do
    let(:level) { "plus" }
    it "renders" do
      expect(component).to be_present
    end
  end

  context "patron" do
    let(:level) { "patron" }
    it "renders" do
      expect(component).to be_present
    end
  end
end
