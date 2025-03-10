require "rails_helper"

RSpec.describe Ctype, type: :model do
  it_behaves_like "friendly_slug_findable"

  describe "#select_options" do
    let!(:axle_nuts) { FactoryBot.create(:ctype, name: "axle nuts") }
    let!(:basket) { FactoryBot.create(:ctype, name: "basket") }
    before { expect(Ctype.other).to be_present }

    it "returns an array of arrays as expected by the rails select helper" do
      options = Ctype.select_options
      expect(options).to be_an_instance_of(Array)
      expect(options.length).to eq(3)

      expect(options).to all(be_an_instance_of(Array))
      expect(options.map(&:last).uniq.count).to eq 3
    end

    it "localizes as needed" do
      I18n.with_locale(:nl) do
        options = Ctype.select_options

        localized_axle_nuts = options.find { _1.last == axle_nuts.id }
        expect(localized_axle_nuts.first).to be_an_instance_of(String)
        expect(localized_axle_nuts.first).to_not eq(axle_nuts.name)
        expect(localized_axle_nuts.last).to eq(axle_nuts.id)

        localized_basket = options.find { _1.last == basket.id }
        expect(localized_axle_nuts.first).to be_an_instance_of(String)
        expect(localized_basket.first).to_not eq(basket.name)
        expect(localized_basket.last).to eq(basket.id)
      end
    end
  end
end
