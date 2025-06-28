require "rails_helper"

RSpec.shared_examples "bike_searchable" do
  let(:manufacturer) { FactoryBot.create(:manufacturer) }
  let(:color) { FactoryBot.create(:color) }
  let(:multi_query_items) { [manufacturer.search_id, color.search_id, "some other string", "another string"] }
  let(:ip_address) { "127.0.0.1" }
  let(:interpreted_params) { BikeSearchable.searchable_interpreted_params(query_params, ip: ip_address) }
  include_context :geocoder_stubbed_bounding_box

  def i_params(serial = nil, ip_address: nil, query_items: [], stolenness: "all")
    BikeSearchable.searchable_interpreted_params({serial: serial, stolenness: stolenness, query_items: query_items}, ip: ip_address)
  end

  describe "search" do
    context "color_ids of primary, secondary and tertiary" do
      let(:color2) { FactoryBot.create(:color) }
      let(:bike1) { FactoryBot.create(:bike, primary_frame_color: color, updated_at: Time.current - 3.months, cycle_type: :cargo, propulsion_type: "pedal-assist-and-throttle") }
      let(:bike2) { FactoryBot.create(:bike, secondary_frame_color: color, tertiary_frame_color: color2, updated_at: Time.current - 2.weeks, cycle_type: :cargo) }
      let(:bike3) { FactoryBot.create(:bike, tertiary_frame_color: color, manufacturer: manufacturer, cycle_type: :stroller, propulsion_type: "throttle") }
      let(:all_color_ids) do
        [
          bike1.primary_frame_color_id,
          bike2.primary_frame_color_id,
          bike3.primary_frame_color_id,
          bike1.secondary_frame_color_id,
          bike2.secondary_frame_color_id,
          bike3.secondary_frame_color_id,
          bike1.tertiary_frame_color_id,
          bike2.tertiary_frame_color_id,
          bike3.tertiary_frame_color_id
        ]
      end
      before do
        expect(all_color_ids.count(color.id)).to eq 3 # Each bike has color only once
      end
      context "single color" do
        let(:query_params) { {colors: [color.id], stolenness: "all"} }
        it "matches bikes with the given color" do
          expect(bike1.listing_order < bike2.listing_order).to be_truthy
          expect(bike2.listing_order < bike3.listing_order).to be_truthy
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike3.id, bike2.id, bike1.id])
        end
      end
      context "second color" do
        let(:query_params) { {colors: [color.id, color2.id], stolenness: "all"} }
        it "matches just the bike with both colors" do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike2.id])
        end
      end
      context "and manufacturer_id" do
        let(:query_params) { {colors: [color.id], manufacturer: manufacturer.id, stolenness: "all"} }
        it "matches just the bike with the matching manufacturer" do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike3.id])
        end
      end
      context "and cycle_type" do
        let(:query_params) { {colors: [color.id], stolenness: "all", cycle_type: "cargo"} }
        it "matches just the bikes with the cycle_type" do
          expect(Bike.search(interpreted_params).pluck(:id)).to match_array([bike1.id, bike2.id])
          expect(Bike.search(interpreted_params.merge(colors: [color.id, color2.id])).pluck(:id)).to eq([bike2.id])
          expect(Bike.search({stolenness: "all", cycle_type: "stroller"}).pluck(:id)).to eq([bike3.id])
        end
      end
      context "and propulsion_type" do
        let(:query_params) { {colors: [color.id], stolenness: "all", propulsion_type: "motorized"} }
        it "matches just the bikes with the cycle_type" do
          expect(Bike.search(interpreted_params).pluck(:id)).to match_array([bike1.id, bike3.id])
          expect(Bike.search(interpreted_params.merge(colors: [color.id, color2.id])).pluck(:id)).to eq([])
          expect(Bike.search({stolenness: "all", propulsion_type: "throttle"}).pluck(:id)).to eq([bike3.id])
        end
      end
    end
    context "serial" do
      before do
        expect(bike).to be_present
      end
      context "stood-ffer" do
        let(:bike) { FactoryBot.create(:bike, serial_number: "st00d-ffer") }
        context "full homoglyph match" do
          let(:query_params) { {serial: "STood ffer", stolenness: "all"} }
          it "finds matching bikes" do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
            # It finds without spaces
            expect(Bike.search(interpreted_params.merge(serial: "SToodffer")).pluck(:id)).to eq([bike.id])
            # And with extra spaces
            expect(Bike.search(interpreted_params.merge(serial: "ST ood ffer")).pluck(:id)).to eq([bike.id])
          end
        end
        context "partial homoglyph match" do
          let(:query_params) { {serial: "ST0oD", stolenness: "all"} }
          it "finds matching bikes" do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
          end
        end
      end
      context "reversed serial" do
        let(:bike) { FactoryBot.create(:bike, serial_number: "K10DY00047-bkd") }
        let(:query_params) { {serial: "bkd-K1oDYooo47", stolenness: "all"} }
        it "full text search" do
          expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike.id])
        end
      end
    end
    context "query" do
      it "selects matching the query" do
        bike1 = FactoryBot.create(:bike, description: "Booger")
        bike2 = FactoryBot.create(:bike)
        expect(bike1).to be_valid
        expect(bike2).to be_valid

        interpreted_params = BikeSearchable.searchable_interpreted_params(
          {query: "booger", stolenness: "all"},
          ip: "127.0.0.1"
        )
        results = Bike.search(interpreted_params)

        expect(results.pluck(:id)).to eq([bike1.id])
      end
    end
    context "stolenness" do
      context "non-proximity" do
        let(:stolen_bike) { FactoryBot.create(:stolen_bike) }
        let(:non_stolen_bike) { FactoryBot.create(:bike) }
        before do
          expect([stolen_bike, non_stolen_bike].size).to eq 2
        end
        context "stolen_search" do
          let(:query_params) { {stolenness: "stolen"} }
          it "only stolen bikes" do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
          end
        end
        context "non_stolen search" do
          let(:query_params) { {stolenness: "non"} }
          it "only non_stolen" do
            expect(Bike.search(interpreted_params).pluck(:id)).to eq([non_stolen_bike.id])
          end
        end
        context "all" do
          let(:query_params) { {stolenness: "all"} }
          it "returns all bikes" do
            ids = Bike.search(interpreted_params).pluck(:id)
            expect(ids.count).to eq 2
            expect(ids.include?(stolen_bike.id)).to be_truthy
            expect(ids.include?(non_stolen_bike.id)).to be_truthy
          end
        end
      end
      context "proximity" do
        it "returns bikes near the requested location" do
          bike1 = FactoryBot.create(:stolen_bike_in_amsterdam)
          bike2 = FactoryBot.create(:stolen_bike_in_nyc)
          expect(bike1.longitude).to_not eq(bike2.longitude)

          interpreted_params = BikeSearchable.searchable_interpreted_params(
            {stolenness: "proximity", location: "New York, NY", distance: 200},
            ip: "127.0.0.1"
          )
          results = Bike.search(interpreted_params)

          expect(results.pluck(:id)).to eq([bike2.id])
        end
      end
    end
    describe "scoped bike" do
      context "organization bike" do
        let(:interpreted_params) { BikeSearchable.searchable_interpreted_params(query_params, ip: "d") }

        let(:bike1) { FactoryBot.create(:bike) }
        let(:bike2) { FactoryBot.create(:bike_organized) }
        let(:organization) { bike2.organizations.first }
        let(:query_params) { {stolenness: "all"} }
        before do
          expect([bike1, bike2].size).to eq 2
          expect(organization.bikes.pluck(:id)).to eq([bike2.id])
        end
        it "only finds bikes in the organization" do
          expect(organization.bikes.search(interpreted_params).pluck(:id)).to eq([bike2.id])
        end
      end
    end

    describe "primary_activity" do
      let(:primary_activity) { FactoryBot.create(:primary_activity) }
      let(:primary_activity2) { nil }
      let(:interpreted_params) { BikeSearchable.searchable_interpreted_params({primary_activity: primary_activity.id, stolenness: "all"}, ip: ip_address) }
      let!(:bike1) { FactoryBot.create(:bike, primary_activity:) }
      let!(:bike2) { FactoryBot.create(:bike, primary_activity: primary_activity2) }
      it "finds the matching bike" do
        expect(Bike.search(interpreted_params).pluck(:id)).to eq([bike1.id])
      end

      context "primary_activity family" do
        let(:primary_activity) { FactoryBot.create(:primary_activity_family) }
        let(:primary_activity2) { FactoryBot.create(:primary_activity, :with_family, primary_activity_family: primary_activity) }

        def i_params_activity(primary_activity_id)
          BikeSearchable.searchable_interpreted_params({primary_activity: primary_activity_id, stolenness: "all"}, ip: ip_address)
        end

        it "finds the matching bike" do
          expect(primary_activity2.reload.primary_activity_family_id).to eq(primary_activity.id)
          expect(Bike.search(i_params_activity(primary_activity.id)).pluck(:id)).to match_array([bike1.id, bike2.id])
          expect(Bike.search(i_params_activity(primary_activity.slug)).pluck(:id)).to match_array([bike1.id, bike2.id])
          expect(Bike.search(i_params_activity(primary_activity.name)).pluck(:id)).to match_array([bike1.id, bike2.id])
          expect(Bike.search(i_params_activity(primary_activity2.short_name)).pluck(:id)).to eq([bike2.id])
        end
      end
    end
  end

  describe "search_close_serials and serials_containing" do
    let(:black) { Color.black }
    let!(:stolen_bike) { FactoryBot.create(:stolen_bike, serial_number: "O|ILSZB-111JJJG8", manufacturer: manufacturer, primary_frame_color: black) }
    let(:blue) { FactoryBot.create(:color, name: "Blue") }
    let!(:non_stolen_bike) { FactoryBot.create(:bike, serial_number: "O|ILSZB-111JJJJJ", primary_frame_color: blue) }
    context "no serial param" do
      let(:query_params) { {query_items: [manufacturer.search_id], stolenness: "non"} }
      it "returns nil" do
        expect(Bike.search_close_serials(interpreted_params)).to be_blank
      end
    end
    context "exact normalized serial" do
      let(:query_params) { {serial: "11I528-111JJJJJ", stolenness: "all"} } # Because drops leading zeros
      it "matches only non-exact" do
        expect(Bike.search(interpreted_params).pluck(:id)).to eq([non_stolen_bike.id])
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
    context "passing color" do
      let(:s_contain) { "011 I528-111J J" }
      let(:s_nearby) { "111528111JJJV" }
      it "matches by color as well" do
        # Sanity check
        expect(Bike.search_serials_containing(i_params(s_contain, stolenness: "all")).pluck(:id)).to match_array([stolen_bike.id, non_stolen_bike.id])
        expect(Bike.search_close_serials(i_params(s_nearby, stolenness: "all")).pluck(:id)).to match_array([stolen_bike.id, non_stolen_bike.id])
        expect(Bike.search(i_params(nil, query_items: [blue.search_id], stolenness: "all")).pluck(:id)).to eq([non_stolen_bike.id])
        expect(Bike.search(i_params(nil, query_items: [black.search_id], stolenness: "all")).pluck(:id)).to eq([stolen_bike.id])
        # search_serials_containing matches by color
        expect(Bike.search_serials_containing(i_params(s_contain, query_items: [blue.search_id], stolenness: "all")).pluck(:id)).to eq([non_stolen_bike.id])
        expect(Bike.search_serials_containing(i_params(s_contain, query_items: [black.search_id], stolenness: "all")).pluck(:id)).to eq([stolen_bike.id])
        # search_close_serials matches by color too
        expect(Bike.search_close_serials(i_params(s_nearby, query_items: [blue.search_id], stolenness: "all")).pluck(:id)).to eq([non_stolen_bike.id])
        expect(Bike.search_close_serials(i_params(s_nearby, query_items: [black.search_id], stolenness: "all")).pluck(:id)).to eq([stolen_bike.id])
      end
    end
    context "serial with spaces rather than dashes" do
      let(:query_params) { {serial: "11I528 111JJJJJ", stolenness: "all"} }
      it "matches only non-exact" do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
    context "spaces" do
      let!(:non_stolen_bike_n) { FactoryBot.create(:bike, serial_number: "O|ILSZB-111JJJN") }
      let(:query_params) { {serial: "011-I528-111J-J", stolenness: "all"} }
      let(:interpreted_params_g) { i_params("011 I528-111J JJg") }
      let(:interpreted_params_n) { i_params("11528 11 1JJ Jn") } # just segment 2
      let(:interpreted_params_no_space) { i_params("011I528111JJ") }
      let(:interpreted_params_first_segment) { i_params("111529") }
      let(:all_ids) { [stolen_bike.id, non_stolen_bike.id, non_stolen_bike_n.id] }
      it "matches only non-exact" do
        # serial contained in - don't match
        expect(non_stolen_bike.reload.serial_normalized_no_space).to match interpreted_params[:serial_no_space]
        expect(non_stolen_bike_n.reload.serial_normalized_no_space).to match interpreted_params[:serial_no_space]
        expect(stolen_bike.reload.serial_normalized_no_space).to match interpreted_params[:serial_no_space]
        expect(Bike.search_serials_containing(interpreted_params).pluck(:id)).to match_array(all_ids)
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([])
        # Inexact serial searched
        expect(stolen_bike.serial_normalized_no_space).to match interpreted_params_g[:serial_no_space]
        expect(Bike.search_serials_containing(interpreted_params_g).pluck(:id)).to match_array([stolen_bike.id])
        expect(Bike.search_close_serials(interpreted_params_g).pluck(:id)).to match_array([non_stolen_bike.id, non_stolen_bike_n.id])
        # Another inexact serial
        expect(non_stolen_bike_n.serial_normalized_no_space).to match interpreted_params_n[:serial_no_space]
        expect(Bike.search_serials_containing(interpreted_params_n).pluck(:id)).to match_array([non_stolen_bike_n.id])
        expect(Bike.search_close_serials(interpreted_params_n).pluck(:id)).to match_array([])
        # No space - same result
        expect(non_stolen_bike.serial_normalized_no_space).to match interpreted_params_no_space[:serial_no_space]
        expect(Bike.search_serials_containing(interpreted_params_no_space).pluck(:id)).to match_array(all_ids)
        expect(Bike.search_close_serials(interpreted_params_no_space).pluck(:id)).to eq([])
        # Exact match, no whitespace
        interpreted_params_no_space2 = i_params("0111528111JJJN")
        expect(non_stolen_bike_n.serial_normalized_no_space).to eq interpreted_params_no_space2[:serial_no_space]
        expect(Bike.search(interpreted_params_no_space2).pluck(:id)).to eq([non_stolen_bike_n.id])
        expect(Bike.search_serials_containing(interpreted_params_no_space2).pluck(:id)).to eq([])
        expect(Bike.search_close_serials(interpreted_params_no_space2).pluck(:id)).to match_array([non_stolen_bike.id, stolen_bike.id])
        # Exact match, extra whitespace, same as above
        interpreted_params_plus_space = i_params("O11 LSZB 111 JJJN")
        expect(non_stolen_bike_n.serial_normalized_no_space).to eq interpreted_params_plus_space[:serial_no_space]
        expect(Bike.search(interpreted_params_plus_space).pluck(:id)).to eq([non_stolen_bike_n.id])
        expect(Bike.search_serials_containing(interpreted_params_plus_space).pluck(:id)).to eq([])
        expect(Bike.search_close_serials(interpreted_params_plus_space).pluck(:id)).to match_array([non_stolen_bike.id, stolen_bike.id])
        # expect(Bike.search_close_serials(i_params("O11 LSZB 111 JJJN")).pluck(:id)).to eq([])
        # first segment mismatch. NOTE: This doesn't work!
        expect(Bike.search_serials_containing(interpreted_params_first_segment).pluck(:id)).to match_array([])
        # TODO: Make this actually work - Levenshtein match against different serial segments, separated by space
        # expect(Bike.search_close_serials(interpreted_params_first_segment).pluck(:id)).to match_array(all_ids)
      end
    end
    context "close serial with stolenness" do
      let(:query_params) { {serial: "011I528-111JJJJk", stolenness: "non"} }
      it "returns matching stolenness" do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([non_stolen_bike.id])
      end
    end
    context "close serial with query items" do
      let(:query_params) { {serial: "011I528-111JJJk", query_items: [manufacturer.search_id], stolenness: "all"} }
      it "returns matching" do
        expect(Bike.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
    context "close serial on organization bikes" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:query_params) { {serial: "011I528-111JJJk", stolenness: "all"} }
      before do
        FactoryBot.create(:bike_organization, bike: stolen_bike, organization: organization)
        stolen_bike.update_attribute :creation_organization_id, organization.id
        expect(organization.bikes.pluck(:id)).to eq([stolen_bike.id])
      end
      it "returns matching stolenness" do
        expect(organization.bikes.search_close_serials(interpreted_params).pluck(:id)).to eq([stolen_bike.id])
      end
    end
  end

  describe "search_serials_containing" do
    let(:stolen_bike) { FactoryBot.create(:stolen_bike, serial_number: "O|ILSZB-111JJJG8", manufacturer: manufacturer) }
    let(:non_stolen_bike) { FactoryBot.create(:bike, serial_number: "O|ILSZB-111JJJJJ") }
    before { expect([non_stolen_bike, stolen_bike].size).to eq 2 }
    context "non-matching" do
      let(:no_serial) { i_params(nil, query_items: [manufacturer.search_id], stolenness: "non") }
      it "returns nil" do
        expect(Bike.search_serials_containing(no_serial).pluck(:id)).to eq([])
        expect(Bike.search_serials_containing(i_params("11I528-111JJJJJ")).pluck(:id)).to eq([])
      end
    end
    context "spaces" do
      it "matches only non-exact" do
        # no spaces
        expect(Bike.search_serials_containing(i_params("011I528111JJJ")).pluck(:id)).to match_array([non_stolen_bike.id, stolen_bike.id])
        # Extra spaces
        expect(Bike.search_serials_containing(i_params("01 1 I5 28 111 J JJ")).pluck(:id)).to match_array([non_stolen_bike.id, stolen_bike.id])
      end
    end
  end
end
