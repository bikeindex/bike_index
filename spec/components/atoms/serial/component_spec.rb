# frozen_string_literal: true

require "rails_helper"

RSpec.describe Atoms::Serial::Component, type: :component do
  let(:instance) { described_class.new(bike:, **options) }
  let(:component) { render_inline(instance) }
  let(:options) { {} }
  let(:bike) { FactoryBot.create(:bike, serial_number: "FFF333") }

  it "renders the serial" do
    expect(component.to_html.strip).to eq '<span class="serial-span">FFF333</span>'
  end

  context "serial unknown" do
    let(:bike) { FactoryBot.create(:bike, serial_number: "unknown") }

    it "renders the word rather than the number" do
      expect(component.to_html.strip).to eq '<span class="less-strong">unknown</span>'
    end
  end

  context "made without serial" do
    let(:bike) { FactoryBot.create(:bike, made_without_serial: true) }

    it "renders made without serial" do
      expect(component.to_html.strip).to eq '<span class="less-strong">made without serial</span>'
    end
  end

  context "hidden serial" do
    let(:bike) { FactoryBot.create(:bike, serial_number: "FFF333", cycle_type: :tandem) }
    before { bike.status = "status_impounded" }

    it "hides the serial and explains why" do
      expect(component.to_html.strip)
        .to eq '<span class="less-strong">hidden</span> <em class="small less-less-strong">because tandem is impounded</em>'
    end

    context "with skip_explanation" do
      let(:options) { {skip_explanation: true} }

      it "hides the serial without the explanation" do
        expect(component.to_html.strip).to eq '<span class="less-strong">hidden</span>'
      end
    end

    context "for a user who may see it" do
      let(:options) { {user: FactoryBot.create(:superuser)} }

      it "shows the serial with the unauthorized-users note" do
        expect(component.to_html.strip)
          .to eq '<span class="serial-span">FFF333</span> <em class="small less-less-strong">hidden for unauthorized users</em>'
      end

      context "with skip_explanation" do
        let(:options) { super().merge(skip_explanation: true) }

        it "shows the serial alone" do
          expect(component.to_html.strip).to eq '<span class="serial-span">FFF333</span>'
        end
      end
    end
  end

  context "no serial" do
    let(:bike) { Bike.new }

    it "renders nothing" do
      expect(component.to_html).to be_blank
    end
  end

  context "with a bike_version" do
    let(:bike) { FactoryBot.create(:bike_version, bike: FactoryBot.create(:bike, serial_number: "FFF333")) }

    it "renders the serial" do
      expect(component.to_html.strip).to eq '<span class="serial-span">FFF333</span>'
    end
  end

  context "with a serial rather than a bike" do
    let(:instance) { described_class.new(serial: "FFF333", **options) }

    it "renders the serial" do
      expect(component.to_html.strip).to eq '<span class="serial-span">FFF333</span>'
    end

    context "with html_class" do
      let(:options) { {html_class: "tw:underline!"} }

      it "adds the class to the span" do
        expect(component.to_html.strip).to eq '<span class="serial-span tw:underline!">FFF333</span>'
      end
    end

    context "matching a placeholder" do
      let(:instance) { described_class.new(serial: "unknown", **options) }

      it "renders the serial rather than the placeholder" do
        expect(component.to_html.strip).to eq '<span class="serial-span">unknown</span>'
      end
    end
  end
end
