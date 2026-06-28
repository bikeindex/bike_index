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

    expect(component).to have_css("lexxy-editor[name='organization_feature[description]'][id='organization_feature_description']")
    # The label is supplied by Form::Group, not this component
    expect(component).to_not have_css("label")
    expect(component).to_not have_css("lexxy-editor.lexxy-editor--compact")
  end

  it "adds the lexxy controller and stylesheet value by default" do
    expect(rendered_component(record))
      .to have_css("lexxy-editor[data-controller='lexxy'][data-lexxy-stylesheet-value*='lexxy']")
  end

  context "size: :single_line" do
    it "adds the compact modifier class and defaults to the trimmed toolbar" do
      component = rendered_component(record, size: :single_line)

      expect(component).to have_css("lexxy-editor.lexxy-editor--compact")
      # defaults to SINGLE_LINE_TOOLBAR_BUTTONS -- the omitted buttons get a hide class
      expect(component).to have_css("lexxy-editor.lexxy-editor--hide-strikethrough.lexxy-editor--hide-table.lexxy-editor--hide-heading")
      expect(component).to have_no_css("lexxy-editor.lexxy-editor--hide-bold")
      expect(component).to have_no_css("lexxy-editor.lexxy-editor--hide-link")
    end
  end

  context "with toolbar_buttons:" do
    it "hides the buttons that aren't listed" do
      component = rendered_component(record, toolbar_buttons: %i[bold italic])

      expect(component).to have_css("lexxy-editor.lexxy-editor--hide-link.lexxy-editor--hide-undo")
      expect(component).to have_no_css("lexxy-editor.lexxy-editor--hide-bold")
      expect(component).to have_no_css("lexxy-editor.lexxy-editor--hide-italic")
    end
  end

  context "with an unsupported size" do
    it "raises ArgumentError" do
      expect { described_class.new(form_builder: nil, attribute: :description, size: :enormous) }
        .to raise_error(ArgumentError, /size must be one of/)
    end
  end
end
