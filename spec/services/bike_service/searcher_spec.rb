require "rails_helper"

RSpec.describe BikeService::Searcher do
  describe "initialize" do
    context "basic serial array" do
      it "deletes the serial gsub expression if it is present" do
        params = {query: "m_940%2Cs%23sdfc%23%2Cc_1"}
        searcher = BikeService::Searcher.new(params)
        expect(searcher.params[:serial]).to eq("sdfc")
        expect(searcher.params[:query]).to eq("m_940%2C%2Cc_1")
      end
    end
    context "troublesome 1" do
      it "deletes the serial gsub expression if it is present" do
        params = {query: "s#R910860723#"}
        searcher = BikeService::Searcher.new(params)
        expect(searcher.params[:serial]).to eq("R910860723")
        expect(searcher.params[:query]).to eq("")
      end
    end
  end

  describe "search selectize options" do
    it "returns the selectized items if passed through the expected things" do
      manufacturer = FactoryBot.create(:manufacturer)
      color_1 = FactoryBot.create(:color)
      color_2 = FactoryBot.create(:color)
      params = {query: "c_#{color_1.id},c_#{color_2.id}%2Cm_#{manufacturer.id}%2Csomething+cool%2Cs%238xcvxcvcx%23"}
      searcher = BikeService::Searcher.new(params)
      searcher.matching_manufacturer(Bike.all)
      searcher.matching_colors(Bike.all)
      target = [
        manufacturer.autocomplete_result_hash,
        color_1.autocomplete_result_hash,
        color_2.autocomplete_result_hash,
        {id: "serial", search_id: "s#8xcvxcvcx#", text: "8xcvxcvcx"},
        {text: "something+cool", search_id: "something+cool"}
      ].as_json
      result = searcher.selectize_items
      expect(result).to eq target
      result.each { |t| expect(target.include?(t)).to be_truthy }
      target.each { |t| expect(result.include?(t)).to be_truthy }
    end
  end

  describe "find_bikes" do
    it "calls select manufacturers, attributes, stolen and query if stolen is present" do
      search = BikeService::Searcher.new(stolen: true)
      expect(search).to receive(:matching_serial).and_return(Bike)
      expect(search).to receive(:matching_stolenness).and_return(Bike)
      expect(search).to receive(:matching_manufacturer).and_return(Bike)
      # search.should_receive(:matching_attr_cache).and_return(true)
      expect(search).to receive(:matching_query).and_return(Bike)
      search.find_bikes
    end
    it "does not fail if nothing is present" do
      search = BikeService::Searcher.new
      expect(search.find_bikes).not_to be_present
    end
  end

  describe "matching_serial" do
    it "finds matching bikes" do
      bike = FactoryBot.create(:bike, serial_number: "st00d-ffer")
      search = BikeService::Searcher.new(serial: "STood ffer")
      expect(search.matching_serial.first).to eq(bike)
    end
    it "finds matching bikes" do
      bike = FactoryBot.create(:bike, serial_number: "st00d-ffer")
      search = BikeService::Searcher.new(serial: "STood")
      expect(search.matching_serial.first).to eq(bike)
    end
    it "fulls text search" do
      bike = FactoryBot.create(:bike, serial_number: "K10DY00047-bkd")
      search = BikeService::Searcher.new(serial: "bkd-K1oDYooo47")
      expect(search.matching_serial.first).to eq(bike)
    end
  end

  describe "matching_manufacturer" do
    it "finds matching bikes from manufacturer without id" do
      manufacturer = FactoryBot.create(:manufacturer, name: "Special bikes co.")
      bike = FactoryBot.create(:bike, manufacturer: manufacturer)
      bike2 = FactoryBot.create(:bike)
      search = BikeService::Searcher.new(manufacturer: "Special", query: "")
      expect(search.matching_manufacturer(Bike.all).first).to eq(bike)
      expect(search.matching_manufacturer(Bike.all).pluck(:id).include?(bike2.id)).to be_falsey
    end

    it "does not return any bikes if we can't find the manufacturer" do
      manufacturer = FactoryBot.create(:manufacturer, name: "Special bikes co.")
      FactoryBot.create(:bike, manufacturer: manufacturer)
      search = BikeService::Searcher.new(manufacturer: "69696969", query: "")
      expect(search.matching_manufacturer(Bike.all).count).to eq(0)
    end

    it "finds matching bikes" do
      bike = FactoryBot.create(:bike)
      search = BikeService::Searcher.new(manufacturer_id: bike.manufacturer_id, query: "something")
      expect(search.matching_manufacturer(Bike.all).first).to eq(bike)
    end
  end

  describe "matching_colors" do
    it "finds matching colors" do
      color = FactoryBot.create(:color)
      bike = FactoryBot.create(:bike, tertiary_frame_color_id: color.id)
      FactoryBot.create(:bike)
      search = BikeService::Searcher.new(colors: "something, #{color.name}").matching_colors(Bike.all)
      expect(search.count).to eq(1)
      expect(search.first).to eq(bike)
    end
  end

  describe "friendly_find_serial" do
    it "finds matching serial segments" do
      bike = FactoryBot.create(:bike, serial_number: "st00d-fferd")
      bike.create_normalized_serial_segments
      bike.normalized_serial_segments
      search = BikeService::Searcher.new(serial: "fferds")
      result = search.friendly_find_serial
      expect(result.first).to eq(bike)
      expect(result.count).to eq(1)
      expect(search.close_serials.map(&:id)).to eq([bike.id])
    end
    it "doesn't find exact matches" do
      FactoryBot.create(:bike, serial_number: "K10DY00047-bkd")
      search = BikeService::Searcher.new(serial: "bkd-K1oDYooo47")
      expect(search.friendly_find_serial).to be_empty
    end
    it "returns nil" do
      expect(BikeService::Searcher.new(serial: "unknown").close_serials).to eq([])
    end
  end

  describe "matching_stolenness" do
    before :each do
      @non_stolen = FactoryBot.create(:bike)
      @stolen = FactoryBot.create(:stolen_bike)
    end
    it "selects only stolen bikes if non-stolen isn't selected" do
      search = BikeService::Searcher.new(stolen: "on")
      result = search.matching_stolenness(Bike.all)
      expect(result).to eq([@stolen])
    end
    it "selects only non-stolen bikes if stolen isn't selected" do
      search = BikeService::Searcher.new(non_stolen: "on")
      result = search.matching_stolenness(Bike.all)
      expect(result).to eq([@non_stolen])
    end
    it "returns all bikes" do
      search = BikeService::Searcher.new.matching_stolenness(Bike.all)
      expect(search).to eq(Bike.all)
    end
  end

  describe "matching_query" do
    it "selects bikes matching the attribute" do
      search = BikeService::Searcher.new(query: "something")
      bikes = Bike.all
      expect(bikes).to receive(:text_search).and_return("booger")
      expect(search.matching_query(bikes)).to eq("booger")
    end
  end
end
