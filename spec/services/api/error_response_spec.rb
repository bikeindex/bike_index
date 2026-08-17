require "rails_helper"

RSpec.describe API::ErrorResponse do
  describe "status_for" do
    it "maps by class, not by message" do
      expect(described_class.status_for(API::EndpointNotFound.new)).to eq 404
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
    context "with an invalid-UTF-8 message" do
      # enum errors interpolate the raw param value, and scanners send probe bytes
      let(:invalid_utf8) { "'\xC3\x28' is not a valid frame_material".dup.force_encoding(Encoding::UTF_8) }

      it "scrubs the bad bytes" do
        expect(invalid_utf8).not_to be_valid_encoding
        expect(described_class.message_for(StandardError.new(invalid_utf8)))
          .to include "is not a valid frame_material"
      end
    end

    context "with an exception whose message raises" do
      let(:error_class) do
        stub_const("RecordNotFoundProbe", Class.new(ActiveRecord::RecordNotFound) {
          def message = raise("message blew up")
        })
      end

      it "falls back to the class name" do
        expect(described_class.message_for(error_class.new)).to eq "RecordNotFoundProbe"
        expect(described_class.status_for(error_class.new)).to eq 404
      end
    end

    context "with an oauth error" do
      let(:response) { OpenStruct.new(description: "The access token is invalid") }

      it "prefixes it" do
        expect(described_class.message_for(APIAuthorization::Errors::OAuthUnauthorizedError.new(response)))
          .to eq "OAuth error: The access token is invalid"
      end
    end
  end
end
