require "rails_helper"

RSpec.describe GrapeErrors do
  describe "status_for" do
    it "maps by class, not by message" do
      expect(described_class.status_for(GrapeErrors::EndpointNotFound.new)).to eq 404
      expect(described_class.status_for(ActiveRecord::RecordNotFound.new)).to eq 404
      expect(described_class.status_for(APIAuthorization::Errors::OAuthUnauthorizedError.new(nil))).to eq 401
      expect(described_class.status_for(APIAuthorization::Errors::OAuthForbiddenError.new(nil))).to eq 403
      expect(described_class.status_for(StandardError.new("boom"))).to eq 500
    end

    context "with a bug worded like a lookup failure" do
      let(:error) { StandardError.new("Unable to find the S3 credentials") }

      # matching /unable to find/ made these 404s, which also dropped them from Honeybadger
      it "is a reportable 500" do
        expect(described_class.status_for(error)).to eq 500
        expect(described_class.report?(described_class.status_for(error))).to be_truthy
      end
    end

    context "with a subclass" do
      let(:error_class) { Class.new(ActiveRecord::RecordNotFound) }

      it "maps from the ancestor" do
        expect(described_class.status_for(error_class.new)).to eq 404
      end
    end

    context "with an exception carrying its own status" do
      let(:validation) { Grape::Exceptions::Validation.new(params: [:serial], message: "is missing") }
      let(:error) { Grape::Exceptions::ValidationErrors.new(errors: [validation]) }

      it "uses it" do
        expect(described_class.status_for(error)).to eq 400
      end

      context "when the status is nil" do
        it "is a 500" do
          expect(described_class.status_for(validation)).to eq 500
        end
      end
    end
  end

  describe "report?" do
    it "is true for 5xx only" do
      expect(described_class.report?(500)).to be_truthy
      expect(described_class.report?(404)).to be_falsey
      expect(described_class.report?(401)).to be_falsey
    end
  end

  describe "message_for" do
    context "with an oauth error" do
      let(:response) { OpenStruct.new(description: "The access token is invalid") }

      it "prefixes it" do
        expect(described_class.message_for(APIAuthorization::Errors::OAuthUnauthorizedError.new(response)))
          .to eq "OAuth error: The access token is invalid"
      end
    end

    context "with an exception whose message raises" do
      let(:error_class) do
        stub_const("RecordNotFoundProbe", Class.new(ActiveRecord::RecordNotFound) {
          def message = raise("message blew up")
        })
      end

      it "falls back to the class name, keeping the status mapping" do
        expect(described_class.message_for(error_class.new)).to eq "RecordNotFoundProbe"
        expect(described_class.status_for(error_class.new)).to eq 404
      end
    end
  end

  # Each of these is an exception that breaks response_for itself, which used to escape as
  # a bare 500 with no JSON body and no Honeybadger notify
  describe "response_for" do
    let(:response) { described_class.response_for(error) }

    context "with an invalid-UTF-8 message" do
      # enum errors interpolate the raw param value - "'\xC3(' is not a valid
      # frame_material" - and scanners send probe bytes
      let(:invalid_utf8) { "'\xC3\x28' is not a valid frame_material".dup.force_encoding(Encoding::UTF_8) }
      # response_for reads error.backtrace, so raise the exception for real
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

  # grape_logging logs a re-raised exception's own #status, so the errors below - which
  # carry none - were recorded as 500s while the client got the mapped status
  describe "logged status", type: :request do
    def logged_status(path)
      statuses = []
      callback = ->(_, _, _, _, payload) { statuses << payload[:status] }
      ActiveSupport::Notifications.subscribed(callback, "grape_key") { get path }
      statuses.last
    end

    it "matches the status the client received" do
      expect(logged_status("/api/v3/bikes/999999999")).to eq 404
      expect(response.status).to eq 404

      expect(logged_status("/api/v3/unknown_endpoint")).to eq 404
      expect(response.status).to eq 404

      expect(logged_status("/api/v3/me")).to eq 401
      expect(response.status).to eq 401
    end
  end
end
