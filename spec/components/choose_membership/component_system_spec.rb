# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChooseMembership::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/choose_membership/component/default" }

  it "default preview" do
    visit(preview_path)

    expect(page).to have_content(/\$4.99\s+per\s+month/)

    # Click yearly toggle
    choose 'Yearly'

    # Verify yearly price is displayed
    expect(page).to have_content(/\$49.99\s+per\s+year/)
  end
end
