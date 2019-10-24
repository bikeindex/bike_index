require "rails_helper"

RSpec.describe LocalizationHelper, type: :helper do
  describe "#language_choices" do
    context "in English" do
      it "returns the language choices with english included" do
        I18n.with_locale(:en) do
          choices = [
            ["English", "en"],
            ["Nederlands (Dutch)", "nl"],
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
          ]
          expect(language_choices).to eq(choices)
        end
      end
    end
  end
end
