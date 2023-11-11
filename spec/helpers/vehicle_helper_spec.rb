require "rails_helper"

RSpec.describe VehicleHelper, type: :helper do
  describe "audit_frame_model_display" do
    let(:model_audit) { ModelAudit.new(frame_model: frame_model) }
    let(:frame_model) { "Something" }
    let(:target) { "<em>Something</em>" }
    it "responds with name" do
      expect(audit_frame_model_display(model_audit)).to eq target
    end
    context "unknown_model" do
      let(:frame_model) { nil }
      let(:target) { "<em class=\"less-strong\">Missing model</em>" }
      it "responds with name" do
        expect(audit_frame_model_display(model_audit)).to eq target
      end
    end
  end
end
