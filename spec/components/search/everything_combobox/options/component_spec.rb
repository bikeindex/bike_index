# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::EverythingCombobox::Options::Component, type: :component do
  let(:rendered) { render_inline(described_class.new(matches:, search_obj_name: "Registrations", next_page: nil)) }

  context "with a color match" do
    let(:matches) { [{"search_id" => "c_1", "text" => "Blue", "category" => "colors", "display" => "#00f"}] }

    it "renders an option with the color swatch and 'that are' prefix" do
      expect(rendered.css(".hw-combobox__option").size).to eq 1
      expect(rendered.css(".hw-combobox__option .sch_").text).to include("Registrations that are")
      expect(rendered.css(".hw-combobox__option .sclr").attr("style").value).to include("background: #00f")
      expect(rendered.css(".hw-combobox__option .label").text).to eq "Blue"
    end
  end

  context "with a manufacturer match" do
    let(:matches) { [{"search_id" => "m_2", "text" => "Trek", "category" => "frame_mnfg"}] }

    it "renders a 'made by' prefix" do
      expect(rendered.css(".hw-combobox__option .sch_").text).to eq "Registrations made by"
      expect(rendered.css(".hw-combobox__option .label").text).to eq "Trek"
    end
  end

  context "with a cycle_type match" do
    let(:matches) { [{"search_id" => "v_3", "text" => "Tricycle", "category" => "cycle_type"}] }

    it "renders 'Search only for'" do
      expect(rendered.css(".hw-combobox__option").text).to include("Search only for")
      expect(rendered.css(".hw-combobox__option strong").text).to eq "Tricycle"
    end
  end

  context "with a query" do
    let(:matches) { [{"search_id" => "c_1", "text" => "Blue", "category" => "colors", "display" => "#00f"}] }
    let(:rendered) { render_inline(described_class.new(matches:, search_obj_name: "Registrations", next_page: nil, q: "blu")) }

    it "appends a 'Search for' synthetic option after the real matches" do
      options = rendered.css(".hw-combobox__option")
      expect(options.size).to eq 2
      expect(options.last.attr("id")).to eq "hw_search_for_option"
      expect(options.last.text).to include("Search for")
      expect(options.last.css(".label").text).to eq "blu"
    end

    context "on a non-first page" do
      it "omits the synthetic option" do
        rendered = with_request_url("/search/combobox/options?page=2") do
          render_inline(described_class.new(matches:, search_obj_name: "Registrations", next_page: nil, q: "blu"))
        end
        expect(rendered.css("#hw_search_for_option")).to be_empty
      end
    end
  end

  it "escapes HTML in the match text" do
    payload = '<img src=x onerror="document.body.dataset.xss=1">'
    rendered = render_inline(described_class.new(
      matches: [{"search_id" => "c_9", "text" => payload, "category" => "colors", "display" => nil}],
      search_obj_name: "Registrations", next_page: nil
    ))

    # No <img> element should be parsed out of the payload - it should land
    # as text in the label or as an escaped attribute value
    expect(rendered.css("img")).to be_empty
    expect(rendered.css(".hw-combobox__option .label").text).to eq payload
  end
end
