require "rails_helper"

RSpec.describe "Locale detection", type: :request do
  describe "requesting the root path" do
    context "given a user preference" do
      include_context :request_spec_logged_in_as_user

      it "renders the homepage in the requested language" do
        get "/"
        expect(response.body).to match(/bike registration/i)

        current_user.update(preferred_language: :nl)
        get "/"
        expect(response.body).to match(/fietsregistratie/i)
      end
    end

    context "given a valid locale query param" do
      it "renders the homepage in the requested language" do
        get "/", params: { locale: :en }
        expect(response.body).to match(/bike registration/i)
        get "/", params: { locale: :nl }
        expect(response.body).to match(/fietsregistratie/i)
      end
    end

    context "given an invalid locale query param" do
      it "renders the homepage in the default language" do
        get "/", params: { locale: :klingon }
        expect(response.body).to match(/bike registration/i)

        get "/", params: { locale: nil }
        expect(response.body).to match(/bike registration/i)
      end
    end

    context "given a valid ACCEPT_LANGUAGE header" do
      it "renders the homepage in the requested language" do
        get "/", params: {}, headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }
        expect(response.body).to match(/bike registration/i)

        get "/", params: {}, headers: { "HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9" }
        expect(response.body).to match(/fietsregistratie/i)
      end
    end

    context "given an unrecognized ACCEPT_LANGUAGE header" do
      it "renders the homepage in the default language" do
        unrecognized_locale = :zh
        expect(I18n.available_locales).to_not include(unrecognized_locale)
        get "/", params: {}, headers: { "HTTP_ACCEPT_LANGUAGE" => "#{unrecognized_locale};q=0.8" }
        expect(response.body).to match(/bike registration/i)
      end
    end

    context "given multiple detected locales" do
      include_context :request_spec_logged_in_as_user

      it "gives highest precedence to query param" do
        current_user.update_attribute :preferred_language, :es
        get "/", params: { locale: :nl }, headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }
        expect(response.body).to match(/fietsregistratie/i)
        # It doesn't reset users preferences based on request
        expect(current_user.reload.preferred_language).to eq "es"
      end

      it "gives secondary precedence to user preference" do
        current_user.update_attribute :preferred_language, :nl
        get "/", params: {}, headers: { "HTTP_ACCEPT_LANGUAGE" => "en-US,en;q=0.9" }
        expect(response.body).to match(/fietsregistratie/i)
        # It doesn't reset users preferences based on request
        expect(current_user.reload.preferred_language).to eq "nl"
      end

      it "gives lowest precedence to request headers" do
        current_user.update_attribute :preferred_language, nil
        get "/", params: {}, headers: { "HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9" }
        expect(response.body).to match(/fietsregistratie/i)
        # It doesn't reset users preferences based on request
        expect(current_user.reload.preferred_language).to eq nil
      end

      it "falls back to the app default if no other locales are provided or recognized" do
        allow(I18n).to receive(:default_locale).and_return(:nl)
        current_user.update(preferred_language: nil)

        get "/", params: { locale: :klingon }, headers: { "HTTP_ACCEPT_LANGUAGE" => "k3" }

        expect(response.body).to match(/fietsregistratie/i)
        allow(I18n).to receive(:default_locale).and_call_original
      end
    end
  end

  describe "requesting an admin path" do
    include_context :request_spec_logged_in_as_superuser

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
        get "/admin", params: { locale: :nl }
        expect(response.body).to match(/The best bike registry/i)
        get "/admin/bikes", params: { locale: :nl }
        expect(response.body).to match(/The best bike registry/i)
      end
    end

    context "given a valid ACCEPT_LANGUAGE header" do
      it "renders the homepage in English" do
        get "/admin", params: {}, headers: { "HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9" }
        expect(response.body).to match(/The best bike registry/i)
        get "/admin/users", params: {}, headers: { "HTTP_ACCEPT_LANGUAGE" => "nl,en;q=0.9" }
        expect(response.body).to match(/The best bike registry/i)
      end
    end
  end
end
