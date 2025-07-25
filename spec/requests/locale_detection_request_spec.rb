require "rails_helper"

RSpec.describe "Locale detection", type: :request do
  before do
    FactoryBot.create(:exchange_rate_to_eur)
  end

  describe "given a currency conversion with a missing required exchange rate" do
    it "redirects to the root url in the default locale" do
      ExchangeRate.delete_all
      expect(ExchangeRate.count).to be_zero

      get "/", params: {locale: :nl}
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to match(/Nederlands .+ localization is unavailable.+/)

      get "/", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9"}
      expect(response).to redirect_to(root_url)
      expect(flash[:error]).to match(/Nederlands .+ localization is unavailable.+/)
    end
  end

  describe "requesting the root path" do
    context "given a user preference" do
      include_context :request_spec_logged_in_as_user

      it "renders the homepage in the requested language" do
        get "/"
        expect(response.body).to match(/bike registration/i)
        expect(response.body).to match('<meta http-equiv="Content-Language" content="en"/>')

        current_user.update(preferred_language: :nl)
        get "/"
        expect(response.body).to match(/fietsregistratie/i)
        expect(response.body).to match('<meta http-equiv="Content-Language" content="nl"/>')

        current_user.update(preferred_language: :nb)
        get "/"
        expect(response.body).to match(/sykkelregistrering/i)
        expect(response.body).to match('<meta http-equiv="Content-Language" content="nb"/>')

        current_user.update(preferred_language: :es)
        get "/"
        expect(response.body).to match(/registro de bicicletas/i)
        expect(response.body).to match('<meta http-equiv="Content-Language" content="es"/>')

        # current_user.update(preferred_language: :it)
        # get "/"
        # expect(response.body).to match(/Registrazione della bicicletta/i)
        # expect(response.body).to match('<meta http-equiv="Content-Language" content="it" />')
      end
    end

    context "given a valid locale query param" do
      it "renders the homepage in the requested language" do
        get "/", params: {locale: :en}
        expect(response.body).to match(/bike registration/i)
        get "/", params: {locale: :nl}
        expect(response.body).to match(/fietsregistratie/i)
        get "/", params: {locale: :nb}
        expect(response.body).to match(/sykkelregistrering/i)
        get "/", params: {locale: :es}
        expect(response.body).to match(/registro de bicicletas/i)
        # get "/", params: {locale: :it}
        # expect(response.body).to match(/registro de bicicletas/i)
      end
    end

    context "given an invalid locale query param" do
      it "renders the homepage in the default language" do
        get "/", params: {locale: :klingon}
        expect(response.body).to match(/bike registration/i)

        get "/", params: {locale: nil}
        expect(response.body).to match(/bike registration/i)
      end
    end

    context "given a valid ACCEPT_LANGUAGE header" do
      it "renders the homepage in the requested language" do
        get "/", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9"}
        expect(response.body).to match(/bike registration/i)

        get "/", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9"}
        expect(response.body).to match(/fietsregistratie/i)

        get "/", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "nb,en;q=0.9"}
        expect(response.body).to match(/sykkelregistrering/i)

        get "/", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "es,en;q=0.9"}
        expect(response.body).to match(/registro de bicicletas/i)
      end
    end

    context "given an unrecognized ACCEPT_LANGUAGE header" do
      it "renders the homepage in the default language" do
        unrecognized_locale = :zh
        expect(I18n.available_locales).to_not include(unrecognized_locale)
        get "/", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "#{unrecognized_locale};q=0.8"}
        expect(response.body).to match(/bike registration/i)
      end
    end

    context "given multiple detected locales" do
      include_context :request_spec_logged_in_as_user

      it "gives highest precedence to query param" do
        current_user.update_attribute :preferred_language, :es
        get "/", params: {locale: :nl}, headers: {"HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9"}
        expect(response.body).to match(/fietsregistratie/i)
        # It doesn't reset users preferences based on request
        expect(current_user.reload.preferred_language).to eq "es"
      end

      it "gives secondary precedence to user preference" do
        current_user.update_attribute :preferred_language, :nl
        get "/", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9"}
        expect(response.body).to match(/fietsregistratie/i)
        # It doesn't reset users preferences based on request
        expect(current_user.reload.preferred_language).to eq "nl"
      end

      it "gives lowest precedence to request headers" do
        current_user.update_attribute :preferred_language, nil
        get "/", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9"}
        expect(response.body).to match(/fietsregistratie/i)
        # It doesn't reset users preferences based on request
        expect(current_user.reload.preferred_language).to eq nil
      end

      it "falls back to the app default if no other locales are provided or recognized" do
        allow(I18n).to receive(:default_locale).and_return(:nl)
        current_user.update(preferred_language: nil)

        get "/", params: {locale: :klingon}, headers: {"HTTP_ACCEPT_LANGUAGE" => "k3"}

        expect(response.body).to match(/fietsregistratie/i)
        allow(I18n).to receive(:default_locale).and_call_original
      end
    end
  end

  describe "requesting an admin path" do
    include_context :request_spec_logged_in_as_superuser
    before { Organization.example } # Read replica

    context "given a user preference" do
      it "renders the admin dashboard in English" do
        current_user.update(preferred_language: :nl)
        get "/admin"
        expect(response.body).to match(/The best bike registry/i)
        get "/admin/bikes"
        expect(response.body).to match(/The best bike registry/i)
      end
    end

    context "given a valid locale query param" do
      it "renders the admin dashboard in English" do
        get "/admin", params: {locale: :nl}
        expect(response.body).to match(/The best bike registry/i)
        get "/admin/bikes", params: {locale: :nl}
        expect(response.body).to match(/The best bike registry/i)
      end
    end

    context "given a valid ACCEPT_LANGUAGE header" do
      it "renders the homepage in English" do
        get "/admin", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9"}
        expect(response.body).to match(/The best bike registry/i)
        get "/admin/users", params: {}, headers: {"HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9"}
        expect(response.body).to match(/The best bike registry/i)
      end
    end
  end
end
