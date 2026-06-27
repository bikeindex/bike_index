# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::TextEditor::Component, type: :component do
  let(:record) { OrganizationFeature.new(description: "<p>Hello</p>") }

  def rendered_component(record)
    render_in_view_context do
      form_for record, url: "#", method: :patch do |f|
        render(Form::TextEditor::Component.new(form_builder: f, attribute: :description))
      end
    end
  end

  let(:component) { rendered_component(record) }

  it "renders a single Lexxy editor bound to the attribute, with an associated label" do
    expect(component).to have_css("lexxy-editor[name='organization_feature[description]'][id='organization_feature_description']")
    expect(component).to have_css("label[for='organization_feature_description']", text: "Description")
  end
end
