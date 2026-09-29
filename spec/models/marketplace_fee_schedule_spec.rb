require "rails_helper"

RSpec.describe MarketplaceFeeSchedule, type: :model do
  describe "factory" do
    let(:marketplace_fee_schedule) { FactoryBot.create(:marketplace_fee_schedule) }

    it "is today's rates, already started" do
      expect(marketplace_fee_schedule).to be_valid
      expect(marketplace_fee_schedule).to have_attributes(platform_fee_percent: 9, platform_fee_cap_cents: 6900, processing_fee_percent: 3)
      expect(marketplace_fee_schedule.start_at).to be < Time.current
    end
  end

  describe "current" do
    let(:time) { Time.at(1_760_000_000) }
    let!(:first_schedule) { FactoryBot.create(:marketplace_fee_schedule, start_at: time - 2.days) }
    let!(:second_schedule) { FactoryBot.create(:marketplace_fee_schedule, start_at: time + 2.days) }
    let!(:future_schedule) { FactoryBot.create(:marketplace_fee_schedule, start_at: Time.current + 1.day) }

    it "is the latest schedule that has started" do
      expect(MarketplaceFeeSchedule.current(time - 3.days)).to be_nil
      expect(MarketplaceFeeSchedule.current(time)).to eq first_schedule
      expect(MarketplaceFeeSchedule.current(first_schedule.start_at)).to eq first_schedule
      expect(MarketplaceFeeSchedule.current(second_schedule.start_at - 1.second)).to eq first_schedule
      expect(MarketplaceFeeSchedule.current(second_schedule.start_at)).to eq second_schedule
      expect(MarketplaceFeeSchedule.current(time + 100.days)).to eq second_schedule
      expect(MarketplaceFeeSchedule.current(future_schedule.start_at)).to eq future_schedule
    end

    context "without a time" do
      it "is the schedule in effect now, not one that hasn't started" do
        expect(MarketplaceFeeSchedule.current).to eq second_schedule
      end
    end

    context "with no schedules" do
      before { MarketplaceFeeSchedule.delete_all }

      it "is nil" do
        expect(MarketplaceFeeSchedule.current).to be_nil
      end
    end
  end

  describe "validations" do
    let(:marketplace_fee_schedule) { FactoryBot.build(:marketplace_fee_schedule, **attributes) }
    let(:attributes) { {} }

    it "is valid" do
      expect(marketplace_fee_schedule).to be_valid
    end

    context "with blank values" do
      let(:attributes) { {platform_fee_percent: nil, platform_fee_cap_cents: nil, processing_fee_percent: nil, start_at: nil} }

      it "is invalid for every column" do
        expect(marketplace_fee_schedule).to be_invalid
        expect(marketplace_fee_schedule.errors.attribute_names).to match_array(attributes.keys)
      end
    end

    context "with percents at the limits" do
      let(:attributes) { {platform_fee_percent: 0, processing_fee_percent: 100} }

      it "is valid" do
        expect(marketplace_fee_schedule).to be_valid
      end
    end

    context "with percents outside 0 to 100" do
      let(:attributes) { {platform_fee_percent: -0.01, processing_fee_percent: 100.01} }

      it "is invalid" do
        expect(marketplace_fee_schedule).to be_invalid
        expect(marketplace_fee_schedule.errors.attribute_names).to match_array(%i[platform_fee_percent processing_fee_percent])
      end
    end

    context "with a cap of 0" do
      let(:attributes) { {platform_fee_cap_cents: 0} }

      it "is valid" do
        expect(marketplace_fee_schedule).to be_valid
      end
    end

    context "with a negative cap" do
      let(:attributes) { {platform_fee_cap_cents: -1} }

      it "is invalid" do
        expect(marketplace_fee_schedule).to be_invalid
        expect(marketplace_fee_schedule.errors.attribute_names).to eq([:platform_fee_cap_cents])
      end
    end

    context "with a start_at another schedule has" do
      let(:existing_schedule) { FactoryBot.create(:marketplace_fee_schedule) }
      let(:attributes) { {start_at: existing_schedule.start_at} }

      it "is invalid" do
        expect(marketplace_fee_schedule).to be_invalid
        expect(marketplace_fee_schedule.errors.attribute_names).to eq([:start_at])
      end
    end
  end

  describe "readonly?" do
    let!(:marketplace_fee_schedule) { FactoryBot.create(:marketplace_fee_schedule, start_at:) }
    let(:start_at) { Time.current - 1.minute }

    it "can't be changed or destroyed once started" do
      expect(marketplace_fee_schedule.readonly?).to be true
      expect { marketplace_fee_schedule.update(platform_fee_percent: 10) }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { marketplace_fee_schedule.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect(marketplace_fee_schedule.reload.platform_fee_percent).to eq 9
      expect(MarketplaceFeeSchedule.count).to eq 1
    end

    context "starting in the future" do
      let(:start_at) { Time.current + 1.day }

      it "can still be changed and destroyed" do
        expect(marketplace_fee_schedule.readonly?).to be false
        expect(marketplace_fee_schedule.update(platform_fee_percent: 10)).to be true
        expect(marketplace_fee_schedule.reload.platform_fee_percent).to eq 10
        marketplace_fee_schedule.destroy
        expect(MarketplaceFeeSchedule.count).to eq 0
      end
    end
  end
end
