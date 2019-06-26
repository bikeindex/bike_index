require "rails_helper"

RSpec.describe "Locale detection", type: :request do
  before do
    allow(Flipper).to receive(:enabled?).with(:localization, nil).and_return(true)
  end

  describe "requesting the root path" do
    context "given a user preference" do
      include_context :request_spec_logged_in_as_user
      before do
        allow(Flipper).to receive(:enabled?).with(:localization, current_user).and_return(true)
      end

      it "renders the homepage in the requested language" do
        get "/"
        expect(response.body).to match(/bike registration/i)

        current_user.update(preferred_language: :es)
        get "/"
        expect(response.body).to match(/registro de bicicleta/i)

        current_user.update(preferred_language: :nl)
        get "/"
        expect(response.body).to match(/fietsregistratie/i)
      end
    end

    context "given a valid locale query param" do
      it "renders the homepage in the requested language" do
        get "/", locale: :en
        expect(response.body).to match(/bike registration/i)

        get "/", locale: :es
        expect(response.body).to match(/registro de bicicleta/i)

        get "/", locale: :nl
        expect(response.body).to match(/fietsregistratie/i)
      end
    end

    context "given an invalid locale query param" do
      it "renders the homepage in the default language" do
        get "/", locale: :klingon
        expect(response.body).to match(/bike registration/i)
      end
    end

    context "given a valid ACCEPT_LANGUAGE header" do
      it "renders the homepage in the requested language" do
        get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }
        expect(response.body).to match(/bike registration/i)

        get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "es,en;q=0.9" }
        expect(response.body).to match(/registro de bicicleta/i)

        get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9" }
        expect(response.body).to match(/fietsregistratie/i)
      end
    end

    context "given an unrecognized ACCEPT_LANGUAGE header" do
      it "renders the homepage in the default language" do
        get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "es-ES;q=0.8,nl-NL;q=0.7" }
        expect(response.body).to match(/bike registration/i)
      end
    end

    context "given multiple detected locales" do
      include_context :request_spec_logged_in_as_user
      before do
        allow(Flipper).to receive(:enabled?).with(:localization, current_user).and_return(true)
      end

      it "gives highest precedence to query param" do
        current_user.update(preferred_language: :es)

        get "/",
            { locale: :nl },
            { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }

        expect(response.body).to match(/fietsregistratie/i), nil
      end

      it "gives secondary precedence to user preference" do
        current_user.update(preferred_language: :es)
        get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }
        expect(response.body).to match(/registro de bicicleta/i)
      end

      it "gives lowest precedence to request headers" do
        current_user.update(preferred_language: nil)
        get "/", {}, { "HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9" }
        expect(response.body).to match(/fietsregistratie/i)
      end

      it "falls back to the app default if no other locales are provided or recognized" do
        I18n.default_locale = :es
        current_user.update(preferred_language: nil)
        get "/", { locale: :klingon }, { "HTTP_ACCEPT_LANGUAGE" => "k3" }
        expect(response.body).to match(/registro de bicicleta/i)
      end
    end
  end
end
