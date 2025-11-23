require "rails_helper"

RSpec.describe RecoveryDisplay::AfterPhotoAttachJob, type: :job do
  let(:recovery_display) { FactoryBot.create(:recovery_display) }

  describe "#perform" do
    context "recovery display does not exist" do
      it "returns without error" do
        expect { described_class.new.perform(999_999) }.not_to raise_error
      end
    end

    context "recovery display has photo" do
      before do
        recovery_display.photo.attach(
          io: File.open(Rails.root.join("spec/fixtures/bike.jpg")),
          filename: "bike.jpg",
          content_type: "image/jpeg"
        )
      end

      it "processes the photo" do
        expect(recovery_display.photo_processed.attached?).to be_falsey
        described_class.new.perform(recovery_display.id)
        expect(recovery_display.reload.photo_processed.attached?).to be_truthy
      end
    end
  end
end
