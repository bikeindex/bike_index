require 'spec_helper'

describe LocaleHelper do
  describe :locale_names do
    it "returns the name and code pair for all available locales" do
      I18n.available_locales = [:en, :es]
      I18n.stub(:t).with("language", locale: :en).and_return "English"
      I18n.stub(:t).with("language", locale: :es).and_return "Español"
      helper.locale_names.should == [{name: "English", code: "en"}, {name: "Español", code: "es"}]
    end
  end
end
