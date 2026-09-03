# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::ButtonGroup::Component, type: :component do
  let(:entries) { [{label: "All", href: "/all"}, {label: "Active", href: "/active", active: true}] }
  let(:component) { render_inline(described_class.new(entries:)) }

  it "renders a link per entry, flagging the active one" do
    expect(component).to have_css("a", count: 2)
    expect(component).to have_css("a[href='/all']", text: "All")
    expect(component).to have_css("a[href='/active'][data-active='true'][aria-current='true']", text: "Active")
    expect(component).to have_no_css("a[href='/all'][data-active]")
    expect(component).to have_css("div.tw\\:flex-wrap")
  end

  it "renders html labels" do
    expect(render_inline(described_class.new(entries: [{label: "only <strong>not</strong> impounded", href: "/x"}]))).to have_css("a span strong", text: "not")
  end

  # Equality, not include: an extra utility here is a visual difference from the button
  it "styles the chips as UI::Button's secondary" do
    expect(component.css("a").first["class"]).to eq(UI::Button::Component.build_classes(color: :secondary, size: :md))
  end

  context "entries without an href" do
    let(:entries) { [{label: "Map", active: true, data: {action: "click->map#show"}}, {label: "List"}] }

    it "renders buttons that don't submit, keeping the passed data attributes" do
      expect(component).to have_css("button[type='button']", count: 2)
      expect(component).to have_css("button[data-active='true'][aria-pressed='true'][data-action='click->map#show']", text: "Map")
    end
  end

  context "disabled entries" do
    let(:entries) { [{label: "All", href: "/all"}, {label: "For sale", href: "/for_sale", disabled: true}] }

    # An <a> takes no disabled attribute, so the chip has to be a button to be inert
    it "renders a disabled button rather than a link" do
      expect(component).to have_css("a", count: 1)
      expect(component).to have_css("button[type='button'][disabled]", text: "For sale")
    end
  end

  context "full_width" do
    let(:component) do
      render_inline(described_class.new(full_width: true,
        entries: %w[xs s m l xl].map { |size| {label: size.upcase, href: "/#{size}", active: size == "m"} }))
    end

    it "lays the chips out as evenly sized columns that wrap" do
      expect(component).to have_css("a", count: 5)
      expect(component.css("div").first["class"]).to include("repeat(auto-fit,minmax(4rem,1fr))")
    end
  end
end
