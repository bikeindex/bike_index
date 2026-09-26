# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pages::Register::Step1::Component, type: :component do
  let(:b_param) { BParam.create(origin: "register_flow", params: {bike: {owner_email: "owner@bikeindex.org"}}.as_json) }
  let(:single_page) { false }

  def render_step_1(**options)
    render_inline(described_class.new(b_param:, **options,
      flow: BikeServices::Register.flow(b_param, sequence: nil, single_page:)))
  end

  context "single_page" do
    let(:single_page) { true }

    it "renders nothing - the single page ends in step 2's submit" do
      expect(render_step_1.to_html).to be_blank
    end
  end

  describe "button_color" do
    def submit_button
      page.find("button[type=submit]")
    end

    it "colors the button, hovering a shade darker" do
      render_step_1(button_color: "#c9a227")

      expect(submit_button["style"])
        .to eq "background-color: #c9a227; border-color: #c9a227; --button-hover-color: #a78620"
    end

    # UI::Button guards every hover against both disabled flags, and an !important
    # would outrank that guard rather than inherit it
    it "guards the hover the way UI::Button's own colors are guarded" do
      render_step_1(button_color: "#c9a227")
      hovers = submit_button["class"].split.grep(/hover:.+--button-hover-color/)

      expect(hovers.count).to eq 2
      expect(hovers.grep_v(/\Atw:not-disabled:not-aria-disabled:hover:/)).to eq([])
    end

    it "takes a hover color rather than deriving one" do
      render_step_1(button_color: "#c9a227", button_hover_color: "#123456")

      expect(submit_button["style"]).to include "--button-hover-color: #123456"
    end

    it "leaves the style off without one" do
      render_step_1

      expect(submit_button["style"]).to be_nil
      expect(submit_button["class"]).to_not include "--button-hover-color"
    end
  end
end
