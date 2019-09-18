namespace :data do
  namespace :migrate_info_hash do
    desc "Migrate customer_contacts.info_hash_text to info_hash"
    task up: :environment do
      customer_contacts = CustomerContact.where.not(info_hash: nil)
      total_count = customer_contacts.count
      puts "Updating #{total_count} customer_contact records..."

      ActiveRecord::Base.transaction do
        customer_contacts.find_each.with_index(1) do |customer_contact, i|
          customer_contact.update(info_hash: customer_contact.info_hash_text)
          print_status(i, total_count)
        end
      end

      puts "\nDone!"
    end

    desc "Migrate customer_contacts.info_hash to info_hash_text"
    task down: :environment do
      customer_contacts = CustomerContact.where.not(info_hash: {})
      total_count = customer_contacts.count
      puts "Updating #{total_count} customer_contact records..."

      ActiveRecord::Base.transaction do
        customer_contacts.find_each.with_index(1) do |customer_contact, i|
          customer_contact.update(info_hash_text: customer_contact.info_hash)
          print_status(i, total_count)
        end
      end

      puts "\nDone!"
    end
  end

  namespace :migrate_customer_contact_types do
    desc "Migrate customer_contacts.contact_type to kind"
    task up: :environment do
      total_count = CustomerContact.count
      puts "Updating #{total_count} customer_contact records..."

      CustomerContact.transaction do
        CustomerContact.find_each.with_index(1) do |customer_contact, i|
          kind_code = CustomerContact.kinds[customer_contact.contact_type]
          customer_contact.update(kind: kind_code)
          print_status(i, total_count)
        end
      end

      puts "\nDone!"
    end

    desc "Migrate customer_contacts.kind to contact_type"
    task down: :environment do
      total_count = CustomerContact.count
      puts "Updating #{total_count} customer_contact records..."

      CustomerContact.transaction do
        CustomerContact.find_each.with_index(1) do |customer_contact, i|
          customer_contact.update(contact_type: customer_contact.kind)
          print_status(i, total_count)
        end
      end

      puts "\nDone!"
    end
  end
end

def print_status(curr, total_count)
  digits = total_count.to_s.length
  count = [curr.to_s.rjust(digits, " "), total_count].join("/")
  percent = (curr * 100 / total_count.to_f).round(1).to_s.rjust(5, " ")
  $stdout.print "#{count} : #{percent}%\r"
  $stdout.flush
end
