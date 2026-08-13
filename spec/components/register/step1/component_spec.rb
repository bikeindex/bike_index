# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::Step1::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization, short_name: "Brakebills") }
  let(:params) { {bike: {owner_email: "owner@bikeindex.org", creation_organization_id: organization.id}} }
  let(:b_param) { BParam.create(origin: "register_flow", params: params.as_json) }

  # Reloaded, so an organization updated mid-example isn't answered from the copy
  # the previous render left on the registration
  def render_step_1(**options)
    reloaded = b_param.reload
    render_inline(described_class.new(b_param: reloaded, **options,
      steps: BikeServices::Register.steps(reloaded, sequence: nil)))
  end

  def email_placeholder
    page.find("input[name='b_param[owner_email]']")["placeholder"]
  end

  describe "the email placeholder" do
    # The same setting the legacy embed form reads, so a university asking for the
    # campus address keeps asking for it here
    it "takes the organization's, and falls back to the example address" do
      render_step_1
      expect(email_placeholder).to eq "you@example.com"

      # A school has a name worth asking by, without anyone setting one
      organization.update(kind: "school")
      render_step_1
      expect(email_placeholder).to eq "Brakebills email"

      # The label set in admin wins over the school's name
      organization.update(registration_field_labels: {owner_email: "brakebills.edu email"})
      render_step_1
      expect(email_placeholder).to eq "brakebills.edu email"
    end

    it "is the example address without an organization" do
      b_param.update(params: {bike: {owner_email: "owner@bikeindex.org"}}.as_json)
      render_step_1

      expect(email_placeholder).to eq "you@example.com"
    end
  end

  describe "button_color" do
    def submit_button
      page.find("form button[type=submit]")
    end

    it "colors the button, hovering a shade darker" do
      render_step_1(button_color: "#c9a227")

      expect(submit_button["style"])
        .to eq "background-color: #c9a227; border-color: #c9a227; --button-hover-color: hsla(46, 68%, 39%, 1)"
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
