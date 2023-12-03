require "rails_helper"

RSpec.describe VehicleHelper, type: :helper do
  describe "model_audit_frame_model_display" do
    let(:model_audit) { ModelAudit.new(frame_model: frame_model) }
    let(:frame_model) { "Something" }
    let(:target) { "<span>Something</span>" }
    it "responds with name" do
      expect(model_audit_frame_model_display(model_audit)).to eq target
    end
    context "unknown_model" do
      let(:frame_model) { nil }
      let(:target) { "<span class=\"less-strong\">Missing model</span>" }
      it "responds with name" do
        expect(model_audit_frame_model_display(model_audit)).to eq target
      end
    end
  end
end
