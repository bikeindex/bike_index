# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Select::Component, type: :component do
  let(:user) { User.new }
  let(:form_builder) do
    BikeIndexFormBuilder.new(:user, user, ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil), {})
  end
  let(:component) do
    render_inline(described_class.new(form_builder:, attribute: :name, option_tags:, options:, required:, html_options:))
  end
  let(:option_tags) { [["Red", "1"], ["Blue", "2"]] }
  let(:options) { {} }
  let(:required) { false }
  let(:html_options) { {} }

  it "renders a twinput select of the option tags" do
    expect(component).to have_css("select.twinput[name='user[name]']")
    expect(component).to have_css("option[value='1']", text: "Red")
    expect(component).to have_css("option[value='2']", text: "Blue")
    expect(component).to_not have_css("select[required]")
  end

  context "with options" do
    let(:options) { {selected: "2", include_blank: "Pick one"} }

    it "marks the selected option and prepends the blank" do
      expect(component).to have_css("option[value='2'][selected]", text: "Blue")
      expect(component).to have_css("option[value='']", text: "Pick one")
    end
  end

  context "when required" do
    let(:required) { true }

    it "marks the select required" do
      expect(component).to have_css("select[required]")
    end
  end

  context "with a class in html_options" do
    let(:html_options) { {class: "tw:font-mono"} }

    it "appends to twinput rather than replacing it" do
      expect(component).to have_css("select.twinput.tw\\:font-mono")
    end
  end
end
