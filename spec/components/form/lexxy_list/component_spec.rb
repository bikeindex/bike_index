# frozen_string_literal: true

require "rails_helper"

RSpec.describe Form::LexxyList::Component, type: :component do
  let(:record) { RegistrationSequencePage.new(bullet_points: ["<p>one</p>"]) }

  def rendered_component(record)
    render_in_view_context do
      form_for record, url: "#", method: :patch do |f|
        render(Form::LexxyList::Component.new(form_builder: f, attribute: :bullet_points))
      end
    end
  end

  let(:component) { rendered_component(record) }

  it "renders a single-line Lexxy editor bound to the array attribute plus an add button" do
    expect(component).to have_css("[data-controller='nested-form']")
    expect(component).to have_css("lexxy-editor[multi-line='false'][name='registration_sequence_page[bullet_points][]']")
    expect(component).to have_button("Add bullet point")
  end
end
