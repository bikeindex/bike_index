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

  # Equality, not include: any utility beyond the tighter line height is a visual difference from the button
  it "styles the chips as UI::Button's secondary, with a tighter line height" do
    expect(component.css("a").first["class"]).to eq("#{UI::Button::Component.build_classes(color: :secondary, size: :md)} tw:leading-4")
  end

  it "raises on a kind it doesn't have" do
    expect { described_class.new(entries:, kind: :segmented) }
      .to raise_error(ArgumentError, /unknown kind :segmented/)
  end

  it "raises on a full_width it can't honor" do
    expect { described_class.new(entries:, kind: :toggle, full_width: true) }
      .to raise_error(ArgumentError, /full_width is not supported/)
  end

  context "kind: toggle" do
    let(:component) { render_inline(described_class.new(entries:, kind: :toggle)) }

    # One row, so no flex-wrap — the button kind's chips wrap
    it "renders the entries as segments of a single track" do
      expect(component).to have_css("div.tw\\:bg-gray-100")
      expect(component).to have_no_css("div.tw\\:flex-wrap")
      expect(component).to have_css("a.tw\\:font-extrabold", count: 2)
    end
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
