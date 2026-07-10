require "rails_helper"

RSpec.describe IpSpoofAttackFilter, type: :request do
  # Reproduce production's exception handling. Test defaults to show_exceptions = :rescuable,
  # which re-raises the (non-rescuable) IpSpoofAttackError up to the filter and masked this bug
  # for months. Production uses :all, where ShowExceptions renders the error into a 500 before
  # the filter — sitting above it in the stack — could ever rescue it.
  around do |example|
    env = Rails.application.env_config
    original = env["action_dispatch.show_exceptions"]
    env["action_dispatch.show_exceptions"] = :all
    example.run
  ensure
    env["action_dispatch.show_exceptions"] = original
  end

  let(:client_ip) { "251.252.74.114" }
  let(:forwarded_for) { "211.112.215.202,109.123.246.221, 172.71.131.189" }

  context "when the IP-header triple is contradictory" do
    let(:spoofed_headers) do
      {"HTTP_CLIENT_IP" => client_ip, "HTTP_X_FORWARDED_FOR" => forwarded_for}
    end

    it "returns 403 on a normal route" do
      get "/", headers: spoofed_headers

      expect(response.status).to eq(403)
      expect(response.body).to eq("Forbidden")
    end

    it "returns 403 on the error page, not 500" do
      # errors#not_found renders the full HTML layout — the exact path that 500'd 1,208 times
      # when a scanner walked unrouted paths (*unmatched_route → errors#not_found) with spoofed
      # headers. /404 exercises the same controller and layout without the prod-only catch-all.
      get "/404", headers: spoofed_headers

      expect(response.status).to eq(403)
      expect(response.body).to eq("Forbidden")
    end

    context "with a matching HTTP_FORWARDED header" do
      let(:spoofed_headers) do
        super().merge("HTTP_FORWARDED" => "for=211.112.215.202, for=109.123.246.221, for=172.71.131.189")
      end

      it "returns 403" do
        get "/", headers: spoofed_headers

        expect(response.status).to eq(403)
        expect(response.body).to eq("Forbidden")
      end
    end

    it "does not spoof-block non-HTML formats, which skip the layout that reads remote_ip" do
      get "/404.json", headers: spoofed_headers

      expect(response.status).to eq(404)
      expect(response.media_type).to eq("application/json")
    end
  end

  context "when only one of the IP headers is present" do
    it "does not trip the filter for HTTP_CLIENT_IP alone" do
      get "/404", headers: {"HTTP_CLIENT_IP" => client_ip}

      expect(response.status).to eq(404)
    end

    it "does not trip the filter for HTTP_X_FORWARDED_FOR alone" do
      get "/404", headers: {"HTTP_X_FORWARDED_FOR" => forwarded_for}

      expect(response.status).to eq(404)
    end
  end
end
