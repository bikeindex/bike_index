# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Range::Component, type: :component do
  let(:component) { render_inline(described_class.new(**options)) }
  let(:options) { {name: :geometry, label: "Geometry", value: 4, max: 5} }

  it "renders a slider under its label, showing its value" do
    expect(component).to have_css("[data-controller='ui--forms--range'] label[for='geometry'] output[for='geometry']", text: "4")
    expect(component).to have_css("input[type='range'][id='geometry'][name='geometry'][min='0'][max='5'][step='1'][value='4']")
    expect(component).to have_css("input[data-action='input->ui--forms--range#update']")
  end

  it "labels no ends without them" do
    expect(component).to have_no_css("input + div")
  end

  context "with end labels" do
    let(:options) { {name: :year, label: "Year", value: 2, max: 5, min_label: "Ignore year", max_label: "Only same year"} }

    it "says what each end means beneath the slider" do
      expect(component).to have_css("input[type='range'] + div.tw\\:text-xs span:first-child", exact_text: "Ignore year")
      expect(component).to have_css("input[type='range'] + div span:last-child", exact_text: "Only same year")
    end
  end

  context "with html_options" do
    let(:options) do
      {name: :ratio, label: "Ratio", value: 1.4, min: 1, max: 2, step: 0.05,
       html_options: {id: "similar-ratio", class: "tw:mt-1", data: {action: "input->similar#change", "similar-target": "weight"}}}
    end

    it "puts them on the input, its action beside the component's" do
      expect(component).to have_css("label[for='similar-ratio'] output[for='similar-ratio']", text: "1.4")
      expect(component).to have_css("input#similar-ratio.tw\\:mt-1.tw\\:w-full[step='0.05'][data-similar-target='weight']")
      expect(component).to have_css("input[data-action='input->ui--forms--range#update input->similar#change']")
    end
  end
end
