require "rails_helper"

RSpec.describe Export, type: :model do
  let(:organization) { export.organization }

  describe "scope and method for stolen_no_blacklist" do
    let(:export) { FactoryBot.create(:export, options: { with_blacklist: true, headers: %w[party registered_at] }) }
    it "is with blacklist" do
      expect(export.stolen?).to be_truthy
      expect(export.option?(:with_blacklist)).to be_truthy
      expect(export.option?(:only_serials_and_police_reports)).to be_falsey
      expect(export.description).to eq "Stolen"
      expect(export.headers).to eq(["registered_at"]) # Just checking that we ignore things
      expect(Export.stolen).to eq([export])
    end
  end
  describe "organization" do
    let(:export) { FactoryBot.create(:export_organization) }
    it "is as expected" do
      expect(export.options).to eq(Export.default_options("organization"))
      expect(export.stolen?).to be_falsey
      expect(export.organization?).to be_truthy
      expect(export.option?("start_at")).to be_falsey
      expect(Export.organization).to eq([export])
      expect(export.bikes_scoped.to_sql).to eq organization.bikes.to_sql
    end
    context "no organization" do
      let(:export) { FactoryBot.build(:export_organization, organization: nil) }
      it "is invalid without organization" do
        export.save
        expect(export.valid?).to be_falsey
        expect(export.errors.full_messages.to_s).to match(/organization/i)
      end
    end
  end

  describe "calculated_progress" do
    let(:export) { Export.new(created_at: Time.current, progress: "pending") }
    it "returns the progress it is given" do
      expect(export.pending?).to be_truthy
      expect(export.calculated_progress).to eq "pending"
      export.progress = "finished"
      expect(export.calculated_progress).to eq "finished"
      export.progress = "errored"
      expect(export.calculated_progress).to eq "errored"
    end
    context "export created a lil bit ago" do
      let(:export) { Export.new(created_at: Time.current - 10.minutes, progress: "pending") }
      it "returns what it's given, unless incomplete" do
        expect(export.pending?).to be_truthy
        expect(export.calculated_progress).to eq "errored"
        export.progress = "ongoing"
        expect(export.calculated_progress).to eq "errored"
        export.progress = "finished"
        expect(export.calculated_progress).to eq "finished"
      end
    end
  end

  describe "tmp_file" do
    let(:export) { FactoryBot.build(:export, file_format: "csv") }
    it "has the correct format" do
      expect(export.kind).to eq "stolen"
      expect(export.tmp_file.path.to_s).to match(/\.csv\z/)
      export.tmp_file.close
      export.tmp_file.unlink
    end
  end

  describe "assignment" do
    let(:time_start) { "2018-01-30T23:57:56" }
    let(:time_end) { "2018-08-23T23:51:56" }
    let(:target_start) { 1517378276 }
    let(:target_end) { 1535086316 }
    let(:timezone) { "America/Chicago" }
    let(:export) { FactoryBot.build(:export) }
    it "assigns correctly" do
      export.update_attributes(timezone: timezone, start_at: time_start, end_at: time_end, headers: %w[party registered_at], bike_code_start: "")
      expect(export.start_at.to_i).to be_within(1).of target_start
      expect(export.end_at.to_i).to be_within(1).of target_end
      expect(export.headers).to eq(["registered_at"])
      expect(export.bike_code_start).to be_nil
      export.bike_code_start = "https://bikeindex.org/bikes/scanned/B21006000?organization_id=psu"
      expect(export.bike_code_start).to eq "B21006000"
    end
  end

  describe "custom_bike_ids=" do
    let(:organization) { FactoryBot.create(:organization) }
    let!(:bike1) { FactoryBot.create(:bike_organized, organization: organization, created_at: Time.current - 1.day) }
    let!(:bike2) { FactoryBot.create(:bike_organized, organization: organization) }
    let!(:bike3) { FactoryBot.create(:bike) }
    let(:export) { FactoryBot.build(:export_organization, organization: organization, end_at: Time.current - 1.hour) }
    it "assigns the bike ids" do
      bike1.reload
      expect(bike1.created_at).to be < export.end_at
      export.custom_bike_ids = "https://bikeindex.org/bikes/#{bike1.id}  \n#{bike3.id}, https://bikeindex.org/bikes/#{bike2.id}  "
      export.assign_exported_bike_ids
      expect(export.custom_bike_ids).to match_array([bike1.id, bike2.id, bike3.id])
      expect(export.bikes_scoped.pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(export.exported_bike_ids).to match_array([bike1.id, bike2.id])
      # Bike1 is within the time parameters - so with no custom bikes, it returns that
      export.custom_bike_ids = ""
      export.assign_exported_bike_ids
      expect(export.custom_bike_ids).to be_nil
      expect(export.bikes_scoped.pluck(:id)).to match_array([bike1.id])
      expect(export.exported_bike_ids).to match_array([bike1.id])
      # And it also returns the bike that is from the time period in addition to any custom bikes that are assigned
      export.custom_bike_ids = "bikeindex.org/bikes/#{bike3.id}  \n /bikes/#{bike2.id}, #{bike2.id}  "
      export.assign_exported_bike_ids
      expect(export.custom_bike_ids).to match_array([bike2.id, bike3.id])
      expect(export.bikes_scoped.pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(export.exported_bike_ids).to match_array([bike1.id, bike2.id])
    end
  end

  describe "avery_export" do
    let(:export) { Export.new }
    let(:target_url) { "https://avery.com?mergeDataURL=https%3A%2F%2Ffiles.bikeindex.org%2Fexports%2F820181214ccc.xlsx" }
    it "is false unless it should be true" do
      ENV["AVERY_EXPORT_URL"] = "https://avery.com?mergeDataURL="
      allow(export).to receive(:file_url) { "https://files.bikeindex.org/exports/820181214ccc.xlsx" }
      expect(export.avery_export?).to be_falsey
      expect(export.avery_export_url).to be_nil
      export.options = { avery_export: true }
      expect(export.avery_export?).to be_truthy
      expect(export.avery_export_url).to be_nil
      expect(export.assign_bike_codes?).to be_falsey
      expect(export.bike_stickers_assigned).to eq([])
      expect(export.bike_codes_removed?).to be_falsey
      export.progress = :finished
      expect(export.avery_export_url).to eq target_url
      export.options = export.options.merge(bike_code_start: "1111")
      expect(export.assign_bike_codes?).to be_truthy
      expect(export.bike_stickers_assigned).to eq([])
      expect(export.bike_codes_removed?).to be_falsey
    end
  end

  describe "avery_export_bike?" do
    context "unclaimed bike, with owner email" do
      let(:organization) { FactoryBot.create(:organization) }
      let(:user) { FactoryBot.create(:user_confirmed, name: "some name") }
      let(:bike) { FactoryBot.create(:creation_organization_bike, organization: organization) }
      let!(:b_param) do
        FactoryBot.create(:b_param, created_bike_id: bike.id,
                                    params: { bike: { address: "102 Washington Pl, State College" } })
      end
      let(:ownership) { FactoryBot.create(:ownership, creator: user, user: nil, bike: bike) }
      include_context :geocoder_real
      it "is exportable" do
        # Referencing the same address and the same cassette from a different spec, b/c I'm terrible ;)
        VCR.use_cassette("organization_export_worker-avery") do
          ownership.reload
          expect(bike.owner_name).to eq "some name"
          expect(bike.registration_address["address"]).to eq "102 Washington Pl"
          expect(Export.avery_export_bike?(bike)).to be_truthy
        end
      end
    end
  end

  describe "bikes_scoped" do
    # Pending - we're getting the organization scopes up and running before migrating existing TsvCreator tasks
    # But we eventually want to add stolen tsv's into here
    # context "stolen" do
    #   it "matches existing tsv scopes"
    # end
    context "organization" do
      let(:export) { FactoryBot.create(:export_organization, file: nil) }
      let(:start_time) { Time.current - 20.hours }
      let(:end_time) { Time.current - 5.minutes }
      it "has the scopes we expect" do
        expect(export.bikes_scoped.to_sql).to eq organization.bikes.to_sql
        export.options = export.options.merge("start_at" => start_time)
        expect(export.bikes_scoped.to_sql).to eq organization.bikes.where("bikes.created_at > ?", export.start_at).to_sql
        export.options = export.options.merge("end_at" => end_time)
        expect(export.bikes_scoped.to_sql).to eq organization.bikes.where(created_at: export.start_at..export.end_at).to_sql
      end
    end
  end

  describe "permitted_headers_for" do
    let(:organization) { Organization.new }
    let(:organization_reg_phone) { Organization.new(enabled_feature_slugs: ["reg_phone"]) }
    let(:organization_full) { Organization.new(enabled_feature_slugs: %w[reg_address reg_phone organization_affiliation bike_stickers]) }
    let(:permitted_headers) { Export::PERMITTED_HEADERS }
    let(:all_headers) { permitted_headers + %w[organization_affiliation phone address sticker] }
    it "returns the array we expect" do
      expect(permitted_headers.count).to eq 12
      expect(Export.permitted_headers).to eq permitted_headers
      expect(Export.permitted_headers("include_paid")).to match_array all_headers
      expect(Export.permitted_headers(organization)).to eq permitted_headers
      expect(Export.permitted_headers(organization_reg_phone)).to eq permitted_headers + ["phone"]
      expect(Export.permitted_headers(organization_full)).to eq all_headers
    end
  end
end
