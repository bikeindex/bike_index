# frozen_string_literal: true

require "rails_helper"

RSpec.describe UI::Forms::Email::Component, :js, type: :system do
  let(:base_path) { "/rails/view_components/ui/forms/email/component/" }
  # the whole message is text; only the address inside it is the button
  let(:suggestion) { "Did you mean you@gmail.com?" }
  let(:correction) { "you@gmail.com" }
  # the correction's name varies, so the message is found by target rather than by name
  let(:suggestion_message) { "[data-ui--forms--email-target='suggestion']" }
  let(:warning) { "That doesn't look like your real email address." }
  let(:override) { "Submit form anyway" }

  # Leaving the field is what checks it
  def fill_in_email_and_leave(email)
    fill_in "Email", with: email
    find_field("Email").send_keys(:tab)
  end

  it "checks the field on leaving it -- suggesting a correction, warning where there's none to offer, swapping it in when clicked" do
    visit("#{base_path}default")

    # the buttons ship hidden -- an empty one in the tab order is both a stop to
    # nowhere and a control with no name, and there's nothing yet to submit past
    expect(page).to have_no_css(suggestion_message)
    expect(page).to have_no_button(override)
    expect(page).to have_button("Register", disabled: false)
    expect_axe_clean

    fill_in_email_and_leave("you@gmial.con")

    # announced as it appears, so the region carries it rather than the button alone
    expect(page).to have_css("[aria-live='polite']", text: suggestion)
    # the form's own submit is held while it stands, with the way past it alongside
    expect(page).to have_button("Register", disabled: true)
    expect(page).to have_button(override)
    expect_axe_clean

    # typing answers it, so the field goes quiet and hands the form back at once
    find_field("Email").send_keys("m")

    expect(page).to have_no_css(suggestion_message)
    expect(page).to have_no_button(override)
    expect(page).to have_button("Register", disabled: false)

    # and it has its say again once the value settles
    fill_in_email_and_leave("you@gmial.con")

    expect(page).to have_css("[aria-live='polite']", text: suggestion)

    click_on correction

    expect(page).to have_field("Email", with: "you@gmail.com")
    expect(page).to have_no_css(suggestion_message)
    # answered, so the form is the user's again
    expect(page).to have_button("Register", disabled: false)

    # a domain nobody knows keeps its name, but its ending is still checked
    fill_in_email_and_leave("you@bikeshop.con")

    expect(page).to have_button("you@bikeshop.com")

    # a dropped letter is corrected however short it leaves the part
    fill_in_email_and_leave("you@macc.om")

    expect(page).to have_button("you@mac.com")

    # a name that short is never corrected itself, though -- "max" isn't a mistyped "mac"
    fill_in_email_and_leave("you@max.com")

    expect(page).to have_no_css(suggestion_message)

    # unless the ending is what's wrong: "mac" has a ".com" and nothing else
    fill_in_email_and_leave("you@mac.co")

    expect(page).to have_button("you@mac.com")

    # which is only the names that have one -- gmx is a ".de", so its ending stands
    fill_in_email_and_leave("you@gmx.de")

    expect(page).to have_no_css(suggestion_message)

    # a multi-label ending is matched whole, so a typo in the name doesn't cost it
    fill_in_email_and_leave("you@yahho.co.jp")

    expect(page).to have_button("you@yahoo.co.jp")

    # and yahoo keeps its own ".co.jp", vouching for ".com" or not
    fill_in_email_and_leave("you@yahoo.co.jp")

    expect(page).to have_no_css(suggestion_message)

    # a dot with nothing on one side is its own typo, so the ending still has one to spend
    fill_in_email_and_leave("you@.gmail..come")

    expect(page).to have_button(correction)

    # ".co" on a domain we don't know is a country's own
    fill_in_email_and_leave("you@bikeshop.co")

    expect(page).to have_no_css(suggestion_message)

    # but a name with one ending vouches for it, so here it's a "com" rather than Colombia
    fill_in_email_and_leave("you@gmail.co")

    expect(page).to have_button(correction)

    # the other typos need more of the part behind them -- "uol" isn't a mistyped "aol"
    fill_in_email_and_leave("you@uol.ro")

    expect(page).to have_no_css(suggestion_message)

    # nothing close to a domain we know of
    fill_in_email_and_leave("you@bikeshop.example")

    expect(page).to have_no_css(suggestion_message)

    # nor anything to say about an address that's already right
    fill_in_email_and_leave("you@gmail.com")

    expect(page).to have_no_css(suggestion_message)

    # a domain RFC 2606 holds back has nothing to correct it to, so it's told rather than asked
    fill_in_email_and_leave("you@example.com")

    expect(page).to have_css("[aria-live='polite']", text: warning)
    expect(page).to have_no_css(suggestion_message)
    expect_axe_clean

    # subdomains of one included, matching what the server scores as spam
    fill_in_email_and_leave("you@mail.example.org")

    expect(page).to have_text(warning)

    # as are its endings, however deliverable the name in front of one reads
    fill_in_email_and_leave("you@bikeshop.invalid")

    expect(page).to have_text(warning)

    # a correction can land on one, so accepting it swaps the question for the warning
    fill_in_email_and_leave("you@example.con")

    expect(page).to have_button("you@example.com")
    # the message animates open over 200ms, and a click before it settles lands on nothing.
    # The warning leaving on the same 200ms is what there is to wait on without reaching
    # into the animation.
    expect(page).to have_no_text(warning)

    click_on "you@example.com"

    expect(page).to have_text(warning)
    expect(page).to have_no_css(suggestion_message)
    expect(page).to have_button("Register", disabled: true)

    # ".co" is a country's rather than one of them, so the field keeps its peace
    fill_in_email_and_leave("you@example.co")

    expect(page).to have_no_text(warning)
    expect(page).to have_button("Register", disabled: false)

    # and enter is spent on the warning too, there being no correction to offer instead
    fill_in "Email", with: "you@example.com"
    find_field("Email").send_keys(:enter)

    expect(page).to have_text(warning)
    # submitting would have taken us off the preview
    expect(page).to have_field("Email", with: "you@example.com")

    # which is what the way past is for -- the address stands as typed
    click_on override

    expect(page).to have_no_field("Email")
  end

  it "checks a value the field is rendered with, and spends enter on the suggestion before the form" do
    visit("#{base_path}mistyped")

    find_field("Email").send_keys(:tab)

    expect(page).to have_button(correction)

    find_field("Email").send_keys(:enter)

    # submitting would have taken us off the preview, which still has the field and the suggestion
    expect(page).to have_button(correction)
    expect(page).to have_field("Email", with: "you@gmial.con")

    find_button(correction).send_keys(:enter)

    expect(page).to have_field("Email", with: "you@gmail.com")
    expect(page).to have_no_css(suggestion_message)
    expect(page).to have_button("Register", disabled: false)
    # releasing puts back only what the hold took, so a submit held elsewhere stays held
    expect(page).to have_button("Held elsewhere", disabled: true)
    # the suggestion is gone, so focus goes back where it came from
    expect(page).to have_css("input[type='email']:focus")

    # and with nothing left to ask about, enter reaches the form
    find_field("Email").send_keys(:enter)

    expect(page).to have_no_field("Email")
  end
end
