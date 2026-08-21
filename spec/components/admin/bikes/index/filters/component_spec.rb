# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Bikes::Index::Filters::Component, type: :component do
  let(:search_params) { {} }
  let(:index) do
    ComponentStates::IndexState.new(params: search_params,
      sort_state: ComponentStates::SortState.new(search_params:))
  end
  let(:options) { {} }
  let(:component) do
    with_request_url("/admin/bikes") do
      render_inline(described_class.new(index:, **options))
    end
  end

  def nav_link(text)
    component.css("a.nav-link").find { |link| link.text.squish == text }
  end

  # The dropdown button carries an sr-only "Open <name> menu" ahead of its name
  def dropdown_names
    component.css("button").map { |button| button.text.squish }
  end

  # The admin row styles .nav-link.active - UI::ActiveLink only sets aria-current, which
  # it doesn't style, so these carry the class themselves from the state passed in
  it "marks no toggle active by default" do
    expect(nav_link("motorized")["class"]).to eq "nav-link"
    expect(nav_link("multi-delete")["class"]).to eq "nav-link"
  end

  context "with motorized on" do
    let(:options) { {motorized: true} }

    it "marks motorized active, and links to turning it off" do
      expect(nav_link("motorized")["class"]).to eq "nav-link active"
      expect(nav_link("motorized")["href"]).to include "search_motorized=false"
    end
  end

  context "with multi_delete on" do
    let(:options) { {multi_delete: true} }

    it "marks multi-delete active" do
      expect(nav_link("multi-delete")["class"]).to eq "nav-link active"
    end
  end

  describe "the POS dropdown" do
    it "names itself POS, and every entry clears or applies one value" do
      expect(dropdown_names).to include a_string_ending_with("menu POS")
      expect(component.css("a").map { |a| a.text.squish })
        .to include("Ascend", "Lightspeed", "POS of any type", "Not POS", "any (POS or not)")
    end

    context "with a pos type searched" do
      let(:options) { {pos_search_type: "ascend_pos"} }

      # Its entries link to the value they apply, so an active one has to clear it
      it "names the type and offers to clear it" do
        expect(dropdown_names).to include a_string_ending_with("menu Ascend pos")
        ascend = component.css("a").find { |a| a.text.squish == "Ascend" }
        expect(ascend["href"]).to_not include "search_pos"
      end
    end
  end

  context "with an origin searched" do
    let(:options) { {origin_search_type: "web"} }

    it "names it on the dropdown" do
      expect(dropdown_names).to include a_string_ending_with("menu Web")
    end
  end
end
