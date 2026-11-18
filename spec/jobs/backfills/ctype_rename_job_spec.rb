require "rails_helper"

RSpec.describe Backfills::CtypeRenameJob, type: :job do
  let(:instance) { described_class.new }

  describe "perform" do
    let!(:cassette) { FactoryBot.create(:ctype, name: "Cog/Cassette/Freewheel") }
    let!(:remote) { FactoryBot.create(:ctype, name: "E-vehicle Display/Remote", secondary_name: "Electric Bike Computer") }

    it "renames, keeping the slug, and is idempotent" do
      instance.perform
      instance.perform

      expect(cassette.reload).to have_attributes(name: "Cassette", secondary_name: "Cog/Freewheel", slug: "cogcassettefreewheel")
      expect(remote.reload).to have_attributes(name: "E-vehicle Remote", secondary_name: "E-vehicle Display, Electric Bike Computer")
      expect(Ctype.friendly_find("Cog/Cassette/Freewheel")).to eq cassette
      expect(Ctype.friendly_find("Cassette")).to eq cassette
    end
  end
end
