# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::NestedFields::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let!(:location) { FactoryBot.create(:location, organization:, name: "Main Office") }
  let(:options) { {} }

  def rendered(organization, options)
    render_in_view_context do
      form_for [:admin, organization] do |f|
        render(UI::Forms::NestedFields::Component.new(form_builder: f, association: :locations,
          fields_component: UI::Forms::NestedFields::PreviewFields::Component,
          add_label: "Add a location", **options))
      end
    end
  end

  let(:component) { rendered(organization, options) }
  let(:template) { Nokogiri::HTML.fragment(component.at_css("template").inner_html) }
  # Nokogiri treats a template's content as ordinary children, so drop it to see only what renders
  let(:rendered_fields) { component.dup.tap { |fragment| fragment.css("template").remove } }

  it "renders the saved records, a blank set in the template, and the add button" do
    expect(component.at_css("button[data-action='click->ui--forms--nested-fields#add']").text).to eq "Add a location"
    expect(component).to have_css("[data-ui--forms--nested-fields-target='target']")
    # The wrapper class is the component's, so it hands the controller the selector for it
    expect(component.at_css("[data-controller]")["data-ui--forms--nested-fields-wrapper-selector-value"])
      .to eq ".nested-fields-wrapper"

    saved = rendered_fields.css(".nested-fields-wrapper")
    expect(saved.map { |wrapper| wrapper["data-new-record"] }).to eq ["false"]
    expect(saved.at_css("input[name$='[name]']")["value"]).to eq "Main Office"
  end

  it "builds the template's record blank, indexed by the placeholder the controller replaces" do
    expect(template.at_css(".nested-fields-wrapper")["data-new-record"]).to eq "true"
    expect(template.at_css("input[name$='[name]']")["name"])
      .to eq "organization[locations_attributes][__INDEX__][name]"
    expect(template.at_css("input[name$='[name]']")["value"]).to be_blank
    expect(template.at_css("input[name$='[_destroy]']")).to be_present
  end

  context "with class_name, add_class_name, fields_class_name and obj_attrs" do
    let(:options) do
      {class_name: "row mt-4", add_class_name: "mx-auto", fields_class_name: "col-md-6",
       obj_attrs: {name: "New location"}}
    end

    it "passes them through" do
      expect(component.at_css("[data-controller]")["class"]).to eq "row mt-4"
      expect(component).to have_css("button.mx-auto[data-action*='#add']")
      expect(rendered_fields.at_css(".nested-fields-wrapper")["class"]).to eq "nested-fields-wrapper col-md-6"
      expect(template.at_css("input[name$='[name]']")["value"]).to eq "New location"
    end
  end
end
