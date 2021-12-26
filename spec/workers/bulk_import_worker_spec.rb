require "rails_helper"

RSpec.describe BulkImportWorker, type: :job do
  let(:subject) { BulkImportWorker }
  let(:instance) { subject.new }
  let(:bulk_import) { FactoryBot.create(:bulk_import, progress: "pending", kind: kind) }
  let(:kind) { nil }
  let!(:black) { FactoryBot.create(:color, name: "Black") } # Because we use it as a default color

  let(:sample_csv_lines) do
    [
      %w[manufacturer model year color owner_email serial_number],
      ["Trek", "Roscoe 8", "2019", "Green", "test@bikeindex.org", "xyz_test"],
      ["Surly", "Midnight Special", "2018", "White", "test2@bikeindex.org", "example"]
    ]
  end
  let(:sample_csv_impounded_lines) do
    [
      %w[manufacturer model year color serial_number impounded_at impounded_street impounded_city impounded_state impounded_zipcode impounded_country impounded_id],
      ["Thesis", "OB1", "2020", "Pink", "xyz_test", "2021-02-04", "1409 Martin Luther King Jr Way", "Berkeley", "CA", "94710", "US", "ddd33333"],
      ["Salsa", "Warbird", "2021", "Purple", "example", Time.current.to_i, "327 17th St", "Oakland", "CA", "94612", ""]
    ]
  end
  # Only handling organization_import and impounded for now, Fuck it
  let(:csv_lines) { kind == "impounded" ? sample_csv_impounded_lines : sample_csv_lines }
  let(:csv_string) { csv_lines.map { |r| r.join(",") }.join("\n") }
  let(:tempfile) do
    file = Tempfile.new
    file.write(csv_lines.join("\n"))
    file.rewind
    file
  end

  describe "perform" do
    context "bulk import already processed" do
      let(:bulk_import) { FactoryBot.create(:bulk_import, progress: "finished") }
      it "returns true" do
        allow_any_instance_of(BulkImport).to receive(:open_file) { csv_string }
        expect(instance).to_not receive(:register_bike)
        instance.perform(bulk_import.id)
      end
    end
    context "bulk import ascend no org" do
      let(:bulk_import) { FactoryBot.create(:bulk_import_ascend) }
      it "returns enqueues email, returns true" do
        Sidekiq::Worker.clear_all
        bulk_import.reload
        expect(bulk_import.import_errors?).to be_falsey
        expect(instance).to_not receive(:register_bike)
        expect {
          instance.perform(bulk_import.id)
        }.to change(UnknownOrganizationForAscendImportWorker.jobs, :count).by 1
        bulk_import.reload
        expect(bulk_import.pending?).to be_truthy
        expect(bulk_import.import_errors?).to be_truthy
        expect(UnknownOrganizationForAscendImportWorker.jobs.map { |j| j["args"] }.flatten).to eq([bulk_import.id])
      end
    end
    context "erroring" do
      let!(:color) { FactoryBot.create(:color, name: "White") }
      after { tempfile.close && tempfile.unlink }

      def bike_matches_target(bike)
        expect(bike.manufacturer).to eq Manufacturer.other
        expect(bike.manufacturer_other).to eq "Surly"
        expect(bike.primary_frame_color).to eq color
        expect(bike.frame_size).to eq "19in"
        expect(bike.serial_number).to eq "ZZZZ"
        expect(bike.owner_email).to eq "test2@bikeindex.org"
        expect(bike.description).to eq "Midnight Special"
      end

      context "valid bike and an invalid bike with substituted header" do
        let(:target_line_error) { [2, ["Owner email can't be blank"]] }
        let(:csv_lines) do
          [
            "Product Description,Vendor,Brand,Color,Size,Serial Number,Customer Last Name,Customer First Name,Customer Email",
            '"Blah","Blah","Surly","","","XXXXX","","",""',
            '"Midnight Special","","Surly","White","19","ZZZZ","","","test2@bikeindex.org"'
          ]
        end
        it "registers bike, adds row that is an error" do
          allow_any_instance_of(BulkImport).to receive(:open_file) { File.open(tempfile.path, "r") }
          expect {
            instance.perform(bulk_import.id)
          }.to change(Bike, :count).by 1
          bulk_import.reload
          expect(bulk_import.line_import_errors).to eq([target_line_error])
          expect(bulk_import.headers).to eq(%w[description vendor manufacturer color frame_size serial_number customer_last_name customer_first_name owner_email])
          expect(bulk_import.import_errors).to eq({line: [target_line_error]}.as_json)
          expect(bulk_import.bikes.count).to eq 1
          expect(BulkImport.line_errors.pluck(:id)).to eq([bulk_import.id])
        end
      end
      context "invalid file" do
        let(:csv_lines) do
          [
            "Product Description,Vendor,Brand,Color,Size,Serial Number,Customer Last Name,Customer First Name,Customer Email",
            '"\"","\'","Surly","","","XXXXX","","","","',
            '"Midnight Special","","Surly","White","19","ZZZZ","","","test2@bikeindex.org"'
          ]
        end
        it "stores error line, resumes post errored line successfully" do
          allow_any_instance_of(BulkImport).to receive(:open_file) { File.open(tempfile.path, "r") }
          # It should throw an error and not create a bike
          expect {
            expect { instance.perform(bulk_import.id) }.to raise_error(CSV::MalformedCSVError)
          }.to change(Bike, :count).by 0
          bulk_import.reload
          expect(bulk_import.progress).to eq "finished"
          expect(bulk_import.line_import_errors).to be_nil
          expect(bulk_import.file_import_errors_with_lines).to eq([["Any value after quoted field isn't allowed in line 1.", 1]])
          # Note: we don't have auto-resume built in right now. You have to manually go in through the console
          # and set the progress to be "ongoing", then re-enqueue
          bulk_import.update_attribute :progress, "ongoing"
          expect {
            instance.perform(bulk_import.id)
          }.to change(Bike, :count).by 1
          bulk_import.reload
          expect(bulk_import.bikes.count).to eq 1
          bike_matches_target(bulk_import.bikes.first)
          # And make sure it hasn't updated the file_import_errors
          expect(bulk_import.file_import_errors_with_lines).to eq([["Any value after quoted field isn't allowed in line 1.", 1]])
          expect(bulk_import.progress).to eq "finished"
        end
      end
    end
    context "empty import" do
      let(:csv_lines) { [sample_csv_lines[0].join(","), ""] }
      it "marks the import empty" do
        allow_any_instance_of(BulkImport).to receive(:open_file) { File.open(tempfile.path, "r") }
        expect {
          instance.perform(bulk_import.id)
        }.to_not change(Bike, :count)
        bulk_import.reload
        expect(bulk_import.no_bikes?).to be_truthy
        expect(bulk_import.import_errors?).to be_falsey
        expect(BulkImport.no_bikes.pluck(:id)).to eq([bulk_import.id])
      end
      context "ascend import" do
        let!(:bulk_import) { FactoryBot.create(:bulk_import_ascend) }
        let(:organization) { FactoryBot.create(:organization_with_auto_user, ascend_name: "BIKELaneChiC", kind: "bike_shop", pos_kind: "ascend_pos") }
        it "resolves error, assigns organization and processes" do
          bulk_import.check_ascend_import_processable!
          bulk_import.reload
          expect(bulk_import.import_errors?).to be_truthy
          # Create organization here
          expect(organization).to be_present
          expect(bulk_import.organization).to_not be_present
          expect {
            instance.perform(bulk_import.id)
          }.to_not change(UnknownOrganizationForAscendImportWorker.jobs, :count)
          bulk_import.reload
          expect(bulk_import.no_bikes?).to be_truthy
          expect(bulk_import.import_errors?).to be_falsey
          expect(BulkImport.no_bikes.pluck(:id)).to eq([bulk_import.id])
          expect(bulk_import.organization_id).to eq organization.id
          expect(bulk_import.creator).to eq organization.auto_user
          # Only has bikes key - no ascend nil key
          expect(bulk_import.import_errors.keys).to eq(["bikes"])
        end
      end
    end
    context "valid file" do
      let!(:color_green) { FactoryBot.create(:color, name: "Green") }
      let!(:color_white) { FactoryBot.create(:color, name: "White") }
      let!(:surly) { FactoryBot.create(:manufacturer, name: "Surly") }
      let!(:trek) { FactoryBot.create(:manufacturer, name: "Trek") }
      let(:file_url) { "https://raw.githubusercontent.com/bikeindex/bike_index/main/public/import_all_optional_fields.csv" }
      let(:organization) { FactoryBot.create(:organization_with_auto_user) }
      # We're stubbing the method to use a remote file, don't pass the file in and let it use the factory default
      let!(:bulk_import) { FactoryBot.create(:bulk_import, progress: "pending", user_id: nil, organization_id: organization.id) }
      it "creates the bikes, doesn't have any errors" do
        # In production, we actually use remote files rather than local files.
        # simulate what that process looks like by loading a remote file in the way we use open_file in BulkImport
        VCR.use_cassette("bulk_import-perform-success") do
          allow_any_instance_of(BulkImport).to receive(:open_file) { URI.parse(file_url).open }
          expect {
            instance.perform(bulk_import.id)
            # This test is being flaky! Add debug printout #2101 (actually after, but still...)
            pp bulk_import.import_errors if bulk_import.reload.blocking_error?
          }.to change(Bike, :count).by 2
          bulk_import.reload
          expect(bulk_import.progress).to eq "finished"
          expect(bulk_import.bikes.count).to eq 2
          expect(bulk_import.file_import_errors).to_not be_present

          bike1 = bulk_import.bikes.reorder(:created_at).first
          expect(bike1.primary_frame_color).to eq color_green
          expect(bike1.serial_number).to eq "xyz_test"
          expect(bike1.owner_email).to eq "test@bikeindex.org"
          expect(bike1.manufacturer).to eq trek
          expect(bike1.current_ownership.origin).to eq "bulk_import_worker"
          expect(bike1.current_ownership.status).to eq "status_with_owner"
          expect(bike1.creator).to eq organization.auto_user
          expect(bike1.creation_organization).to eq organization
          expect(bike1.year).to eq 2019
          expect(bike1.description).to eq "I love this, it's my favorite"
          expect(bike1.frame_size).to eq "29in"
          expect(bike1.frame_size_unit).to eq "in"
          expect(bike1.public_images.count).to eq 0
          expect(bike1.phone).to eq("8887776666")
          # Previously, was actually geocoding things - but that didn't seem to help people. So just use what was entered
          expect(bike1.registration_address).to eq({"street" => default_location[:address]})
          expect(bike1.registration_address_source).to eq "initial_creation"
          target_address_hash = default_location.slice(:latitude, :longitude).merge(street: default_location[:address])
          expect(bike1.address_hash.reject { |_k, v| v.blank? }.to_h).to eq target_address_hash.as_json
          expect(bike1.extra_registration_number).to be_nil
          expect(bike1.owner_name).to be_nil

          bike2 = bulk_import.bikes.reorder(:created_at).last
          expect(bike2.primary_frame_color).to eq color_white
          expect(bike2.serial_number).to eq "example"
          expect(bike2.owner_email).to eq "test2@bikeindex.org"
          expect(bike2.manufacturer).to eq surly
          expect(bike2.current_ownership.origin).to eq "bulk_import_worker"
          expect(bike2.current_ownership.registration_info).to eq({"user_name" => "Sally"})
          expect(bike2.creator).to eq organization.auto_user
          expect(bike2.creation_organization).to eq organization
          expect(bike2.year).to_not be_present
          expect(bike2.public_images.count).to eq 1
          expect(bike2.frame_size).to eq "m"
          expect(bike2.frame_size_unit).to eq "ordinal"
          expect(bike2.registration_address).to_not be_present
          expect(bike2.phone).to be_nil
          expect(bike2.extra_registration_number).to eq "extra serial number"
          expect(bike2.owner_name).to eq "Sally"
        end
      end
      context "valid file, kind: impounded" do
        let(:file_url) { "https://raw.githubusercontent.com/bikeindex/bike_index/main/public/import_impounded_all_optional_fields.csv" }
        let(:impound_configuration) { FactoryBot.create(:impound_configuration) }
        let(:organization) { impound_configuration.organization }
        let!(:state) { FactoryBot.create(:state_california) }
        let(:user) { FactoryBot.create(:organization_member, organization: organization) }
        # We're stubbing the method to use a remote file, don't pass the file in and let it use the factory default
        let!(:bulk_import) { FactoryBot.create(:bulk_import, progress: "pending", user_id: user.id, kind: "impounded", organization_id: organization.id) }
        include_context :geocoder_real
        let(:bike1_tareget) do
          {
            primary_frame_color: color_green,
            serial_number: "xyz_test",
            owner_email: "test@bikeindex.org",
            manufacturer: trek,
            creator: organization.auto_user,
            creation_organization_id: organization.id,
            year: 2019,
            description: "I love this, it's my favorite",
            frame_size: "29in",
            frame_size_unit: "in",
            registration_address: {},
            public_images: [],
            phone: "8887776666",
            extra_registration_number: nil,
            owner_name: nil,
            status: "status_impounded"
          }
        end
        let(:bike2_target) do
          {
            primary_frame_color: color_white,
            serial_number: "example",
            owner_email: "test2@bikeindex.org",
            manufacturer: surly,
            creator: organization.auto_user,
            creation_organization_id: organization.id,
            year: nil,
            frame_size: "m",
            frame_size_unit: "ordinal",
            registration_address: {},
            phone: nil,
            extra_registration_number: "extra serial number",
            owner_name: "Sally",
            status: "status_impounded"
          }
        end
        let(:impound_record1_target) do
          {
            impounded_description: "It was locked to a handicap railing",
            display_id: "2020-33333",
            unregistered_bike: true,
            street: "1409 Martin Luther King Jr Way",
            city: "Berkeley",
            zipcode: "94709", # NOTE: the zipcode that is entered is 94710
            state_id: state.id
          }
        end
        let(:impound_record2_target) do
          {
            impounded_description: "Appears to be abandoned",
            display_id: "1",
            unregistered_bike: true,
            street: "327 17th St",
            city: "Oakland",
            zipcode: "94612",
            state_id: state.id
          }
        end
        it "creates the bikes and impound records" do
          VCR.use_cassette("bulk_import-impounded-perform-success", match_requests_on: [:method]) do
            allow_any_instance_of(BulkImport).to receive(:open_file) { URI.parse(file_url).open }
            expect {
              instance.perform(bulk_import.id)
              # This test is being flaky! Add debug printout #2101
              pp bulk_import.import_errors if bulk_import.reload.blocking_error?
            }.to change(Bike, :count).by 2
            bulk_import.reload
            expect(bulk_import.progress).to eq "finished"
            expect(bulk_import.bikes.count).to eq 2
            expect(bulk_import.file_import_errors).to_not be_present
            expect(bulk_import.headers).to eq(%w[manufacturer model color owner_email serial_number year description phone secondary_serial owner_name frame_size photo impounded_at impounded_street impounded_city impounded_state impounded_zipcode impounded_country impounded_id impounded_description])

            bike1 = bulk_import.bikes.reorder(:created_at).first
            expect(bike1.current_ownership.origin).to eq "bulk_import_worker"
            expect(bike1.current_ownership.status).to eq "status_impounded"
            expect_attrs_to_match_hash(bike1, bike1_tareget)
            expect(bike1.created_by_notification_or_impounding?).to be_truthy
            bike1_impound_record = bike1.current_impound_record
            expect_attrs_to_match_hash(bike1_impound_record, impound_record1_target)
            expect(bike1_impound_record.impounded_at).to be_within(1.day).of Time.parse("2020-12-30")
            expect(bike1_impound_record.latitude).to be_within(0.01).of 37.881
            expect(bike1.address_hash).to eq bike1_impound_record.address_hash

            bike2 = bulk_import.bikes.reorder(:created_at).last
            expect_attrs_to_match_hash(bike2, bike2_target)
            expect(bike2.public_images.count).to eq 1
            expect(bike2.current_ownership.origin).to eq "bulk_import_worker"
            expect(bike1.current_ownership.status).to eq "status_impounded"
            expect(bike2.created_by_notification_or_impounding?).to be_truthy
            bike2_impound_record = bike2.current_impound_record
            expect_attrs_to_match_hash(bike2_impound_record, impound_record2_target)
            expect(bike2_impound_record.impounded_at).to be_within(1.day).of Time.parse("2021-01-01")
            expect(bike2_impound_record.latitude).to be_within(0.01).of 37.8053
            expect(bike2.address_hash).to eq bike2_impound_record.address_hash
          end
        end
      end
    end
  end

  context "with assigned bulk import" do
    before { instance.bulk_import = bulk_import }
    describe "process_csv" do
      after { tempfile.close && tempfile.unlink }
      context "without a header" do
        let(:csv_lines) { sample_csv_lines.slice(1, 2).map { |l| l.join(",") } }
        it "adds a file error" do
          expect(instance).to_not receive(:register_bike)
          instance.process_csv(File.open(tempfile.path, "r"))
          bulk_import.reload
          expect(bulk_import.file_import_errors.to_s).to match(/invalid csv headers/i)
          expect(bulk_import.progress).to eq "finished"
        end
      end
      context "with an invalid header" do
        let(:csv_lines) { ([%w[manufacturer email name color]] + sample_csv_lines.slice(1, 2)).map { |l| l.join(",") } }
        it "adds a file error" do
          expect(instance).to_not receive(:register_bike)
          instance.process_csv(File.open(tempfile.path, "r"))
          bulk_import.reload
          expect(bulk_import.file_import_errors.to_s).to match(/invalid csv headers/i)
          expect(bulk_import.progress).to eq "finished"
        end
      end
      context "with failed row" do
        let(:error_line) { ["Surly", "Midnight Special", "2018", nil, " ", "example"] }
        let(:csv_lines) { [[sample_csv_lines[0]], [error_line]].map { |l| l.join(",") } }
        let(:target_line_error) { [2, ["Owner email can't be blank"]] }
        it "registers a bike and adds a row error" do
          instance.process_csv(File.open(tempfile.path, "r"))
          expect(instance.line_errors.count).to eq 1
          expect(instance.line_errors.first).to eq target_line_error
          expect(bulk_import.progress).to eq "ongoing"
        end
      end
      context "with two valid bikes" do
        let(:csv_lines) { sample_csv_lines.map { |l| l.join(",") } }
        let(:bparam_line1) { instance.row_to_b_param_hash(sample_csv_lines[0].map(&:to_sym).zip(sample_csv_lines[1]).to_h) }
        let(:bparam_line2) { instance.row_to_b_param_hash(sample_csv_lines[0].map(&:to_sym).zip(sample_csv_lines[2]).to_h) }
        it "calls register bike with the valid bikes" do
          expect(instance).to receive(:register_bike).with(bparam_line1) { Bike.new(id: 1) }
          expect(instance).to receive(:register_bike).with(bparam_line2) { Bike.new(id: 1) }
          instance.process_csv(File.open(tempfile.path, "r"))
          bulk_import.reload
          expect(bulk_import.import_errors).to_not be_present
          expect(bulk_import.progress).to eq "ongoing"
        end
      end
    end

    describe "row_to_b_param_hash" do
      let(:row) { sample_csv_lines[0].map(&:to_sym).zip(csv_lines[1]).to_h }
      let(:target) do
        {
          owner_email: row[:owner_email],
          manufacturer_id: "Trek",
          is_bulk: true,
          color: "Green",
          serial_number: row[:serial_number],
          year: row[:year],
          frame_model: "Roscoe 8",
          description: nil,
          frame_size: nil,
          phone: nil,
          address: nil,
          extra_registration_number: nil,
          user_name: nil,
          send_email: true,
          creation_organization_id: nil
        }
      end
      describe "row_to_b_param_hash" do
        context "some extra bits" do
          it "returns the hash we want" do
            row_hash = row.merge(hidden: true, another_thing: "912913")
            result = instance.row_to_b_param_hash(row_hash)
            expect(result.select { |_k, v| v.present? }.keys).to eq([:bulk_import_id, :bike])
            expect(result[:bike]).to eq target
          end
        end
        context "with organization" do
          let(:organization) { FactoryBot.create(:organization) }
          let!(:bulk_import) { FactoryBot.create(:bulk_import, organization: organization, no_notify: true) }
          it "registers with organization" do
            expect(instance.row_to_b_param_hash(row)[:bike]).to eq target.merge(send_email: false, creation_organization_id: organization.id)
          end
        end
      end
      context "impounded" do
        let(:row) { sample_csv_impounded_lines[0].map(&:to_sym).zip(csv_lines[1]).to_h }
        let(:kind) { "impounded" }
        let(:target) do
          {
            owner_email: bulk_import.user.email,
            manufacturer_id: "Thesis",
            is_bulk: true,
            color: "Pink",
            serial_number: row[:serial_number],
            year: row[:year],
            frame_model: "OB1",
            description: nil,
            frame_size: nil,
            phone: nil,
            address: nil,
            extra_registration_number: nil,
            user_name: nil,
            send_email: true,
            creation_organization_id: nil
          }
        end
        let(:target_impound) do
          {
            impounded_at_with_timezone: "2021-02-04",
            street: "1409 Martin Luther King Jr Way",
            city: "Berkeley",
            state: "CA",
            zipcode: "94710",
            country: "US",
            display_id: "ddd33333",
            impounded_description: nil,
            organization_id: bulk_import.organization_id
          }
        end
        it "returns impounded kind" do
          result = instance.row_to_b_param_hash(row)
          expect(result.select { |_k, v| v.present? }.keys).to eq([:bulk_import_id, :bike, :impound_record])
          expect(result[:bike]).to eq target
          expect(result[:impound_record]).to eq target_impound
        end
      end
    end

    describe "register bike" do
      let!(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
      context "valid organization bike" do
        let(:organization) { FactoryBot.create(:organization_with_auto_user) }
        let!(:bulk_import) { FactoryBot.create(:bulk_import, organization: organization) }
        let(:row) { {manufacturer: " Surly", serial_number: "na", color: nil, owner_email: "test2@bikeindex.org", year: "2018", model: "Midnight Special", cycle_type: "tandem"} }
        def expect_registered_bike(passed_row)
          expect(organization.auto_user).to_not eq bulk_import.user
          expect(Bike.count).to eq 0
          expect {
            bike = instance.register_bike(instance.row_to_b_param_hash(passed_row))
            # This test is being flaky! Add debug printout #2101
            pp bike.errors unless bike.errors.none?
          }.to change(Bike, :count).by 1
          bike = Bike.last

          expect(bike.owner_email).to eq row[:owner_email]
          expect(bike.manufacturer).to eq manufacturer
          expect(bike.serial_number).to eq "unknown"
          expect(bike.frame_model).to eq "Midnight Special"

          ownership = bike.current_ownership
          expect(ownership.bulk?).to be_truthy
          expect(ownership.origin).to eq "bulk_import_worker"
          expect(ownership.organization).to eq organization
          expect(bike.creation_organization).to eq organization
          expect(bike.creator).to eq organization.auto_user
          bike
        end
        it "registers a bike" do
          bike = expect_registered_bike(row)

          expect(bike.primary_frame_color).to eq black
          expect(bike.paint_id).to be_blank
        end
        context "chartreuse color" do
          let(:color) { "chartreuse" }
          it "creates a new paint" do
            expect(Paint.count).to eq 0
            bike = expect_registered_bike(row.merge(color: color))

            expect(bike.primary_frame_color).to eq black
            expect(bike.paint_id).to be_present
            expect(Paint.count).to eq 1
            paint = bike.paint
            expect(paint.manufacturer_id).to be_blank # I don't know where this is set...
            expect(paint.name).to eq color
            expect(paint.color_id).to be_blank
            expect(paint.linked?).to be_falsey
          end
          context "with chartreuse paint" do
            let(:green) { FactoryBot.create(:color, name: "Green") }
            let!(:paint) { FactoryBot.create(:paint, name: color, color: green) }
            it "assigns" do
              expect(Paint.count).to eq 1
              bike = expect_registered_bike(row.merge(color: " ChartreuSE  "))

              expect(bike.primary_frame_color_id).to eq green.id
              expect(bike.paint_id).to be_present
              expect(Paint.count).to eq 1
              paint = bike.paint
              expect(paint.manufacturer_id).to be_blank # I don't know where this is set...
              expect(paint.name).to eq color
              expect(paint.color_id).to eq green.id
              expect(paint.linked?).to be_truthy
            end
          end
        end
      end
      context "not valid bike" do
        let(:row) { {manufacturer_id: "\n", serial_number: "na", color: nil} }
        let(:target_errors) { ["Owner email can't be blank"] }
        it "returns the invalid bike with errors" do
          expect {
            bike = instance.register_bike(instance.row_to_b_param_hash(row))
            expect(bike.id).to_not be_present
            expect(bike.cleaned_error_messages).to eq(target_errors)
          }.to change(Bike, :count).by 0
        end
      end
      context "not valid bike" do
        let(:row) { {manufacturer_id: "\n", serial_number: "", color: nil} }
        let(:target_errors) { ["Owner email can't be blank"] }
        it "returns the invalid bike with errors" do
          bulk_import.kind = "impounded"
          expect {
            expect(instance.register_bike(instance.row_to_b_param_hash(row))).to be_blank
          }.to change(Bike, :count).by 0
        end
      end
    end

    describe "rescue_blank_serials" do
      let(:blank_examples) { ["NA", "N/A", "unkown", "unkown", "           ", "none"] }
      let(:non_blank_examples) { %w[somethingna none8xc9x] }
      it "rescues blank serials, doesn't rescue non blank serials" do
        blank_examples.each do |blank|
          expect(instance.rescue_blank_serial(blank)).to eq("unknown"), "Failure: '#{blank}'"
        end
        non_blank_examples.each do |non_blank|
          expect(instance.rescue_blank_serial(non_blank)).to_not eq("unknown"), "Failure: #{non_blank}"
        end
      end
    end

    describe "convert_header" do
      context "headers match" do
        let(:header_string) { "ManufaCTURER,MODEL, YEAR, owner_email, serial Number, Stuff\n" }
        let(:target) { %i[manufacturer model year owner_email serial_number stuff] }
        it "leaves things alone" do
          expect(instance.convert_headers(header_string)).to eq target
          expect(instance.bulk_import.import_errors?).to be_falsey
        end
      end
      context "impounded" do
        let(:kind) { "impounded" }
        let(:header_string) { "BRAnd, vendor,MODEL,frame_model, frame YEAR,impounded_at, serial, impounded street, impounded-city, Stuff\n" }
        let(:target) { %i[manufacturer vendor model frame_model year impounded_at serial_number impounded_street impounded_city stuff] }
        it "returns the symbol if the symbol exists, without overwriting better terms" do
          expect(instance.convert_headers(header_string)).to eq target
          expect(instance.bulk_import.import_errors?).to be_falsey
        end
        context "crazy characters" do
          # EPS had a header with a nonbreaking space in it. It was very hard to debug. So - strip out any potential things like that
          let(:shitty_character) { CGI.unescapeHTML("&#65279;") }
          let(:header_string) { "#{shitty_character}impounded_id, BRAnd, vendor,MODEL,frame_model, frame YEAR,impounded_at, serial, impounded street, impounded-city, Stuff\n" }
          it "returns the target" do
            expect(header_string.first.ord).to eq 65279
            expect(instance.convert_headers(header_string)).to eq([:impounded_id] + target)
            expect(instance.bulk_import.import_errors?).to be_falsey
          end
        end
      end
      context "conversions" do
        let(:header_string) { "BRAnd, vendor,MODEL,frame_model, frame YEAR,email, serial, Stuff\n" }
        let(:target) { %i[manufacturer vendor model frame_model year owner_email serial_number stuff] }
        it "returns the symbol if the symbol exists, without overwriting better terms" do
          expect(instance.convert_headers(header_string)).to eq target
          expect(instance.bulk_import.import_errors?).to be_falsey
        end
        context "quote wrapped" do
          let(:header_string) { '"Product Description","Brand","Color","Size","Serial Number","Customer Last Name","Customer First Name","Customer Email"' }
          let(:target) { %i[description manufacturer color frame_size serial_number customer_last_name customer_first_name owner_email] }
          it "leaves things alone" do
            expect(instance.convert_headers(header_string)).to eq target
            expect(instance.bulk_import.import_errors?).to be_falsey
          end
        end
      end
    end
  end
end
