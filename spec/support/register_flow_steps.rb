# frozen_string_literal: true

RSpec.shared_context :register_flow_steps do
  let(:owner_email) { "owner@bikeindex.org" }
  let(:user_name) { "Sally Rider" }
  let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
  let!(:red) { FactoryBot.create(:color, name: "Red") }

  before do
    # The manufacturer combobox autocompletes against the redis index
    Autocomplete::Loader.clear_redis
    Autocomplete::Loader.load_all(%w[Manufacturer])
  end

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email
    click_button "Continue"
    fill_in "Password", with: "testthisthing7$"
    click_button "Log in"
    expect(page).to have_current_path("/my_account", wait: 5)
  end

  def submit_step_1
    type_into("#b_param_manufacturer_id", "Surly")
    click_combobox_option("Surly")
    fill_in "b_param[owner_email]", with: owner_email
    click_button "Next"
  end

  # fill_in focuses the field, then sends its text a round trip later - so a controller
  # connecting in between lands the text in the field filled just before
  def wait_for_details_step(wait: Capybara.default_max_wait_time)
    expect(page).to have_content("Add your bike", wait:)
    expect(page).to have_css("input[name='bike[frame_model]']:focus", wait:)
    wait_for_stimulus(timeout: wait)
  end

  # Through step 1 and onto step 2, the way a rider gets there
  def start_registration
    visit "/register/new"

    # new creates the registration and lands on its tokenized step 1
    expect(page).to have_current_path(/register\?b_param_token=.+&step=1/, url: true)

    submit_step_1

    wait_for_details_step
  end
end
