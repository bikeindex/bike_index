require "rails_helper"

RSpec.describe BikeFinder do
  describe ".find_matching" do
    it "returns nil when the target email is not present on any bike, user, or user_email record" do
      bike = FactoryBot.create(:ownership).bike
      missing_email = "bad-email@example.com"
      expect(Bike.exists?(owner_email: missing_email)).to eq(false)
      expect(User.exists?(email: missing_email)).to eq(false)
      expect(UserEmail.exists?(email: missing_email)).to eq(false)

      result = BikeFinder.find_matching(
        serial: bike.serial_number,
        owner_email: missing_email
      )

      expect(result).to be_nil
    end

    it "returns match when the target email is present on a user record and the serial matches" do
      bike = FactoryBot.create(:ownership).bike
      UserEmail.delete_all
      expect(User.exists?(email: bike.creator.email)).to eq(true)
      expect(UserEmail.exists?(email: bike.creator.email)).to eq(false)

      result = BikeFinder.find_matching(
        serial: bike.serial_number,
        owner_email: bike.creator.email
      )

      expect(result).to eq(bike)
    end

    it "returns match when the target email is present on a user_email record and the serial matches" do
      expect(User.count).to eq 0
      user = FactoryBot.create(:user_confirmed, email: "cool@email.com")
      bike = FactoryBot.create(:ownership, creator: user).bike
      user.additional_emails = "new-email@example.com"
      expect(user.reload.user_emails.pluck(:email)).to match_array(["cool@email.com", "new-email@example.com"])

      expect(User.exists?(email: "new-email@example.com")).to eq(false)
      expect(UserEmail.exists?(email: "new-email@example.com")).to eq(true)

      result = BikeFinder.find_matching(
        serial: bike.serial_number,
        owner_email: "new-email@example.com"
      )

      expect(result).to eq(bike)
    end

    it "returns match when the target email is present on a bike record and the serial matches" do
      bike = FactoryBot.create(:bike)
      expect(User.find_by(email: bike.owner_email)).to be_nil
      expect(UserEmail.find_by(email: bike.owner_email)).to be_nil

      result = BikeFinder.find_matching(
        serial: bike.serial_number,
        owner_email: "  #{bike.owner_email} "
      )

      expect(result).to eq(bike)
    end

    it "returns nil if neither the serial nor the normalized serial match a bike record" do
      bike = FactoryBot.create(:ownership).bike

      result = BikeFinder.find_matching(
        serial: "bad-serial-number",
        owner_email: bike.creator.email
      )

      expect(result).to be_nil
    end

    it "returns match if an email and the normalized serial number match" do
      serial = "SOCOOL"
      normalized_serial = "50C001"
      bike = FactoryBot.create(:ownership).bike
      bike.update(serial_number: normalized_serial)

      result = BikeFinder.find_matching(
        serial: serial,
        owner_email: bike.creator.email
      )

      expect(result).to eq(bike)
    end

    it "returns match if an email and the un-normalized serial number match" do
      serial = "SOCOOL"
      bike = FactoryBot.create(:ownership).bike
      bike.update(serial_number: serial)

      result = BikeFinder.find_matching(
        serial: serial,
        owner_email: bike.creator.email
      )

      expect(result).to eq(bike)
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
        expect(BikeFinder.find_matching_user_ids(bike1.creator.email)).to eq([bike1.creator.id])
        expect(BikeFinder.find_matching_user_ids(bike1.creator.email, "92929292")).to eq([bike1.creator.id])
        expect(BikeFinder.find_matching_user_ids("s@stuff.com", phone1)).to eq([user1.id])

        expect(BikeFinder.find_matching(serial: "50C001", phone: " #{phone1}  ")&.id).to eq bike1.id
        expect(BikeFinder.find_matching(serial: serial1, owner_email: "a@b.com", phone: phone1)&.id).to eq bike1.id
        expect(BikeFinder.find_matching(serial: serial1, phone: phone2)&.id).to be_blank

        expect(BikeFinder.find_matching(serial: serial2, phone: phone1)&.id).to be_blank
        expect(BikeFinder.find_matching(serial: serial2, phone: phone2)&.id).to eq bike2.id
        expect(BikeFinder.find_matching(serial: serial2, phone: phone1)&.id).to be_blank
        expect(BikeFinder.find_matching(serial: serial2, owner_email: "a@b.com", phone: phone2)&.id).to eq bike2.id
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
      expect(BikeFinder.find_matching_user_ids(email)).to eq([user2.id])
      expect(BikeFinder.find_matching_user_ids("something@stuff.com")).to eq([user2.id])
      expect(BikeFinder.find_matching_user_ids(email, "1234567890")).to eq([user2.id])
      expect(BikeFinder.find_matching_user_ids(nil, phone)).to eq([user1.id])
      expect(BikeFinder.find_matching_user_ids(nil, "7273824888")).to eq([user1.id])
      expect(BikeFinder.find_matching_user_ids("example@example.com", phone)).to eq([user1.id])
      expect(BikeFinder.find_matching_user_ids(email, phone)).to match_array([user2.id, user1.id])
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
        expect(BikeFinder.find_matching_user_ids(email)).to eq([user2.id])
        expect(BikeFinder.find_matching_user_ids(email2)).to eq([user2.id])
        expect(BikeFinder.find_matching_user_ids(email, "1234567890")).to eq([user2.id])
        expect(BikeFinder.find_matching_user_ids(email2, "1234567890")).to eq([user2.id])
        expect(BikeFinder.find_matching_user_ids(nil, phone)).to eq([user1.id])
        expect(BikeFinder.find_matching_user_ids(nil, phone2)).to eq([user1.id])
        expect(BikeFinder.find_matching_user_ids("example@example.com", phone)).to eq([user1.id])
        expect(BikeFinder.find_matching_user_ids("example@example.com", phone2)).to eq([user1.id])
        expect(BikeFinder.find_matching_user_ids(email, phone)).to match_array([user2.id, user1.id])
        expect(BikeFinder.find_matching_user_ids(email2, phone2)).to match_array([user2.id, user1.id])
      end
    end
  end
end
