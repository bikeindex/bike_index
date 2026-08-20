# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Container::Component, type: :component do
  def classes(**options)
    render_inline(described_class.new(**options)) { "content".html_safe }.at_css("div")["class"]
  end

  it "centers a single column at the narrower width" do
    expect(classes).to eq "tw:w-full tw:max-w-3xl tw:mx-auto"
  end

  it "gives two columns the wider one to share" do
    expect(classes(columns: 2)).to eq "tw:w-full tw:max-w-7xl tw:mx-auto"
  end

  it "leaves the slack on the right when aligned left" do
    expect(classes(alignment: :left)).to eq "tw:w-full tw:max-w-3xl"
  end

  # It's the page's outermost container, so it carries the gutter the capped ones nest inside
  it "caps nothing when full width, so there is nothing to center, and owns the gutter" do
    expect(classes(full_width: true)).to eq "tw:w-full tw:px-4"
  end

  it "renders its content" do
    expect(render_inline(described_class.new) { "content".html_safe }).to have_content("content")
  end

  it "raises on values it has no layout for" do
    expect { described_class.new(columns: 3) }.to raise_error(ArgumentError, /3/)
    expect { described_class.new(alignment: :justify) }.to raise_error(ArgumentError, /justify/)
  end
end
