# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Email::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/email/component/" }
  let(:suggestion) { "Did you mean you@gmail.com?" }
  let(:suggestion_button) { "[aria-live='polite'] button" }
  let(:warning) { "That doesn't look like your real email address." }

  # Leaving the field is what checks it
  def fill_in_email_and_leave(email)
    fill_in "Email", with: email
    find_field("Email").send_keys(:tab)
  end

  it "checks the field on leaving it -- suggesting a correction, warning where there's none to offer, swapping it in when clicked" do
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

    # a name that short is never corrected itself, though -- "max" isn't a mistyped "mac"
    fill_in_email_and_leave("you@max.com")

    expect(page).to have_no_css(suggestion_button)

    # unless the ending is what's wrong: "mac" has a ".com" and nothing else
    fill_in_email_and_leave("you@mac.co")

    expect(page).to have_button("Did you mean you@mac.com?")

    # which is only the names that have one -- gmx is a ".de", so its ending stands
    fill_in_email_and_leave("you@gmx.de")

    expect(page).to have_no_css(suggestion_button)

    # a multi-label ending is matched whole, so a typo in the name doesn't cost it
    fill_in_email_and_leave("you@yahho.co.jp")

    expect(page).to have_button("Did you mean you@yahoo.co.jp?")

    # and yahoo keeps its own ".co.jp", vouching for ".com" or not
    fill_in_email_and_leave("you@yahoo.co.jp")

    expect(page).to have_no_css(suggestion_button)

    # a dot with nothing on one side is its own typo, so the ending still has one to spend
    fill_in_email_and_leave("you@.gmail..come")

    expect(page).to have_button(suggestion)

    # ".co" on a domain we don't know is a country's own
    fill_in_email_and_leave("you@bikeshop.co")

    expect(page).to have_no_css(suggestion_button)

    # but a name with one ending vouches for it, so here it's a "com" rather than Colombia
    fill_in_email_and_leave("you@gmail.co")

    expect(page).to have_button(suggestion)

    # the other typos need more of the part behind them -- "uol" isn't a mistyped "aol"
    fill_in_email_and_leave("you@uol.ro")

    expect(page).to have_no_css(suggestion_button)

    # nothing close to a domain we know of
    fill_in_email_and_leave("you@bikeshop.example")

    expect(page).to have_no_css(suggestion_button)

    # nor anything to say about an address that's already right
    fill_in_email_and_leave("you@gmail.com")

    expect(page).to have_no_css(suggestion_button)

    # a domain RFC 2606 holds back has nothing to correct it to, so it's told rather than asked
    fill_in_email_and_leave("you@example.com")

    expect(page).to have_css("[aria-live='polite']", text: warning)
    expect(page).to have_no_css(suggestion_button)
    expect_axe_clean

    # subdomains of one included, matching what the server scores as spam
    fill_in_email_and_leave("you@mail.example.org")

    expect(page).to have_text(warning)

    # as are its endings, however deliverable the name in front of one reads
    fill_in_email_and_leave("you@bikeshop.invalid")

    expect(page).to have_text(warning)

    # ".co" is a country's rather than one of them, so the field keeps its peace
    fill_in_email_and_leave("you@example.co")

    expect(page).to have_no_text(warning)

    # and enter is spent on the warning too, there being no correction to offer instead
    fill_in "Email", with: "you@example.com"
    find_field("Email").send_keys(:enter)

    expect(page).to have_text(warning)
    # submitting would have taken us off the preview
    expect(page).to have_field("Email", with: "you@example.com")
  end

  it "checks a value the field is rendered with, and spends enter on the suggestion before the form" do
    visit("#{base_path}mistyped")

    find_field("Email").send_keys(:tab)

    expect(page).to have_button(suggestion)

    find_field("Email").send_keys(:enter)

    # submitting would have taken us off the preview, which still has the field and the suggestion
    expect(page).to have_button(suggestion)
    expect(page).to have_field("Email", with: "you@gmial.con")

    find_button(suggestion).send_keys(:enter)

    expect(page).to have_field("Email", with: "you@gmail.com")
    expect(page).to have_no_css(suggestion_button)
    # the suggestion is gone, so focus goes back where it came from
    expect(page).to have_css("input[type='email']:focus")

    # and with nothing left to ask about, enter reaches the form
    find_field("Email").send_keys(:enter)

    expect(page).to have_no_field("Email")
  end
end
