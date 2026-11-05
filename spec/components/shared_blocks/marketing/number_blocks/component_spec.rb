# frozen_string_literal: true

require "rails_helper"

RSpec.describe SharedBlocks::Marketing::NumberBlocks::Component, type: :component do
  let(:component) { render_inline(described_class.new(items: [["17,387", "stolen bikes recovered"], ["$0", "to register"]])) }

  it "renders each label as the term and its value as the definition" do
    expect(component.css("dt").map { it.text.strip }).to eq(["stolen bikes recovered", "to register"])
    expect(component.css("dd").map { it.text.strip }).to eq(["17,387", "$0"])
  end
end
