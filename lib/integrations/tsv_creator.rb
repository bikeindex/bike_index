class TsvCreator

  def manufacturers_header
    "text\tcategory\tpriority\twebsite\tlogo\n"
  end

  def stolen_header
    "Make\tModel\tSerial\tDescription\tArticleOrGun\tDateOfTheft\tCaseNumber\tLEName\tLEContact\tComments\n"
  end

  def stolen_with_reports_header
    "Make\tModel\tSerial\tDescription\tDateOfTheft\tCaseNumber\tLEName\tLEContact\tComments\n"
  end

  def manufacturer_row(mnfg)
    row = "#{mnfg.name}\t"
    row << (mnfg.frame_maker ? 'Frame manufacturer' : 'Manufacturer')
    row << "\t"
    row << "#{mnfg.bikes.count}"
    row << "\t"
    row << "#{mnfg.website}"
    row << "\t"
    row << "#{mnfg.logo}" if mnfg.logo.present?
    "#{row}"
  end

  def create_manufacturer
    out_file = File.join(Rails.root,'/manufacturers.tsv')
    output = File.open(out_file, "w")
    output.puts manufacturers_header
    Manufacturer.all.each { |m| output.puts manufacturer_row(m) }
    uploader = TsvUploader.new
    uploader.store!(output)
    output.close
    puts uploader.url
  end

  def create_stolen
    out_file = File.join(Rails.root,'/current_stolen_bikes.tsv')
    output = File.open(out_file, "w")
    output.puts stolen_header
    StolenRecord.approveds.includes(:bike).each do |sr|
      output.puts sr.tsv_row if sr.tsv_row.present?
    end
    output
    uploader = TsvUploader.new
    uploader.store!(output)
    output.close
    puts uploader.url
  end

  def create_stolen_with_reports
    out_file = File.join(Rails.root,'/current_stolen_with_reports.tsv')
    output = File.open(out_file, "w")
    output.puts stolen_with_reports_header
    StolenRecord.approveds.where("police_report_number IS NOT NULL").
      where("police_report_department IS NOT NULL").joins(:bike).merge(Bike.with_serial).each do |sr|
        next unless sr.police_report_number.present?
      output.puts sr.tsv_row(false) if sr.tsv_row.present?
    end
    output
    uploader = TsvUploader.new
    uploader.store!(output)
    output.close
    puts uploader.url
  end

end