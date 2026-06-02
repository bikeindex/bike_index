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

  describe "EverythingCombobox", :flaky do
    # The combobox autocomplete is served locally by Search::ComboboxController,
    # so load the autocomplete data the combobox queries against.
    let!(:black) { FactoryBot.create(:color, name: "Black", display: "#000") }
    let!(:burgundy) { FactoryBot.create(:color, name: "Burgundy", display: "#900") }

    before do
      Autocomplete::Loader.load_all(%w[Color])
      visit(preview_path)
      # Clear localStorage
      page.execute_script("window.localStorage.clear()")
    end

    # The query_items[] fields the combobox mirrors its value into - these are
    # what actually get submitted with the form
    def combobox_values
      all("input[name='query_items[]']", visible: :all).map(&:value)
    end

    # Type a query into the combobox, then click the matching autocomplete option
    def combobox_select(query, option_text)
      find(".hw-combobox__input").set(query)
      expect(page).to have_css(".hw-combobox__option", text: option_text, wait: 30)
      find(".hw-combobox__option", text: option_text, match: :first).click
    end

    def expect_count(kind_scope, value = :greater_than_zero)
      kind_scope_text = find("[data-count-target=\"#{kind_scope}\"]").text
      # Check that the text matches the pattern (\d+) and extract the number
      number = kind_scope_text.match(/\((\d+)\)/)

      expect(number).not_to be_nil

      if value == :greater_than_zero
        expect(number.present? && number[1].to_i > 0).to be_truthy,
          "Expected #{kind_scope} count be > 0 in parentheses, but got: '#{number}'"
      else
        expect(number.present? && number[1].to_i).to eq(value),
          "Expected #{kind_scope} count eq(#{value}) in parentheses, but got: '#{number}'"
      end
    end

    def expect_localstorage_location(location:, distance:)
      local_storage = page.execute_script(<<~JS)
        let storage = {};
        for (let i = 0; i < localStorage.length; i++) {
          let key = localStorage.key(i);
          storage[key] = localStorage.getItem(key);
        }
        return storage;
      JS

      location_key = local_storage.find { |k, _| k.match?(/location/i) }&.first
      distance_key = local_storage.find { |k, _| k.match?(/distance/i) }&.first
      # pp local_storage
      expect(local_storage).to match_hash_indifferently({location_key => location, distance_key => distance})
    end

    it "submits after selecting a color" do
      expect(combobox_values).to eq([])
      expect_axe_clean
      expect(page_text(page.text)).to_not match("miles of")

      find("label", text: "Stolen in search area").click

      combobox_select("Burg", "Burgundy")
      expect(combobox_values).to eq([burgundy.search_id])

      distance = "251"
      location = "Portland, OR"
      # Enter location info
      find("#distance").set(distance)
      find("#location").set(location)
      expect(page_text(page.text)).to match("miles of")

      # Enter on the empty combobox input submits the search
      find(".hw-combobox__input").send_keys(:return)
      expect(page).to have_current_path(/\?/, wait: 5)

      expect_localstorage_location(location:, distance:)

      target_params = {
        distance: [distance],
        location: [location],
        "query_items[]": [burgundy.search_id],
        stolenness: ["proximity"],
        serial: [""]
      }

      # For some reason query doesn't show up
      expect(page_query_params(current_url).slice(*target_params.keys.map(&:to_s)))
        .to match_hash_indifferently(target_params)
    end

    it "adds the matching option when enter is pressed" do
      find(".hw-combobox__input").set("Burg")
      # Wait for filtering to settle to the single match before pressing enter
      expect(page).to have_css(".hw-combobox__option", text: "Burgundy", count: 1, wait: 30)
      expect(page).to have_no_css(".hw-combobox__option", text: "Black")

      # Enter with a matching option selects it rather than adding free text
      find(".hw-combobox__input").send_keys(:return)
      expect(combobox_values).to eq([burgundy.search_id])
    end

    it "escapes HTML in autocomplete results" do
      # An autocomplete entry whose name contains markup must render as text
      FactoryBot.create(:color, name: "Reddish<img src=x onerror=\"document.body.dataset.xss=1\">")
      Autocomplete::Loader.load_all(%w[Color])
      visit(preview_path)

      find(".hw-combobox__input").set("Reddish")
      expect(page).to have_css(".hw-combobox__option", wait: 10)

      expect(page.evaluate_script("document.body.dataset.xss")).to be_nil
    end

    context "chicago_tall_bike" do
      let(:preview_path) { "/rails/view_components/search/form/component/chicago_tall_bike" }
      let(:kind_scopes) { %w[proximity stolen non for_sale] }
      include_context :geocoder_real

      it "renders the counts", vcr: {cassette_name: :search_form_component_chicago_tall_bike} do
        # v_9 (a cycle type) is preselected via the preview's query_items
        expect(combobox_values).to eq(["v_9"])

        kind_scopes.each { |kind_scope| expect_count(kind_scope, 0) }

        combobox_select("Black", "Black")

        expect(combobox_values).to match_array(["v_9", black.search_id])

        proximity_text = find("[data-test-id=\"Search::KindOption-proximity\"]").text

        # Counts should have been hidden because a new item was added
        expect(proximity_text.strip).to eq("Stolen in search area")
      end
    end

    context "for_sale" do
      let(:kind_scopes) { %w[for_sale for_sale_proximity] }
      let(:preview_path) { "/rails/view_components/search/form/component/for_sale" }
      it "renders and updates" do
        expect(combobox_values).to eq([])
        expect(page_text(page.text)).not_to match("miles of")
        expect(find("#primary_activity", visible: false).value).to eq ""

        %w[for_sale for_sale_proximity].each { |kind_scope| expect_count(kind_scope, 0) }

        find("label", text: "For sale in search area").click

        find("#distance").set("251")
        find("#location").set("Edmonton, AB")
        expect(page_text(page.text)).to match("miles of")

        proximity_text = find("[data-test-id=\"Search::KindOption-for_sale_proximity\"]").text
        # Counts should have been hidden because a new item was added
        expect(proximity_text.strip).to eq("For sale in search area")
      end

      context "for_sale_san_francisco_atb" do
        let(:preview_path) do
          primary_activity # Needs to happen before page is rendered
          "/rails/view_components/search/form/component/for_sale_san_francisco_atb"
        end
        let(:primary_activity) { FactoryBot.create(:primary_activity_family, name: "ATB (All Terrain Biking)") }

        it "renders and updates" do
          expect(combobox_values).to eq([])
          expect(page_text(page.text)).to match("miles of")
          expect(find("#primary_activity", visible: false).value).to eq primary_activity.id.to_s

          kind_scopes.each { |kind_scope| expect_count(kind_scope, 0) }
        end
      end
    end
  end
end
