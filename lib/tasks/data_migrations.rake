namespace :data do
  desc "Create external registries"
  task create_external_registries: :environment do
    total_count = ExternalRegistry.registries_attrs.length
    puts "Ensuring #{total_count} external registries are persisted..."

    ActiveRecord::Base.transaction do
      ExternalRegistry.create_all do |record, i|
        if record.persisted?
          print_status(i, total_count)
        else
          raise ArgumentError, record.errors.full_messages.to_sentence
        end
      end
    end

    puts "\nDone!"
  end
end

def print_status(curr, total_count)
  digits = total_count.to_s.length
  count = [curr.to_s.rjust(digits, " "), total_count].join("/")
  percent = (curr * 100 / total_count.to_f).round(1).to_s.rjust(5, " ")
  $stdout.print "#{count} : #{percent}%\r"
  $stdout.flush
end
