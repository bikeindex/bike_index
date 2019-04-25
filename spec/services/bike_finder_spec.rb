require "spec_helper"

RSpec.describe BikeFinder do
  describe ".find_matching" do
    it "returns nil when the target email is not present on any user or user_email record" do
      bike = FactoryBot.create(:ownership).bike
      absent_email = "bad-email@example.com"
      expect(User.exists?(email: absent_email)).to eq(false)
      expect(UserEmail.exists?(email: absent_email)).to eq(false)

      result = BikeFinder.find_matching(
        serial: bike.serial_number,
        owner_email: absent_email,
      )

      expect(result).to be_nil
    end

    it "returns match when the target email is present on a user record and the serial matches" do
      bike = FactoryBot.create(:ownership).bike
      expect(User.exists?(email: bike.creator.email)).to eq(true)
      UserEmail.delete_all
      expect(UserEmail.exists?(email: bike.creator.email)).to eq(false)

      result = BikeFinder.find_matching(
        serial: bike.serial_number,
        owner_email: bike.creator.email,
      )

      expect(result).to eq(bike)
    end

    it "returns match when the target email is present on a user_email record and the serial matches" do
      bike = FactoryBot.create(:ownership).bike
      User.first.update(email: "new-email@example.com")
      expect(User.exists?(email: bike.creator.email)).to eq(false)
      expect(UserEmail.exists?(email: bike.creator.email)).to eq(true)

      result = BikeFinder.find_matching(
        serial: bike.serial_number,
        owner_email: bike.creator.email,
      )

      expect(result).to eq(bike)
    end

    it "returns nil if neither the serial nor the normalized serial matches a bike record" do
      bike = FactoryBot.create(:ownership).bike

      result = BikeFinder.find_matching(
        serial: "bad-serial-number",
        owner_email: bike.creator.email,
      )

      expect(result).to be_nil
    end

    it "returns match if a user is found and the normalized serial number matches" do
      serial = "SOCOOL"
      normalized_serial = "50C001"
      bike = FactoryBot.create(:ownership).bike
      bike.update(serial_number: normalized_serial)

      result = BikeFinder.find_matching(
        serial: serial,
        owner_email: bike.creator.email,
      )

      expect(result).to eq(bike)
    end

    it "returns match if a user is found and the un-normalized serial number matches" do
      serial = "SOCOOL"
      bike = FactoryBot.create(:ownership).bike
      bike.update(serial_number: serial)

      result = BikeFinder.find_matching(
        serial: serial,
        owner_email: bike.creator.email,
      )

      expect(result).to eq(bike)
    end
  end
end
