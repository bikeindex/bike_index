# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::AddFields::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let(:fields) { ->(builder) { builder.text_field(:name) } }
  let(:options) { {class_name: "twlink"} }

  def rendered_link(organization, fields, options)
    rendered = render_in_view_context do
      form_for [:admin, organization] do |f|
        render(UI::Forms::AddFields::Component.new(name: "Add a location", form_builder: f,
          association: :locations, fields:, **options))
      end
    end
    rendered.at_css("a[data-controller='ui--forms--add-fields']")
  end

  let(:link) { rendered_link(organization, fields, options) }
  let(:added) { Nokogiri::HTML.fragment(link["data-ui--forms--add-fields-fields-value"]) }

  it "renders the link with the blank fields the controller inserts" do
    expect(link.text).to eq "Add a location"
    expect(link["class"]).to eq "twlink"
    expect(link["data-action"]).to eq "click->ui--forms--add-fields#add"
    # The controller swaps the placeholder for a unique index, so it has to survive to the browser
    expect(added.css("input").map { |input| input["name"] })
      .to eq ["organization[locations_attributes][__INDEX__][name]"]
  end

  it "builds the new record blank, rather than reusing a saved one" do
    FactoryBot.create(:location, organization:, name: "Main Office")

    expect(added.css("input").map { |input| input["value"] }.compact).to be_empty
  end

  context "with obj_attrs" do
    let(:options) { {obj_attrs: {name: "New location"}} }

    it "builds the new record with them" do
      expect(added.at_css("input")["value"]).to eq "New location"
    end
  end
end
