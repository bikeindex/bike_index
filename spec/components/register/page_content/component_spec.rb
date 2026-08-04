# frozen_string_literal: true

require "rails_helper"

RSpec.describe Register::PageContent::Component, type: :component do
  let(:page_record) do
    FactoryBot.build(:registration_sequence_page, title: "Battery safety", heading: "Charge safely",
      subtitle: "A few rules", body: "<ul><li>Use the right charger</li><li>Store it cool</li></ul>")
  end

  # In real use the control lambda is defined in a template, where view helpers exist;
  # here a plain string stands in for whatever checkbox the caller renders.
  it "renders the heading, the title as a section label, and a control per bullet" do
    render_inline(described_class.new(page: page_record, control: ->(index) {
      %(<input type="checkbox" data-index="#{index}">).html_safe
    }))

    expect(page).to have_css("h1", text: "Charge safely") # heading_text, big like the flow
    expect(page).to have_content("Battery safety") # the title labels the rules
    expect(page).to have_css("input[type=checkbox][data-index='0']")
    expect(page).to have_css("input[type=checkbox][data-index='1']")
    expect(page).to have_content("Use the right charger")
  end

  it "renders the caller's badge and FAQ affordance" do
    render_inline(described_class.new(page: page_record, control: ->(_index) { "".html_safe })) do |content|
      content.with_badge { "<span>E-vehicle</span>".html_safe }
      content.with_faq { '<a href="#">Read the FAQ</a>'.html_safe }
    end

    expect(page).to have_content("E-vehicle")
    expect(page).to have_link("Read the FAQ")
  end
end
