# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::TextEditor::Component, type: :component do
  let(:record) { OrganizationFeature.new(feature_slugs: ["<p>one</p>"]) }

  def rendered_component(record)
    render_in_view_context do
      form_for record, url: "#", method: :patch do |f|
        render(Form::TextEditor::Component.new(form_builder: f, attribute: :feature_slugs))
      end
    end
  end

  let(:component) { rendered_component(record) }

  it "renders a single-line Lexxy editor bound to the array attribute plus an add button" do
    expect(component).to have_css("[data-controller='nested-form']")
    expect(component).to have_css("lexxy-editor[multi-line='false'][name='organization_feature[feature_slugs][]']")
    expect(component).to have_button("Add feature slug")
  end
end
