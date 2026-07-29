# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Email::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/email/component/" }
  let(:suggestion) { "Did you mean you@gmail.com?" }
  let(:suggestion_button) { "[aria-live='polite'] button" }

  # Leaving the field is what checks it
  def fill_in_email_and_leave(email)
    fill_in "Email", with: email
    find_field("Email").send_keys(:tab)
  end

  it "suggests a correction on leaving the field, holds its peace where it has none, and swaps it in when clicked" do
    visit("#{base_path}default")

    # the button ships hidden -- an empty one in the tab order is both a stop to
    # nowhere and a control with no name
    expect(page).to have_no_css(suggestion_button)
    expect_axe_clean

    fill_in_email_and_leave("you@gmial.con")

    # announced as it appears, so the region carries it rather than the button alone
    expect(page).to have_css("[aria-live='polite']", text: suggestion)
    expect_axe_clean

    click_on suggestion

    expect(page).to have_field("Email", with: "you@gmail.com")
    expect(page).to have_no_css(suggestion_button)

    # a domain nobody knows keeps its name, but its ending is still checked
    fill_in_email_and_leave("you@bikeshop.con")

    expect(page).to have_button("Did you mean you@bikeshop.com?")

    # a dropped letter is corrected however short it leaves the part
    fill_in_email_and_leave("you@macc.om")

    expect(page).to have_button("Did you mean you@mac.com?")

    # a dot with nothing on one side is its own typo, so the ending still has one to spend
    fill_in_email_and_leave("you@.gmail..come")

    expect(page).to have_button(suggestion)

    # the other typos aren't, on a part this short -- "uol" is no more a mistyped "aol"
    # than every two-letter ending is a mistyped one of the two-letter endings we know
    fill_in_email_and_leave("you@uol.ro")

    expect(page).to have_no_css(suggestion_button)

    # nothing close to a domain we know of
    fill_in_email_and_leave("you@bikeshop.example")

    expect(page).to have_no_css(suggestion_button)

    # nor anything to say about an address that's already right
    fill_in_email_and_leave("you@gmail.com")

    expect(page).to have_no_css(suggestion_button)
  end

  it "checks a value the field is rendered with, and accepts it from the keyboard" do
    visit("#{base_path}mistyped")

    find_field("Email").send_keys(:tab)

    expect(page).to have_button(suggestion)

    find_button(suggestion).send_keys(:enter)

    expect(page).to have_field("Email", with: "you@gmail.com")
    expect(page).to have_no_css(suggestion_button)
    # the suggestion is gone, so focus goes back where it came from
    expect(page).to have_css("input[type='email']:focus")
  end
end
