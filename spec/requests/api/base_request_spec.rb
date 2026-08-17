require "rails_helper"

# The API error-handler behaviors the endpoint request specs don't exercise - each
# is an exception that breaks respond_to_error itself, which used to escape as a
# bare 500 with no JSON body and no Honeybadger notify. Status mapping, the
# {"error": …} envelope, and CORS headers are covered by the v2/v3 request specs.
RSpec.describe API::Base do
  describe ".respond_to_error" do
    let(:response) { described_class.respond_to_error(error) }

    context "with an invalid-UTF-8 message" do
      # enum errors interpolate the raw param value - "'\xC3(' is not a valid
      # frame_material" - and scanners send probe bytes
      let(:invalid_utf8) { "'\xC3\x28' is not a valid frame_material".dup.force_encoding(Encoding::UTF_8) }
      # respond_to_error reads e.backtrace, so raise the exception for real
      let(:error) do
        raise StandardError, invalid_utf8
      rescue => e
        e
      end

      it "scrubs the bad bytes instead of crashing" do
        expect(invalid_utf8).not_to be_valid_encoding
        expect(response.status).to eq 500
        expect(JSON.parse(response.body.first)["error"]).to include "is not a valid frame_material"
      end
    end

    context "with an exception whose message raises" do
      # named, because the class name is what the fallback maps the status from
      let(:error_class) do
        stub_const("ActiveRecord::RecordNotFoundProbe", Class.new(ActiveRecord::RecordNotFound) {
          def message = raise("message blew up")
        })
      end
      let(:error) do
        raise error_class
      rescue => e
        e
      end

      it "falls back to the class name, keeping the status mapping" do
        expect(response.status).to eq 404
        expect(JSON.parse(response.body.first)["error"]).to eq "ActiveRecord::RecordNotFoundProbe"
      end
    end

    context "with an exception whose backtrace raises" do
      let(:error_class) do
        Class.new(StandardError) do
          def backtrace = raise("backtrace blew up")
        end
      end
      let(:error) do
        raise error_class
      rescue => e
        e
      end

      it "answers from the fallback rather than escaping" do
        expect(response.status).to eq 500
        expect(JSON.parse(response.body.first)["error"]).to eq "Internal Server Error"
      end
    end

    context "with an unraised exception" do
      let(:error) { ActiveRecord::RecordNotFound.new }

      it "handles the nil backtrace" do
        expect(response.status).to eq 404
      end
    end

    context "outside the test env" do
      let(:error) do
        raise StandardError, "some api failure"
      rescue => e
        e
      end
      before { allow(Rails.env).to receive(:test?).and_return(false) }

      it "logs to the Rails logger" do
        expect(Rails.logger).to receive(:error).with("StandardError: some api failure")
        expect(response.status).to eq 500
      end
    end
  end

  # grape_logging records the status of the exception it re-raises rather than of the
  # response the error handler builds, which recorded every handled error as a 500
  describe "logged status", type: :request do
    let(:logged_statuses) { [] }
    let(:subscription) do
      ActiveSupport::Notifications.subscribe("grape_key") do |*args|
        logged_statuses << ActiveSupport::Notifications::Event.new(*args).payload[:status]
      end
    end
    before { subscription }
    after { ActiveSupport::Notifications.unsubscribe(subscription) }

    it "matches the status the client received" do
      get "/api/v3/bikes/999999999"
      expect(response.status).to eq 404
      expect(logged_statuses.last).to eq 404

      get "/api/v3/unknown_endpoint"
      expect(response.status).to eq 404
      expect(logged_statuses.last).to eq 404

      get "/api/v3/me"
      expect(response.status).to eq 401
      expect(logged_statuses.last).to eq 401
    end
  end
end
