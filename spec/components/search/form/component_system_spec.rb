# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Form::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/search/form/component/default" }
  let(:default_params) do
    {
      distance: ["100"],
      location: [""],
      "query_items[]": [],
      stolenness: "stolen", # TODO: above should be this
      serial: [""]
    }
  end

  def page_query_params(url)
    uri = URI.parse(url)
    CGI.parse(uri.query || "")
  end

  describe "EverythingCombobox" do
    # NOTE: these tests are specific to Select2, unfortuanately
    # It requires hacks to target specific selectors because Select2 doesn't use accessible elements
    # ... but the behavior should be the same for any updated combobox plugin

    before do
      # Stub the API_URL to use the production autocomplete url, for more accurate testing
      stub_const("Search::EverythingCombobox::Component::API_URL", "https://bikeindex.org/api/autocomplete")
      visit(preview_path)
      # Clear localStorage
      page.execute_script("window.localStorage.clear()")
    end

    it "adds an item when selected" do
      expect(find("#query_items", visible: false).value).to be_blank
      find(".select2-container").click

      expect(page).to have_content("Bikes that are Black", wait: 5)
      find("li", text: "Bikes that are Black").click

      expect(page).to have_css(".select2-selection__rendered", text: "Black")

      # NOTE: Since this uses production data, values are consistent
      expect(find("#query_items", visible: false).value).to eq(["c_1"])
    end

    it "submits when enter is pressed twice" do
      expect(find("#query_items", visible: false).value).to be_blank

      find("label", text: "Stolen in search area").click

      find(".select2-container").click
      # Wait for select2 to load
      expect(page).to have_content("Bikes that are Black", wait: 5)

      page.send_keys :arrow_down
      page.send_keys :arrow_down
      page.send_keys :arrow_down

      page.send_keys :return

      # NOTE: Since this uses production data, values are consistent
      expect(find("#query_items", visible: false).value).to eq(["c_5"])

      # Enter location info
      find("#distance").set("251")
      find("#location").set("Portland, OR")

      page.send_keys(:return)
      expect(page).to have_current_path(/\?/, wait: 5)

      target_params = {
        distance: ["251"],
        location: ["Portland, OR"],
        "query_items[]": ["c_5"],
        query: [""],
        button: [""],
        stolenness: ["proximity"],
        serial: [""]
      }
      expect(page_query_params(current_url)).to match_hash_indifferently(target_params)
    end

    it "scrolls through paginated options" do
      visit(preview_path)

      expect(find("#query_items", visible: false).value).to be_blank
      find(".select2-container").click

      expect(page).to have_content("Bikes that are Black", wait: 5)
      # Scroll down, verify it loads more
      page.execute_script(<<-JS)
        const container = document.querySelector('.select2-results__options');
        const interval = setInterval(() => {
          container.scrollTop += 100;
          const element = Array.from(container.querySelectorAll('li')).find(el => el.textContent.includes('Bikes made by All City'));
          if (element && element.getBoundingClientRect().top >= 0 && element.getBoundingClientRect().bottom <= window.innerHeight) {
            clearInterval(interval);
          }
        }, 100);
      JS
    end
  end
end
