# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::TextEditor::Component, type: :component do
  let(:record) { OrganizationFeature.new(description: "<p>Hello</p>") }

  def rendered_component(record, **options)
    render_in_view_context do
      form_for record, url: "#", method: :patch do |f|
        render(UI::Forms::TextEditor::Component.new(form_builder: f, attribute: :description, **options))
      end
    end
  end

  it "renders just the default multi-line Lexxy editor box bound to the attribute (no label)" do
    component = rendered_component(record)

    expect(component).to have_css("lexxy-editor[name='organization_feature[description]'][id='organization_feature_description']")
    # The label is supplied by UI::Forms::Group, not this component
    expect(component).to_not have_css("label")
    expect(component).to_not have_css("lexxy-editor.lexxy-editor--compact")
  end

  it "adds the controller and stylesheet value by default" do
    expect(rendered_component(record))
      .to have_css("lexxy-editor[data-controller='ui--forms--text-editor'][data-ui--forms--text-editor-stylesheet-value*='lexxy']")
  end

  it "derives the standalone editor's accessible name from the attribute (Lexxy copies aria-label onto the box)" do
    expect(rendered_component(record)).to have_css("lexxy-editor[aria-label='Description']")
  end

  context "standalone: false" do
    it "omits aria-label so the paired UI::Forms::Group label is the accessible name" do
      expect(rendered_component(record, standalone: false)).to have_no_css("lexxy-editor[aria-label]")
    end
  end

  context "size: :single_line" do
    it "adds the compact modifier class and defaults to the trimmed toolbar" do
      component = rendered_component(record, size: :single_line)

      expect(component).to have_css("lexxy-editor.lexxy-editor--compact")
      # defaults to SINGLE_LINE_TOOLBAR_BUTTONS -- the omitted buttons get a hide class
      expect(component).to have_css("lexxy-editor.lexxy-editor--hide-strikethrough.lexxy-editor--hide-table.lexxy-editor--hide-format")
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

  # The hide classes only do anything if lexxy_overrides.css carries a matching rule, and a button
  # added here without one would fail silently -- it just wouldn't hide.
  it "has a stylesheet rule for every toolbar button" do
    stylesheet = Rails.root.join("app/assets/tailwind/lexxy_overrides.css").read
    ruled = stylesheet.scan(/\.lexxy-editor--hide-([a-z-]+)/).flatten.uniq

    expect(ruled).to match_array(described_class::TOOLBAR_BUTTONS.map { it.to_s.tr("_", "-") })
  end

  context "with an unsupported size" do
    it "raises ArgumentError" do
      expect { described_class.new(form_builder: nil, attribute: :description, size: :enormous) }
        .to raise_error(ArgumentError, /size must be one of/)
    end
  end

  context "with an unknown toolbar_button" do
    it "raises ArgumentError" do
      expect { described_class.new(form_builder: nil, attribute: :description, toolbar_buttons: %i[bold sparkles]) }
        .to raise_error(ArgumentError, /unknown toolbar_buttons.*sparkles/)
    end
  end
end
