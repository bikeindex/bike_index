require "rails_helper"

RSpec.describe TranslationHelper, type: :helper do
  describe "#language_choices" do
    context "in English" do
      it "returns the language choices with english included" do
        I18n.with_locale(:en) do
          choices = [
            ["English", "en"],
            ["Nederlands (Dutch)", "nl"],
            ["Norwegian (Bokmål)", "nb"]
          ]
          expect(language_choices).to eq(choices)
        end
      end
    end

    context "in Dutch" do
      it "returns with dutch included" do
        I18n.with_locale(:nl) do
          choices = [
            ["English (Engels)", "en"],
            ["Nederlands", "nl"],
            ["Noors (Bokmål)", "nb"]
          ]
          expect(language_choices).to eq(choices)
        end
      end
    end

    context "in Norwegian" do
      it "returns with norwegian included" do
        I18n.with_locale(:nb) do
          choices = [
            ["Engelsk", "en"],
            ["Nederlands (nederlandsk)", "nl"],
            ["norsk (bokmål)", "nb"]
          ]
          expect(language_choices).to eq(choices)
        end
      end
    end
  end
end
