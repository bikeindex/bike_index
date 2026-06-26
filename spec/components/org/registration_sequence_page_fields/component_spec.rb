# frozen_string_literal: true

require "rails_helper"

RSpec.describe Org::RegistrationSequencePageFields::Component, type: :component do
  let(:page) { RegistrationSequencePage.new(bullet_points: ["<p>first bullet</p>"]) }

  def rendered_component(page)
    render_in_view_context do
      form_for page, url: "#", method: :patch do |f|
        render(Org::RegistrationSequencePageFields::Component.new(form_builder: f))
      end
    end
  end

  let(:component) { rendered_component(page) }

  it "renders the image field and a single-line Lexxy editor per bullet" do
    expect(component).to have_field("registration_sequence_page_image")
    expect(component).to have_css("lexxy-editor[multi-line='false'][name='registration_sequence_page[bullet_points][]']")
    expect(component).to have_button("Add bullet point")
    expect(component).to_not have_field("registration_sequence_page_listing_order")
  end
end
