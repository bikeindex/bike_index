require "rails_helper"

# The one API error-handler behavior the endpoint request specs don't exercise:
# an exception whose message carries invalid UTF-8 (enum errors interpolate the
# raw param value — "'\xC3(' is not a valid frame_material" — and scanners send
# probe bytes). The bad byte used to crash respond_to_error, yielding a bare 500
# with no JSON body and no Honeybadger notify. Status mapping, the {"error": …}
# envelope, and CORS headers are covered by the v2/v3 request specs.
RSpec.describe API::Base do
  describe ".respond_to_error with an invalid-UTF-8 message" do
    let(:invalid_utf8) { "'\xC3\x28' is not a valid frame_material".dup.force_encoding(Encoding::UTF_8) }
    # respond_to_error reads e.backtrace, so raise the exception for real
    let(:error) do
      raise StandardError, invalid_utf8
    rescue => e
      e
    end

    it "scrubs the bad bytes instead of crashing" do
      expect(invalid_utf8).not_to be_valid_encoding
      response = nil
      expect { response = described_class.respond_to_error(error) }.not_to raise_error
      expect(response.status).to eq 500
      expect(JSON.parse(response.body.first)["error"]).to include "is not a valid frame_material"
    end
  end
end
