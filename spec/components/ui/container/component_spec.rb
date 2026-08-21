# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Container::Component, type: :component do
  def classes(**options)
    render_inline(described_class.new(**options)) { "content".html_safe }.at_css("div")["class"]
  end

  it "caps the width, centering unless aligned left, and adds no padding" do
    expect(classes).to eq "tw:w-full tw:max-w-3xl tw:mx-auto"
    expect(classes(width: :wide)).to eq "tw:w-full tw:max-w-7xl tw:mx-auto"
    expect(classes(alignment: :left)).to eq "tw:w-full tw:max-w-3xl"
    # The page owns the gutter (.twgutter), so nesting these can't compound padding
    expect(described_class::WIDTHS.map { |width| classes(width:) }.join).to_not include("px-")
  end

  it "raises on values it has no layout for" do
    expect { described_class.new(width: :huge) }.to raise_error(ArgumentError, /huge/)
    expect { described_class.new(alignment: :justify) }.to raise_error(ArgumentError, /justify/)
  end
end
