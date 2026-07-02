# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSequence::PageEditBullet::Component, type: :component do
  it "names the editor for the given index, prefills the content, and renders the row controls" do
    render_inline(described_class.new(index: 2, value: "ride safely"))

    expect(page).to have_css("lexxy-editor[name='bullet[2][content]'][value*='ride safely']", visible: :all)
    expect(page).to have_css("[data-bullet-editors-target='item'] [data-bullet-editors-target='handle']", visible: :all)
    expect(page).to have_css("[data-action~='bullet-editors#remove']", visible: :all)
  end

  it "uses the placeholder index for the clone template" do
    render_inline(described_class.new(index: "__INDEX__"))

    expect(page).to have_css("lexxy-editor[name='bullet[__INDEX__][content]']", visible: :all)
  end
end
