# frozen_string_literal: true

require "rails_helper"

RSpec.describe Search::Form::Component, :js, type: :system do
  let(:preview_path) { "/rails/view_components/search/form/component/default" }

  def page_text(rendered_page)
    rendered_page.gsub(/\s+/, " ")
  end

  def page_query_params(url)
    uri = URI.parse(url)
    CGI.parse(uri.query || "")
  end

  describe "EverythingCombobox" do
    # NOTE: these tests are specific to Select2, unfortunately
    # It requires hacks to target specific selectors because Select2 doesn't use accessible elements
    # ... but the behavior should be the same for any updated combobox plugin

    before do
      # Stub the API_URL to use the production urls, for more accurate testing
      stub_const("Search::EverythingCombobox::Component::API_URL", "https://bikeindex.org/api/autocomplete")
      visit(preview_path)
      # Clear localStorage
      page.execute_script("window.localStorage.clear()")
    end

    def expect_count(stolenness, value = :greater_than_zero)
      stolenness_text = find("[data-count-target=\"#{stolenness}\"]").text
      # Check that the text matches the pattern (\d+) and extract the number
      number = stolenness_text.match(/\((\d+)\)/)

      expect(number).not_to be_nil

      if value == :greater_than_zero
        expect(number.present? && number[1].to_i > 0).to be_truthy,
          "Expected #{stolenness} count be > 0 in parentheses, but got: '#{number}'"
      else
        expect(number.present? && number[1].to_i).to eq(value),
          "Expected #{stolenness} count eq(#{value}) in parentheses, but got: '#{number}'"
      end
    end

    it "submits when enter is pressed twice" do
      expect(find("#query_items", visible: false).value).to be_blank
      expect(page_text(page.text)).to_not match("miles of")

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
      expect(page_text(page.text)).to match("miles of")

      page.send_keys(:return)
      expect(page).to have_current_path(/\?/, wait: 5)

      target_params = {
        distance: ["251"],
        location: ["Portland, OR"],
        "query_items[]": ["c_5"],
        query: "",
        button: [""],
        stolenness: ["proximity"],
        serial: [""]
      }

      # For some reason query doesn't show up
      expect(page_query_params(current_url).except("query"))
        .to match_hash_indifferently(target_params.except(:query))

      # TODO: test for entering location: you, location: anywhere
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

    context "chicago_tall_bike" do
      let(:preview_path) { "/rails/view_components/search/form/component/chicago_tall_bike" }
      include_context :geocoder_real
      # Maybe TODO: get real results for counts
      # let(:production_count_url) { "https://bikeindex.org/api/v3/search/count" }
      # allow_any_instance_of(Search::KindSelectFields::Component).to receive(:api_count_url).and_return(production_count_url)
      it "renders the counts", vcr: {cassette_name: :search_form_component_chicago_tall_bike} do
        expect(find("#query_items", visible: false).value).to eq(["v_9"])

        # TODO: Why doesn't this show up?
        # expect(page_text(page.text)).to match("miles of")

        %w[proximity stolen non for_sale].each { |stolenness| expect_count(stolenness, 0) }

        find(".select2-container").click
        # Wait for select2 to load
        expect(page).to have_content("Bikes that are Black", wait: 5)

        page.send_keys :arrow_down
        page.send_keys :arrow_down
        page.send_keys :arrow_down

        page.send_keys :return

        # NOTE: Since this uses production data, values are consistent
        expect(find("#query_items", visible: false).value).to match_array(%w[v_9 c_5])

        proximity_text = find("[data-test-id=\"Search::KindOption-proximity\"]").text

        # Counts should have been hidden because a new item was added
        expect(proximity_text.strip).to eq("Stolen in search area")
      end
    end

    context "for_sale" do
      let(:preview_path) { "/rails/view_components/search/form/component/for_sale" }
      it "renders and updates" do
        expect(find("#query_items", visible: false).value).to eq([])
        expect(page_text(page.text)).not_to match("miles of")

        find("label", text: "For sale in search area").click

        # TODO: Why is this not working?
        find("#distance").set("251")
        find("#location").set("Edmonton, AB")
        expect(page_text(page.text)).to match("miles of")
      end
    end
  end
end
