class TsvCreator
  def self.enqueue_creation
    TsvCreatorWorker.perform_async('create_manufacturer')
    TsvCreatorWorker.perform_async('create_daily_tsvs')
    TsvCreatorWorker.perform_in(20.minutes, 'create_stolen_with_reports', true)
    TsvCreatorWorker.perform_in(1.hour, 'create_stolen', true)
  end

  attr_reader :file_prefix

  def initialize
    @file_prefix = Rails.env.test? ? "/spec/fixtures/tsv_creation/" : ""
  end

  def manufacturers_header
    "id\ttext\tcategory\tpriority\twebsite\tlogo\n"
  end

  def stolen_header
    "Make\tModel\tSerial\tDescription\tArticleOrGun\tDateOfTheft\tCaseNumber\tLEName\tLEContact\tComments\n"
  end

  def stolen_with_reports_header
    "Make\tModel\tSerial\tDescription\tDateOfTheft\tCaseNumber\tLEName\tLEContact\tComments\n"
  end

  def org_counts_header
    "Date\tStolen?\tName\tEmail\tlink\n"
  end

  def org_count_row(bike)
    row = bike.created_at.strftime("%m.%d.%Y")
    row << "\t"
    row << "true" if bike.stolen 
    row << "\t"
    row << bike.first_ownership.proper_owner_name if bike.first_ownership.proper_owner_name
    row << "\t#{bike.first_owner_email}"
    row << "\t#{ENV['BASE_URL']}/bikes/#{bike.id}\n"
    "#{row}"
  end

  def manufacturer_row(mnfg)
    popularity = mnfg.bikes.count + 1
    popularity = 500 if popularity > 500
    popularity = 250 if popularity.between?(250, 499)
    popularity = 100 if popularity.between?(100, 249)
    popularity = 10  if popularity.between?(2, 99)
    row = "#{mnfg.id}\t#{mnfg.name}\t"
    row << (mnfg.frame_maker ? 'Frame manufacturer' : 'Manufacturer')
    row << "\t"
    row << "#{mnfg.bikes.count}"
    row << "\t"
    row << "#{mnfg.website}"
    row << "\t"
    row << "#{mnfg.logo}" if mnfg.logo.present?
    "#{row}"
  end

  def create_org_count(organization, start_date=nil)
    start_date ||= Time.now.beginning_of_year
    obikes = organization.bikes.where('bikes.created_at >= ?', start_date)
    out_file = File.join(Rails.root, "#{@file_prefix}org_count_bikes.tsv")
    output = File.open(out_file, 'w')
    output.puts org_counts_header
    obikes.each { |b| output.puts org_count_row(b) }
    send_to_uploader(output)
  end

  # Not tested. Needs to be tested and made useful before use
  # def create_org_total_count(organization, start_date=nil)
  #   return "organization has no location" unless organization.locations.present?
  #   start_date ||= Time.now.beginning_of_year
  #   obikes = organization.bikes.where("created_at >= ?", start_date)
  #   organization_bikes = obikes.count
  #   box = Geocoder::Calculations.bounding_box(organization.locations.first, 50)
  #   stolen_ids = StolenRecord.within_bounding_box(box).pluck(:bike_id)
  #   non_org_stolen_count = (stolen_ids - obikes.pluck(:ids)).count
  # end

  def create_manufacturer
    out_file = File.join(Rails.root,"#{@file_prefix}manufacturers.tsv")
    output = File.open(out_file, "w")
    output.puts manufacturers_header
    Manufacturer.all.each { |m| output.puts manufacturer_row(m) }
    send_to_uploader(output)
  end

  def create_stolen(blacklist=false, stolen_records: nil)
    stolen_records ||= StolenRecord.approveds
    filename = "#{@file_prefix}#{"approved_" if blacklist}current_stolen_bikes.tsv"
    out_file = File.join(Rails.root, filename)
    output = File.open(out_file, "w")
    output.puts stolen_header
    stolen_records.includes(:bike).each do |sr|
      output.puts sr.tsv_row if sr.tsv_row.present?
    end
    send_to_uploader(output)
  end

  def create_stolen_with_reports(blacklist=false, stolen_records: nil)
    stolen_records ||= StolenRecord.approveds_with_reports
    filename = "#{@file_prefix}#{"approved_" if blacklist}current_stolen_with_reports.tsv"
    out_file = File.join(Rails.root, filename)
    output = File.open(out_file, "w")
    output.puts stolen_with_reports_header
    stolen_records.joins(:bike).merge(Bike.with_serial).each do |sr|
        next unless sr.police_report_number.present?
      output.puts sr.tsv_row(false) if sr.tsv_row.present?
    end
    send_to_uploader(output)
  end

  def send_to_uploader(output)
    uploader = TsvUploader.new
    uploader.store!(output)
    output.close
    if TsvUploader.storage.to_s.match(/fog/i) # If we're in fog, we need to open via a URL
      path = uploader.url
    else
      path = uploader.current_path
    end
    FileCacheMaintainer.update_file_info(path)
    output
  end

  def create_daily_tsvs
    @file_prefix = "#{@file_prefix}#{Time.now.strftime('%Y_%-m_%-d')}_"
    create_stolen(true, stolen_records: StolenRecord.approveds.tsv_today)
    create_stolen_with_reports(true, stolen_records: StolenRecord.approveds_with_reports.tsv_today)
    t = Time.now
    StolenRecord.tsv_today.map{ |sr| sr.update_attribute :tsved_at, t }
  end

end