require "rails_helper"

# Regression coverage for the API error handler. Exception messages routinely
# carry invalid UTF-8 — enum errors interpolate the raw param value
# ("'\xC3(' is not a valid frame_material"), scanners send probe bytes. An
# unscrubbed bad byte used to crash respond_to_error, producing a bare 500 with
# no JSON body and — worse — suppressing the Honeybadger notify, so API 500s
# went unreported.
RSpec.describe API::Base do
  let(:invalid_utf8) { "'\xC3\x28' is not a valid frame_material".dup.force_encoding(Encoding::UTF_8) }
  # respond_to_error reads e.backtrace, so exercise real raised exceptions
  def raised(klass, message)
    raise klass, message
  rescue => e
    e
  end

  describe ".status_code_for" do
    it "maps by class and message" do
      expect(described_class.status_code_for(ActiveRecord::RecordNotFound.new, "missing")).to eq 404
      expect(described_class.status_code_for(StandardError.new, "Unable to find endpoint")).to eq 404
      expect(described_class.status_code_for(StandardError.new, "boom")).to eq 500
    end
  end

  describe ".respond_to_error" do
    it "returns a JSON error response with CORS headers" do
      response = described_class.respond_to_error(raised(StandardError, "boom"))
      expect(response.status).to eq 500
      expect(response.headers["Access-Control-Allow-Origin"]).to eq "*"
      expect(JSON.parse(response.body.first)["error"]).to eq "boom"
    end

    it "maps a not-found message to 404" do
      response = described_class.respond_to_error(raised(StandardError, "Unable to find endpoint"))
      expect(response.status).to eq 404
    end

    context "with an invalid-UTF-8 message" do
      it "scrubs the bad bytes instead of crashing" do
        expect(invalid_utf8).not_to be_valid_encoding
        response = nil
        expect { response = described_class.respond_to_error(raised(StandardError, invalid_utf8)) }
          .not_to raise_error
        expect(response.status).to eq 500
        body = JSON.parse(response.body.first)
        expect(body["error"]).to include "is not a valid frame_material"
      end
    end
  end
end
