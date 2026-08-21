# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::Organizations::Form::Locations::Component, type: :component do
  let(:organization) { FactoryBot.create(:organization) }
  let!(:location) { FactoryBot.create(:location, organization:, name: "Main Office") }

  def rendered_component(organization)
    render_in_view_context do
      form_for [:admin, organization] do |f|
        render(Admin::Organizations::Form::Locations::Component.new(form_builder: f))
      end
    end
  end

  let(:component) { rendered_component(organization) }

  it "renders the location fields, and a blank set in the nested-fields template" do
    expect(component).to have_field("organization_locations_attributes_0_name", with: "Main Office")
    expect(component).to have_field("organization_locations_attributes_0_address_record_attributes_city")

    # ui--forms--nested-fields clones this into the page, so it has to be exactly one blank location
    template = Nokogiri::HTML.fragment(component.at_css("template").inner_html)
    expect(template.css("fieldset").length).to eq 1
    expect(template.css("input.twinput[name*='locations_attributes']").length).to be > 1
    expect(template.css("[name='organization[name]']")).to be_empty
    expect(template.text).not_to match "Main Office"
  end
end
