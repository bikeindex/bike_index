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
            #["Español (Spansk)", "es"],
            #["Italiano (Italiensk)", "it"],
            #["עִברִית (Hebraisk)", "he"],
          ]
          expect(language_choices).to eq(choices)
        end
      end
    end

    context "in Dutch" do
      it "returns with Dutch included" do
        I18n.with_locale(:nl) do
          choices = [
            ["English (Engels)", "en"],
            ["Nederlands", "nl"],
            ["Norsk Bokmål (Noors)", "nb"],
            #["Español (Spaans)", "es"],
            #["Italiano (Italiaans)", "it"],
            #["עִברִית (Hebreeuws)", "he"],
          ]
          expect(language_choices).to eq(choices)
        end
      end
    end

    context "in Norwegian" do
      it "returns with Norwegian included" do
        I18n.with_locale(:nb) do
            choices = [
              ["English (Engelsk)", "en"],
              ["Nederlands (Nederlandsk)", "nl"],
              ["Norsk Bokmål", "nb"],
              #["Español (Spansk)", "es"],
              #["Italiano (Italiensk)", "it"],
              #["עִברִית (Hebraisk)", "he"],
            ]
            expect(language_choices).to eq(choices)
          end
        end
      end
  
      # context "in Spanish" do
      #   it "returns with Spanish included" do
      #     I18n.with_locale(:es) do
      #       choices = [
      #         ["English (Inglés)", "en"],
      #         ["Nederlands (Holandés)", "nl"],
      #         ["Norsk Bokmål (Noruego)", "nb"],
      #         ["Español", "es"],
      #         ["Italiano (Italiano)", "it"],
      #         ["עִברִית (Hebreo)", "he"],             
      #       ]
      #       expect(language_choices).to eq(choices)
      #     end
      #   end
      # end

      # context "in Italian" do
      #   it "returns with Italian included" do
      #     I18n.with_locale(:it) do
      #       choices = [
      #         ["English (Inglese)", "en"],
      #         ["Nederlands (Olandese)", "nl"],
      #         ["Norsk Bokmål (Norvegese)", "nb"],
      #         ["Español (Spagnolo)", "es"],
      #         ["Italiano", "it"],
      #         ["עִברִית (Ebraico)", "he"],             
      #       ]
      #       expect(language_choices).to eq(choices)
      #     end
      #   end
      # end

      # context "in Hebrew" do
      #   it "returns with Hebrew included" do
      #     I18n.with_locale(:he) do
      #       choices = [
      #         ["English (אנגלית)", "en"],
      #         ["Nederlands (הוֹלַנדִי)", "nl"],
      #         ["Norsk Bokmål (נורבגית)", "nb"],
      #         ["Español (ספרדית)", "es"],
      #         ["Italiano (אִיטַלְקִית)", "it"],
      #         ["עִברִית", "he"],             
      #       ]
      #       expect(language_choices).to eq(choices)
      #     end
      #   end
      # end
    end
  end