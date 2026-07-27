# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atom::Serial::Component, type: :component do
  let(:instance) { described_class.new(bike:, **options) }
  let(:component) { render_inline(instance) }
  let(:options) { {} }
  let(:bike) { FactoryBot.create(:bike, serial_number: "FFF333") }

  it "renders the serial in a monospace code block" do
    expect(component).to have_css("code", text: "FFF333")
    expect(component.to_html).to include("tw:font-mono")
  end

  context "serial unknown" do
    let(:bike) { FactoryBot.create(:bike, serial_number: "unknown") }

    it "renders the word rather than a code block" do
      expect(component).to have_css("span", text: "unknown")
      expect(component).to have_no_css("code")
    end
  end

  context "made without serial" do
    let(:bike) { FactoryBot.create(:bike, made_without_serial: true) }

    it "renders the made-without-serial text" do
      expect(component).to have_text("made without serial")
    end
  end

  context "hidden serial" do
    before { bike.status = "status_impounded" }

    it "hides the serial and explains why" do
      expect(component).to have_no_text("FFF333")
      expect(component).to have_text("hidden")
      expect(component).to have_css("em", text: "because bike is impounded")
    end

    context "with skip_explanation" do
      let(:options) { {skip_explanation: true} }

      it "hides the serial without the explanation" do
        expect(component).to have_no_text("FFF333")
        expect(component).to have_no_css("em")
      end
    end

    context "for a user who may see it" do
      let(:options) { {user: FactoryBot.create(:superuser)} }

      it "shows the serial with the unauthorized-users note" do
        expect(component).to have_css("code", text: "FFF333")
        expect(component).to have_css("em", text: "hidden for unauthorized users")
      end
    end
  end
end
