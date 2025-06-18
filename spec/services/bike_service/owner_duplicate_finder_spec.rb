require "rails_helper"

RSpec.describe BikeService::OwnerDuplicateFinder do
  describe ".find_matching" do
    let(:bike) { FactoryBot.create(:bike, :with_ownership) }
    it "returns nil when the target email is not present on any bike, user, or user_email record" do
      expect(bike).to be_present
      missing_email = "bad-email@example.com"
      expect(Bike.exists?(owner_email: missing_email)).to eq(false)
      expect(User.exists?(email: missing_email)).to eq(false)
      expect(UserEmail.exists?(email: missing_email)).to eq(false)

      result = described_class.matching(
        serial: bike.serial_number,
        owner_email: missing_email
      ).first

      expect(result).to be_nil
    end

    it "returns match when the target email is present on a user record and the serial matches" do
      FactoryBot.create(:user, email: bike.owner_email)
      UserEmail.delete_all
      expect(User.exists?(email: bike.owner_email)).to eq(true)
      expect(UserEmail.exists?(email: bike.owner_email)).to eq(false)

      result = described_class.matching(
        serial: bike.serial_number,
        owner_email: bike.owner_email
      ).first

      expect(result).to eq(bike)
    end

    context "additional email" do
      let(:additional_email) { "new-email@example.com" }
      let!(:bike) { FactoryBot.create(:bike, :with_ownership, owner_email: additional_email) }
      it "returns match when the target email is present on a user_email record and the serial matches" do
        user = FactoryBot.create(:user_confirmed, email: "cool@email.com")
        user.additional_emails = additional_email
        expect(user.reload.user_emails.pluck(:email)).to match_array(["cool@email.com", "new-email@example.com"])
        expect(bike.reload.user&.id).to be_blank

        expect(User.exists?(email: additional_email)).to eq(false)
        expect(UserEmail.exists?(email: additional_email)).to eq(true)

        result = described_class.matching(
          serial: bike.serial_number,
          owner_email: additional_email
        ).first

        expect(result).to eq(bike)
      end
    end

    context "target email is present on a bike record and the serial matches" do
      let!(:bike) { FactoryBot.create(:bike) }
      it "returns match unless manufacturer_id incorrect" do
        expect(User.find_by(email: bike.owner_email)).to be_nil
        expect(UserEmail.find_by(email: bike.owner_email)).to be_nil

        result = described_class.matching(
          serial: bike.serial_number,
          owner_email: "  #{bike.owner_email} "
        ).pluck(:id)
        expect(result).to eq([bike.id])

        result2 = described_class.matching(
          serial: bike.serial_number,
          owner_email: "  #{bike.owner_email} ",
          manufacturer_id: bike.manufacturer_id
        ).pluck(:id)
        expect(result2).to eq([bike.id])

        result2 = described_class.matching(
          serial: bike.serial_number,
          owner_email: "  #{bike.owner_email} ",
          manufacturer_id: FactoryBot.create(:manufacturer).id
        ).pluck(:id)
        expect(result2).to eq([])
      end
    end

    it "returns nil if neither the serial nor the normalized serial match a bike record" do
      expect(bike).to be_present

      result = described_class.matching(
        serial: "bad-serial-number",
        owner_email: bike.creator.email
      ).first

      expect(result).to be_nil
    end

    it "returns match if an email and the normalized serial number match" do
      serial = "SOCOOL"
      normalized_serial = "50C001"
      expect(bike).to be_present
      bike.update(serial_number: serial)
      expect(bike.reload.serial_normalized).to eq normalized_serial

      result = described_class.matching(
        serial: serial,
        owner_email: bike.owner_email
      ).first
      expect(result).to eq(bike)

      result2 = described_class.matching(
        serial: "#{normalized_serial.downcase}\n",
        owner_email: bike.owner_email
      ).first
      expect(result2).to eq(bike)
    end

    context "with phone" do
      let(:serial1) { "socool" }
      let(:serial2) { "Another-serial-number" }
      let(:user1) { FactoryBot.create(:user, phone: phone1) }
      let(:phone1) { "2342342345" }
      let(:phone2) { "8883337777" }
      let(:bike1) { FactoryBot.create(:bike, owner_email: user1.email, serial_number: serial1) }
      let!(:bike1_ownership) { FactoryBot.create(:ownership, bike: bike1, owner_email: phone1, is_phone: true) }
      # Bike without an existing matching user
      let!(:bike2) { FactoryBot.create(:bike, :phone_registration, owner_email: phone2, serial_number: serial2) }
      it "matches based on phone" do
        bike1.reload # Update the seria
        bike2.reload
        expect(bike1.phone_registration?).to be_falsey
        expect(bike1.serial_normalized).to eq "50C001"
        expect(bike1.creator.id).to_not eq user1.id
        expect(bike2.phone_registration?).to be_truthy
        expect(bike2.serial_normalized).to eq "AN0THER 5ER1A1 NUM8ER"
        expect(described_class.send(:find_matching_user_ids, bike1.creator.email)).to eq([bike1.creator.id])
        expect(described_class.send(:find_matching_user_ids, bike1.creator.email, "92929292")).to eq([bike1.creator.id])
        expect(described_class.send(:find_matching_user_ids, "s@stuff.com", phone1)).to eq([user1.id])

        expect(described_class.matching(serial: "50C001", phone: " #{phone1}  ").first&.id).to eq bike1.id
        expect(described_class.matching(serial: serial1, owner_email: "a@b.com", phone: phone1).first&.id).to eq bike1.id
        expect(described_class.matching(serial: serial1, phone: phone2).first&.id).to be_blank

        expect(described_class.matching(serial: serial2, phone: phone1).first&.id).to be_blank
        expect(described_class.matching(serial: serial2, phone: phone2).first&.id).to eq bike2.id
        expect(described_class.matching(serial: serial2, phone: phone1).first&.id).to be_blank
        expect(described_class.matching(serial: serial2, owner_email: "a@b.com", phone: phone2).first&.id).to eq bike2.id
      end
    end

    context "special serials" do
      let!(:bike) { FactoryBot.create(:bike, :with_ownership, serial_number: serial) }
      let(:serial) { "made_without_serial" }
      it "returns nil" do
        expect(Bike.where(serial_number: serial).count).to eq 1
        result = described_class.matching(
          serial: "made_without_serial",
          owner_email: bike.owner_email
        ).first
        expect(result).to be_blank

        result2 = described_class.matching(
          serial: "Made Without Serial",
          owner_email: bike.owner_email
        ).first
        expect(result2).to be_blank
      end
      context "unknown" do
        let(:serial) { "unknown" }
        it "returns nil" do
          expect(Bike.where(serial_number: serial).count).to eq 1
          expect(bike.reload.serial_number).to eq "unknown"
          result = described_class.matching(
            serial: "UNknown",
            owner_email: bike.owner_email
          ).first
          expect(result).to be_blank

          expect(SerialNormalizer.normalized_and_corrected("idk")).to be_nil
          result2 = described_class.matching(
            serial: "idk",
            owner_email: bike.owner_email
          ).first
          expect(result2).to be_blank
        end
      end
    end
  end

  describe "matching_user_ids" do
    let(:user1) { FactoryBot.create(:user, phone: "7273824888") }
    let(:phone) { "2342342345" }
    let(:user_phone) { FactoryBot.create(:user_phone, phone: phone, user: user1) }
    let(:email) { "example@bikeindex.org" }
    let(:user2) { FactoryBot.create(:user, email: "something@stuff.com") }
    let(:user_email) { FactoryBot.create(:user_email, email: email, user: user2, confirmation_token: "lkhiunmluujhm") }
    it "finds by email or phone, even if not confirmed" do
      user_phone.reload
      user_email.reload
      expect(user1.confirmed?).to be_falsey
      expect(user_phone.confirmed?).to be_falsey
      expect(user1.phone).to_not eq phone
      expect(user2.confirmed?).to be_falsey
      expect(user_email.confirmed?).to be_falsey
      expect(user2.email).to_not eq email
      expect(described_class.send(:find_matching_user_ids, email)).to eq([user2.id])
      expect(described_class.send(:find_matching_user_ids, "something@stuff.com")).to eq([user2.id])
      expect(described_class.send(:find_matching_user_ids, email, "1234567890")).to eq([user2.id])
      expect(described_class.send(:find_matching_user_ids, nil, phone)).to eq([user1.id])
      expect(described_class.send(:find_matching_user_ids, nil, "7273824888")).to eq([user1.id])
      expect(described_class.send(:find_matching_user_ids, "example@example.com", phone)).to eq([user1.id])
      expect(described_class.send(:find_matching_user_ids, email, phone)).to match_array([user2.id, user1.id])
    end
    context "confirmed email and phone" do
      let(:user1) { FactoryBot.create(:user_confirmed, phone: phone2) }
      let(:phone2) { "5432234234" }
      let(:email2) { "fake@bikeindex.org" }
      let(:user_phone) { FactoryBot.create(:user_phone_confirmed, phone: phone, user: user1) }
      let(:email) { "example@bikeindex.org" }
      let(:user2) { FactoryBot.create(:user_confirmed, email: email2) }
      let(:user_email) { FactoryBot.create(:user_email, email: email, user: user2, confirmation_token: nil) }
      it "finds users confirmed email" do
        user_phone.reload
        user_email.reload
        expect(user1.confirmed?).to be_truthy
        expect(user_phone.confirmed?).to be_truthy
        expect(user2.confirmed?).to be_truthy
        expect(user_email.confirmed?).to be_truthy
        expect(described_class.send(:find_matching_user_ids, email)).to eq([user2.id])
        expect(described_class.send(:find_matching_user_ids, email2)).to eq([user2.id])
        expect(described_class.send(:find_matching_user_ids, email, "1234567890")).to eq([user2.id])
        expect(described_class.send(:find_matching_user_ids, email2, "1234567890")).to eq([user2.id])
        expect(described_class.send(:find_matching_user_ids, nil, phone)).to eq([user1.id])
        expect(described_class.send(:find_matching_user_ids, nil, phone2)).to eq([user1.id])
        expect(described_class.send(:find_matching_user_ids, "example@example.com", phone)).to eq([user1.id])
        expect(described_class.send(:find_matching_user_ids, "example@example.com", phone2)).to eq([user1.id])
        expect(described_class.send(:find_matching_user_ids, email, phone)).to match_array([user2.id, user1.id])
        expect(described_class.send(:find_matching_user_ids, email2, phone2)).to match_array([user2.id, user1.id])
      end
    end
  end
end
