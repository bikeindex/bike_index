task :start do
  system 'redis-server &'
  system 'bundle exec foreman start -f Procfile_development'
end

desc "Scrape single product"
task :create_stolen_tsv => :environment do
  out_file = File.join(Rails.root,'/output.tsv')
  headers = "Make\tModel\tSerial\tDescription\tArticleOrGun\tDateOfTheft\tCaseNumber\tLEName\tLEContact\tComments\n"
  output = File.open(out_file, "w")
  output.puts headers
  StolenRecord.where(current: true).where(approved: true).includes(:bike).each do |sr|
    output.puts sr.tsv_row
  end
  output
  
  uploader = TsvUploader.new
  uploader.store!(output)
  puts uploader.url
end
