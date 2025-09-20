require "rails_helper"

RSpec.shared_examples "active_periodable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.build(model_sym, start_at:, end_at:) }
  let(:start_at) { nil }
  let(:end_at) { nil }

  describe "periods" do
    it "is inactive when nil" do
      expect(instance.period_active?).to be_falsey
    end
    context "start_at in the future" do
      let(:start_at) { 1.minute.from_now }
      it "is inactive" do
        expect(instance.period_active?).to be_falsey
      end
    end
    context "start_at in past" do
      let(:start_at) { 1.year.ago }
      it "is active" do
        expect(instance.period_active?).to be_truthy
        instance.save!
        expect(instance.reload.period_active?).to be_truthy
        expect(subject.class.period_active.pluck(:id)).to eq([instance.id])
        expect(subject.class.period_inactive.pluck(:id)).to eq([])
      end
      context "with end_at in the future" do
        let(:end_at) { 1.week.from_now }

        it "is active" do
          expect(instance.period_active?).to be_truthy
        end
      end
      context "with end_at in the past" do
        let(:end_at) { 1.minute.ago }

        it "is active" do
          expect(instance.period_active?).to be_falsey
          instance.save!
          expect(instance.reload.period_active?).to be_falsey
          expect(instance.reload.period_inactive?).to be_truthy
          expect(subject.class.period_active.pluck(:id)).to eq([])
          expect(subject.class.period_inactive.pluck(:id)).to eq([instance.id])
        end
      end
    end
  end
end
