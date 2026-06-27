# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::TextEditor::Component, type: :component do
  let(:record) { OrganizationFeature.new(description: "<p>Hello</p>") }

  def rendered_component(record, **options)
    render_in_view_context do
      form_for record, url: "#", method: :patch do |f|
        render(Form::TextEditor::Component.new(form_builder: f, attribute: :description, **options))
      end
    end
  end

  it "renders a single normal-size Lexxy editor bound to the attribute, with an associated label" do
    component = rendered_component(record)

    expect(component).to have_css("lexxy-editor[name='organization_feature[description]'][id='organization_feature_description']")
    expect(component).to have_css("label[for='organization_feature_description']", text: "Description")
    expect(component).to_not have_css("lexxy-editor.lexxy-editor--compact")
    expect(component).to have_css("lexxy-editor[multi-line='false']")
  end

  context "size: :small" do
    it "adds the compact modifier class" do
      expect(rendered_component(record, size: :small)).to have_css("lexxy-editor.lexxy-editor--compact")
    end
  end

  context "multi_line: true" do
    it "renders the editor with multi-line enabled" do
      expect(rendered_component(record, multi_line: true)).to have_css("lexxy-editor[multi-line='true']")
    end
  end
end
