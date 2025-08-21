# == Schema Information
#
# Table name: exports
#
#  id              :integer          not null, primary key
#  file            :text
#  file_format     :integer          default("csv")
#  kind            :integer          default("organization")
#  options         :jsonb
#  progress        :integer          default("pending")
#  rows            :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  organization_id :integer
#  user_id         :integer
#
# Indexes
#
#  index_exports_on_organization_id  (organization_id)
#  index_exports_on_user_id          (user_id)
#
require "rails_helper"

RSpec.describe Export, type: :model do
  let(:organization) { export.organization }

  describe "scope and method for stolen_no_blocklist" do
    let(:export) { FactoryBot.create(:export, options: {with_blocklist: true, headers: %w[party registered_at]}) }
    it "is with blocklist" do
      expect(export.stolen?).to be_truthy
      expect(export.option?(:with_blocklist)).to be_truthy
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

  describe "partial_registrations" do
    it "returns false if not present" do
      expect(Export.new.partial_registrations).to be_falsey
    end
    context "true" do
      let(:export) { Export.new(options: {partial_registrations: true}.as_json) }
      it "returns true if true" do
        expect(export.partial_registrations).to eq true
      end
    end
    context "only" do
      let(:export) { Export.new(options: {partial_registrations: "only"}.as_json) }
      it "returns true if true" do
        expect(export.partial_registrations).to eq "only"
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
      export.update(timezone: timezone, start_at: time_start, end_at: time_end, headers: %w[party registered_at], bike_code_start: "")
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
    let!(:bike1) { FactoryBot.create(:bike_organized, creation_organization: organization, created_at: Time.current - 1.day) }
    let!(:bike2) { FactoryBot.create(:bike_organized, creation_organization: organization) }
    let!(:bike3) { FactoryBot.create(:bike) }
    let(:export) { FactoryBot.build(:export_organization, organization: organization, end_at: Time.current - 1.hour) }
    it "assigns the bike ids" do
      bike1.reload
      expect(bike1.created_at).to be < export.end_at
      export.custom_bike_ids = "https://bikeindex.org/bikes/#{bike1.id}?organization_id=#{organization.slug}  \n#{bike3.id}, https://bikeindex.org/bikes/#{bike2.id}?organization_id=#{organization.slug}  "
      export.assign_exported_bike_ids
      expect(export.custom_bike_ids).to match_array([bike1.id, bike2.id, bike3.id])
      expect(export.bikes_scoped.pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(export.exported_bike_ids).to match_array([bike1.id, bike2.id])
      # Using _ separator: bikes search > export separator
      export.custom_bike_ids = "#{bike1.id}_#{bike3.id}_#{bike2.id}"
      expect(export.custom_bike_ids).to eq([bike1.id, bike3.id, bike2.id])
      export.assign_exported_bike_ids
      expect(export.exported_bike_ids).to match_array([bike1.id, bike2.id])
      # only_custom_bike_ids
      export.only_custom_bike_ids = true
      expect(export.bikes_scoped.pluck(:id)).to match_array([bike1.id, bike2.id])
      export.assign_exported_bike_ids
      expect(export.exported_bike_ids).to match_array([bike1.id, bike2.id])
      # only_custom_bike_ids with no custom bikes
      export.custom_bike_ids = ""
      export.assign_exported_bike_ids
      expect(export.custom_bike_ids).to be_nil
      expect(export.bikes_scoped.pluck(:id)).to match_array([])
      expect(export.exported_bike_ids).to match_array([])
      export.only_custom_bike_ids = "0" # Reassign to false for the
      # Bike1 is within the time parameters - so with no custom bikes, it returns that
      export.custom_bike_ids = ""
      export.assign_exported_bike_ids
      expect(export.bikes_scoped.pluck(:id)).to match_array([bike1.id])
      expect(export.exported_bike_ids).to match_array([bike1.id])
      # And it also returns the bike that is from the time period in addition to any custom bikes that are assigned
      export.custom_bike_ids = "bikeindex.org/bikes/#{bike3.id}  \n /bikes/#{bike2.id}, #{bike2.id}  "
      export.assign_exported_bike_ids
      expect(export.custom_bike_ids).to match_array([bike2.id, bike3.id])
      expect(export.bikes_scoped.pluck(:id)).to match_array([bike1.id, bike2.id])
      expect(export.exported_bike_ids).to match_array([bike1.id, bike2.id])
      # with only_custom_bike_ids it doesn't include bike from the time period
      export.only_custom_bike_ids = "1"
      export.assign_exported_bike_ids
      expect(export.custom_bike_ids).to match_array([bike2.id, bike3.id])
      expect(export.bikes_scoped.pluck(:id)).to match_array([bike2.id])
      expect(export.exported_bike_ids).to match_array([bike2.id])
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
      export.options = {avery_export: true}
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

  describe "assign_bike_stickers" do
    let(:export) { Export.new }
    it "is true if assign_bike_stickers" do
      expect(export.assign_bike_codes?).to be_falsey
      export.assign_bike_codes = true
      expect(export.assign_bike_codes?).to be_truthy
      export.options = {}
      expect(export.assign_bike_codes?).to be_falsey
      export.bike_code_start = "34324"
      expect(export.assign_bike_codes?).to be_truthy
    end
  end

  describe "bikes_scoped" do
    # Pending - we're getting the organization scopes up and running before migrating existing Spreadsheets::TsvCreator tasks
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
    let(:organization_full) { Organization.new(enabled_feature_slugs: %w[reg_address reg_phone reg_organization_affiliation reg_student_id reg_bike_sticker]) }
    let(:permitted_headers) { Export::PERMITTED_HEADERS }
    let(:additional_headers) { %w[address bike_sticker organization_affiliation phone student_id] }
    let(:all_headers) { permitted_headers + additional_headers }
    it "returns the array we expect" do
      expect(permitted_headers.count).to eq 15
      expect(Export.permitted_headers).to eq permitted_headers
      expect(Export.permitted_headers("include_paid")).to match_array all_headers
      expect(Export.permitted_headers(organization)).to eq permitted_headers
      expect(organization_reg_phone.additional_registration_fields).to eq(["reg_phone"])
      expect(Export.permitted_headers(organization_reg_phone)).to eq(permitted_headers + ["phone"])
      expect(organization_full.additional_registration_fields.map { |s| s.gsub("reg_", "") }).to eq additional_headers
      expect(Export.permitted_headers(organization_full)).to eq all_headers
    end
    context "with impounded and partial" do
      let!(:organization) { FactoryBot.create(:organization_with_organization_features, enabled_feature_slugs: %w[impound_bikes show_partial_registrations]) }
      it "returns the array we expect" do
        expect(permitted_headers.count).to eq 15
        expect(Export.permitted_headers).to eq permitted_headers
        expect(Export.permitted_headers("include_paid")).to match_array all_headers
        expect(Export.permitted_headers(organization)).to match_array(permitted_headers + %w[is_impounded partial_registration])
      end
    end
    context "with bike_stickers from regional organization" do
      let!(:organization_in_region) { FactoryBot.create(:organization, :in_nyc) }
      let!(:organization_regional) { FactoryBot.create(:organization_with_organization_features, :in_nyc, enabled_feature_slugs: %w[bike_stickers regional_bike_counts]) }
      it "returns with reg_bike_sticker" do
        organization_regional.reload
        expect(organization_regional.regional?).to be_truthy
        expect(organization_regional.regional_ids).to eq([organization_in_region.id])
        expect(organization_regional.enabled_feature_slugs).to eq(%w[bike_stickers reg_bike_sticker regional_bike_counts])
        expect(Export.permitted_headers(organization_regional)).to eq(permitted_headers + ["bike_sticker"])
        expect(organization_regional.enabled?("reg_student_id")).to be_falsey
        expect(organization_regional.enabled?("reg_bike_sticker")).to be_truthy
        expect(organization_regional.additional_registration_fields).to eq(["reg_bike_sticker"])
        expect(Export.permitted_headers(organization_regional)).to eq(permitted_headers + ["bike_sticker"])

        organization_in_region.update(updated_at: Time.current) # To bump enabled features there
        organization_in_region.reload
        expect(organization_in_region.regional?).to be_falsey
        expect(organization_in_region.regional_parents.pluck(:id)).to eq([organization_regional.id])
        expect(organization_in_region.enabled_feature_slugs).to eq(%w[bike_stickers reg_bike_sticker])
        expect(organization_in_region.enabled?("reg_student_id")).to be_falsey
        expect(organization_in_region.enabled?("reg_bike_sticker")).to be_truthy
        expect(organization_in_region.additional_registration_fields).to eq(["reg_bike_sticker"])
        expect(Export.permitted_headers(organization_in_region)).to eq(permitted_headers + ["bike_sticker"])
      end
    end
  end
end
