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

  it "renders just the default multi-line Lexxy editor box bound to the attribute (no label)" do
    component = rendered_component(record)

    expect(component).to have_css("lexxy-editor[name='organization_feature[description]'][id='organization_feature_description'][multi-line='true']")
    # The label is supplied by Form::Group, not this component
    expect(component).to_not have_css("label")
    expect(component).to_not have_css("lexxy-editor.lexxy-editor--compact")
  end

  it "adds the lexxy controller and stylesheet value by default" do
    expect(rendered_component(record))
      .to have_css("lexxy-editor[data-controller='lexxy'][data-lexxy-stylesheet-value*='lexxy']")
  end

  context "skip_assets: true" do
    it "omits the lexxy controller (assets loaded by another editor on the page)" do
      component = rendered_component(record, skip_assets: true)

      expect(component).to have_css("lexxy-editor")
      expect(component).to_not have_css("lexxy-editor[data-controller]")
    end
  end

  context "size: :single_line" do
    it "adds the compact modifier class and disables multi-line" do
      component = rendered_component(record, size: :single_line)

      expect(component).to have_css("lexxy-editor.lexxy-editor--compact[multi-line='false']")
    end
  end
end
