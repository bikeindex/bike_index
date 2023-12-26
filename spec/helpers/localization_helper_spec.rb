require "rails_helper"

RSpec.describe LocalizationHelper, type: :helper do
  describe "#language_choices" do
    context "in English" do
      it "returns the language choices with english included" do
        I18n.with_locale(:en) do
          choices = [
            ["English", "en"],
            ["Nederlands (Dutch)", "nl"],
            ["Norsk Bokmål (Norwegian)", "nb"],
            #["Español (Spanish)", "es"]
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
            ["Norsk Bokmål (Noors)", "nb"],
            #["Español (Spaans)", "es"]
          ]
          expect(language_choices).to eq(choices)
        end
      end
    end

    context "in Norwegian" do
      it "returns with norwegian included" do
        I18n.with_locale(:nb) do
          I18n.with_locale(:nb) do
            choices = [
              ["English (Engelsk)", "en"],
              ["Nederlands (Nederlandsk)", "nl"],
              ["Norsk Bokmål", "nb"],
              #["Español (Spansk)", "es"]
            ]
            expect(language_choices).to eq(choices)
          end
        end
      end
  
      # context "in Spanish" do
      #   it "returns with spanish included" do
      #     I18n.with_locale(:es) do
      #       choices = [
      #         ["English (Inglés)", "en"],
      #         ["Nederlands (Holandés)", "nl"],
      #         ["Norsk Bokmål (Noruego)", "nb"],
      #         ["Español", "es"]             
      #       ]
      #       expect(language_choices).to eq(choices)
      #     end
      #   end
      # end
    end
  end