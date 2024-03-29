require "rails_helper"

RSpec.describe Color, type: :model do
  it_behaves_like "friendly_name_findable"
  it_behaves_like "autocomplete_hashable"

  describe "friendly_find" do
    it "finds users by email address when the case doesn't match" do
      color = FactoryBot.create(:color, name: "Poopy PANTERS")
      expect(Color.friendly_find("poopy panters")).to eq(color)
    end
    context "slug from color serializer" do
      let(:color) { FactoryBot.create(:color, name: "Silver, gray or bare metal") }
      it "finds" do
        expect(color.slug).to eq "silver"
        expect(Color.friendly_find("Silver, gray or bare metal")).to eq color
        expect(Color.friendly_find("silveR")).to eq color
      end
    end
  end

  describe "autocomplete_hash" do
    it "returns what we want" do
      color = FactoryBot.create(:color, name: "blue", display: "#386ed2")
      result = color.autocomplete_hash
      expect(result.keys).to eq(%i[id text category priority data])
      expect(result[:data][:display]).to eq color.display
      expect(result[:data][:search_id]).to eq("c_#{color.id}")
    end
  end

  describe "black" do
    context "not-existing" do
      it "creates it on first pass" do
        expect { Color.black }.to change(Color, :count).by(1)
      end
    end
  end

  describe "#select_options" do
    it "returns an array of arrays as expected by the rails select helper" do
      FactoryBot.create(:color, name: :black)
      FactoryBot.create(:color, name: :blue)

      options = Color.select_options
      expect(options).to be_an_instance_of(Array)
      expect(options.length).to eq(2)

      expect(options).to all(be_an_instance_of(Array))
      expect(options.map(&:length).uniq).to eq([2])
    end

    it "localizes as needed" do
      I18n.with_locale(:nl) do
        black = FactoryBot.create(:color, name: :black)
        blue = FactoryBot.create(:color, name: :blue)

        options = Color.select_options

        localized_black = options.first
        expect(localized_black.first).to be_an_instance_of(String)
        expect(localized_black.first).to_not eq(black.name)
        expect(localized_black.last).to eq(black.id)

        localized_blue = options.last
        expect(localized_blue.first).to be_an_instance_of(String)
        expect(localized_blue.first).to_not eq(blue.name)
        expect(localized_blue.last).to eq(blue.id)
      end
    end
  end
end
