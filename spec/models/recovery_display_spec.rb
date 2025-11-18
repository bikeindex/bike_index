require "rails_helper"

RSpec.describe RecoveryDisplay, type: :model do
  describe "stolen_record" do
    let!(:recovery_display) { FactoryBot.create(:recovery_display_with_stolen_record) }
    it "finds the stolen_record" do
      recovery_display.reload
      expect(recovery_display.stolen_record).to be_present
    end
  end

  describe "image_exists? and image_processing" do
    let(:recovery_display) { RecoveryDisplay.new }
    it "is false by default" do
      expect(recovery_display.image_exists?).to be_falsey
      expect(recovery_display.image_processing?).to be_falsey
    end
    context "with image present" do
      let(:recovery_display) { RecoveryDisplay.new(updated_at: Time.current) }
      it "processing is true if recently updated" do
        # Sort of hacky, but gets us something
        allow(recovery_display).to receive(:image) { OpenStruct.new(file: OpenStruct.new("exists?" => false)) }
        expect(recovery_display.image_exists?).to be_falsey
        expect(recovery_display.image_processing?).to be_truthy
        recovery_display.updated_at = Time.current - 2.minutes
        expect(recovery_display.image_processing?).to be_falsey
      end
    end
  end

  describe "set_calculated_attributes" do
    it "sets time from input" do
      recovery_display = RecoveryDisplay.new(date_input: "04-27-1999")
      recovery_display.set_calculated_attributes
      expect(recovery_display.recovered_at).to eq(DateTime.strptime("04-27-1999 06", "%m-%d-%Y %H"))
    end
    it "sets time if no time" do
      recovery_display = RecoveryDisplay.new
      recovery_display.set_calculated_attributes
      expect(recovery_display.recovered_at).to be > Time.current - 5.seconds
    end
  end

  describe "from_stolen_record_id" do
    it "doesn't break if stolen record isn't present" do
      recovery_display = RecoveryDisplay.from_stolen_record_id(69)
      expect(recovery_display.errors).not_to be_present
      expect(recovery_display.calculated_owner_name).to be_nil
    end
    it "sets first name from stolen record" do
      user = FactoryBot.create(:user, name: "somebody Special")
      ownership = FactoryBot.create(:ownership, creator: user, user: user)
      stolen_record = FactoryBot.create(:stolen_record, bike: ownership.bike)
      RecoveryDisplay.new
      recovery_display = RecoveryDisplay.from_stolen_record_id(stolen_record.id)
      expect(recovery_display.calculated_owner_name).to eq "somebody Special"
      expect(recovery_display.quote_by).to eq("somebody")
      expect(recovery_display.location_string).to be_nil
    end
    context "stolen record" do
      let(:t) { Time.current }
      let(:bike) { FactoryBot.create(:bike) }
      let(:stolen_record) { FactoryBot.create(:stolen_record_recovered, :in_nyc, recovered_at: t, recovered_description: "stuff", bike: bike) }
      let(:recovery_display) { RecoveryDisplay.new }
      it "sets attrs from stolen record" do
        recovery_display = RecoveryDisplay.from_stolen_record_id(stolen_record.id)
        expect(recovery_display.quote).to eq("stuff")
        expect(recovery_display.recovered_at).to be > Time.current - 5.seconds
        expect(recovery_display.calculated_owner_name).to be_nil
        expect(recovery_display.stolen_record_id).to eq(stolen_record.id)
        expect(recovery_display.quote_by).to be_nil
        expect(recovery_display.location_string).to eq "New York"
      end
      context "bike hidden" do
        let(:bike) { FactoryBot.create(:bike, :with_ownership_claimed) }
        before { bike.update(marked_user_hidden: true) }
        it "still works expected" do
          expect(bike.reload.user_hidden).to be_truthy
          recovery_display = RecoveryDisplay.from_stolen_record_id(stolen_record.id)
          expect(recovery_display.quote).to eq("stuff")
          expect(recovery_display.recovered_at).to be > Time.current - 5.seconds
          expect(recovery_display.calculated_owner_name).to eq bike.current_ownership.user.display_name
          expect(recovery_display.stolen_record_id).to eq(stolen_record.id)
          expect(recovery_display.quote_by).to eq "User"
          expect(recovery_display.bike&.id).to eq bike.id
          expect(recovery_display.location_string).to eq "New York"
        end
      end
    end
  end
end
