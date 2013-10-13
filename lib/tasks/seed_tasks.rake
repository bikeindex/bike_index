# Seed the database with test things!
# Note: you have to seed the users first, or else the bikes don't have anywhere to go.

desc "Seed test users"
task :seed_test_users => :environment do 
  user = User.create(name: "admin", email: "admin@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true)
  user.confirmed = true 
  user.superuser = true 
  user.save
  user = User.create(name: "member", email: "member@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true)
  user.confirmed = true 
  user.can_invite = true
  user.save
  user = User.create(name: "user", email: "user@example.com", password: "please12", password_confirmation: "please12", terms_of_service: true)
  user.confirmed = true 
  user.save


  org = Organization.create(name: "Ikes Bike's", website: "", short_name: "Ikes", default_bike_token_count: 5, show_on_map: true)
  org.save
  membership = Membership.create(organization_id: org.id, user_id: User.find_by_email("member@example.com").id, role: "admin")
  membership.save
  puts "\nSuccess"
end

desc "Create test bikes for user@example on first organization"
task :seed_test_bikes => :environment do
  @user = User.find_by_email('user@example.com')
  @member = User.find_by_email('member@example.com')
  @org = Organization.first
  @propulsion_type_id = PropulsionType.find_by_name('Foot pedal').id
  @cycle_type_id = CycleType.find_by_name('Bike').id
  50.times do 
    bike = Bike.new(
      cycle_type_id: @cycle_type_id,
      propulsion_type_id: @propulsion_type_id,
      manufacturer_id: (rand(Manufacturer.frames.count) + 1),
      rear_tire_narrow: true,
      rear_wheel_size_id: (rand(WheelSize.count) + 1),
      primary_frame_color_id: (rand(Color.count) + 1),
      handlebar_type_id: (rand(HandlebarType.count) + 1),
      creator: @user,
      owner_email: @user.email,
      verified: true
    )
    bike.serial_number = (0...10).map{(65+rand(26)).chr}.join
    bike.creation_organization_id = @org.id
    if bike.save
      ownership = Ownership.new(bike_id: bike.id, creator_id: @member.id, user_id: @user.id, owner_email: @user.email, current: true)
      unless ownership.save
        puts "\n Ownership error \n #{ownership.errors.messages}"
        raise StandardError
      end
      puts "New bike made by #{bike.manufacturer.name}"
    else
      puts "\n Bike error \n #{bike.errors.messages}"
    end
  end
end

task :seed_dup_bikes => :environment do
  @user = User.find_by_email('user@example.com')
  @member = User.find_by_email('member@example.com')
  @org = Organization.first
  @propulsion_type_id = PropulsionType.find_by_name('Foot pedal').id
  @cycle_type_id = CycleType.find_by_name('Bike').id
  @serial_number = (0...10).map{(65+rand(26)).chr}.join
  @manufacturer_id = (rand(Manufacturer.frames.count) + 1)
  5.times do 
    bike = Bike.new(
      cycle_type_id: @cycle_type_id,
      propulsion_type_id: @propulsion_type_id,
      manufacturer_id: @manufacturer_id,
      rear_tire_narrow: true,
      rear_wheel_size_id: WheelSize.first.id,
      primary_frame_color_id: Color.first.id,
      handlebar_type_id: HandlebarType.first.id,
      creator: @user,
      owner_email: @user.email,
      serial_number: @serial_number
    )
    bike.organization_id = @org.id
    if bike.save
      ownership = Ownership.new(bike_id: bike.id, creator_id: @member.id, user_id: @user.id, owner_email: @user.email, current: true)
      unless ownership.save
        puts "\n Ownership error \n #{ownership.errors.messages}"
        raise StandardError
      end
      puts "New bike made by #{bike.manufacturer.name}"
    else
      puts "\n Bike error \n #{bike.errors.messages}"
    end
  end
end


task :seed_countries => :environment do
  countries = [
    { name: "Afghanistan", iso: "AF" },
      { name: "Albania", iso: "AL" },
    { name: "Algeria", iso: "DZ" },
    { name: "American Samoa", iso: "AS" },
    { name: "Andorra", iso: "AD" },
    { name: "Angola", iso: "AO" },
    { name: "Anguilla", iso: "AI" },
    { name: "Antarctica", iso: "AQ" },
    { name: "Antigua and Barbuda", iso: "AG" },
    { name: "Argentina", iso: "AR" },
    { name: "Armenia", iso: "AM" },
    { name: "Aruba", iso: "AW" },
    { name: "Australia", iso: "AU" },
    { name: "Austria", iso: "AT" },
    { name: "Azerbaijan", iso: "AZ" },
    { name: "Bahamas", iso: "BS" },
    { name: "Bahrain", iso: "BH" },
    { name: "Bangladesh", iso: "BD" },
    { name: "Barbados", iso: "BB" },
    { name: "Belarus", iso: "BY" },
    { name: "Belgium", iso: "BE" },
    { name: "Belize", iso: "BZ" },
    { name: "Benin", iso: "BJ" },
    { name: "Bermuda", iso: "BM" },
    { name: "Bhutan", iso: "BT" },
    { name: "Bolivia", iso: "BO" },
    { name: "Bosnia and Herzegovina", iso: "BA" },
    { name: "Botswana", iso: "BW" },
    { name: "Bouvet Island", iso: "BV" },
    { name: "Brazil", iso: "BR" },
    { name: "British Indian Ocean Territory", iso: "IO" },
    { name: "Brunei Darussalam", iso: "BN" },
    { name: "Bulgaria", iso: "BG" },
    { name: "Burkina Faso", iso: "BF" },
    { name: "Burundi", iso: "BI" },
    { name: "Cambodia", iso: "KH" },
    { name: "Cameroon", iso: "CM" },
    { name: "Canada", iso: "CA" },
    { name: "Cape Verde", iso: "CV" },
    { name: "Cayman Islands", iso: "KY" },
    { name: "Central African Republic", iso: "CF" },
    { name: "Chad", iso: "TD" },
    { name: "Chile", iso: "CL" },
    { name: "China", iso: "CN" },
    { name: "Christmas Island", iso: "CX" },
    { name: "Cocos (Keeling) Islands", iso: "CC" },
    { name: "Colombia", iso: "CO" },
    { name: "Comoros", iso: "KM" },
    { name: "Congo", iso: "CG" },
    { name: "Congo, The Democratic Republic of The", iso: "CD" },
    { name: "Cook Islands", iso: "CK" },
    { name: "Costa Rica", iso: "CR" },
    { name: "Cote D'ivoire", iso: "CI" },
    { name: "Croatia", iso: "HR" },
    { name: "Cuba", iso: "CU" },
    { name: "Cyprus", iso: "CY" },
    { name: "Czech Republic", iso: "CZ" },
    { name: "Denmark", iso: "DK" },
    { name: "Djibouti", iso: "DJ" },
    { name: "Dominica", iso: "DM" },
    { name: "Dominican Republic", iso: "DO" },
    { name: "Ecuador", iso: "EC" },
    { name: "Egypt", iso: "EG" },
    { name: "El Salvador", iso: "SV" },
    { name: "Equatorial Guinea", iso: "GQ" },
    { name: "Eritrea", iso: "ER" },
    { name: "Estonia", iso: "EE" },
    { name: "Ethiopia", iso: "ET" },
    { name: "Falkland Islands (Malvinas", iso: "FK" },
    { name: "Faroe Islands", iso: "FO" },
    { name: "Fiji", iso: "FJ" },
    { name: "Finland", iso: "FI" },
    { name: "France", iso: "FR" },
    { name: "French Guiana", iso: "GF" },
    { name: "French Polynesia", iso: "PF" },
    { name: "French Southern Territories", iso: "TF" },
    { name: "Gabon", iso: "GA" },
    { name: "Gambia", iso: "GM" },
    { name: "Georgia", iso: "GE" },
    { name: "Germany", iso: "DE" },
    { name: "Ghana", iso: "GH" },
    { name: "Gibraltar", iso: "GI" },
    { name: "Greece", iso: "GR" },
    { name: "Greenland", iso: "GL" },
    { name: "Grenada", iso: "GD" },
    { name: "Guadeloupe", iso: "GP" },
    { name: "Guam", iso: "GU" },
    { name: "Guatemala", iso: "GT" },
    { name: "Guernsey", iso: "GG" },
    { name: "Guinea", iso: "GN" },
    { name: "Guinea-bissau", iso: "GW" },
    { name: "Guyana", iso: "GY" },
    { name: "Haiti", iso: "HT" },
    { name: "Heard Island and Mcdonald Islands", iso: "HM" },
    { name: "Holy See (Vatican City State", iso: "VA" },
    { name: "Honduras", iso: "HN" },
    { name: "Hong Kong", iso: "HK" },
    { name: "Hungary", iso: "HU" },
    { name: "Iceland", iso: "IS" },
    { name: "India", iso: "IN" },
    { name: "Indonesia", iso: "ID" },
    { name: "Iran, Islamic Republic of", iso: "IR" },
    { name: "Iraq", iso: "IQ" },
    { name: "Ireland", iso: "IE" },
    { name: "Isle of Man", iso: "IM" },
    { name: "Israel", iso: "IL" },
    { name: "Italy", iso: "IT" },
    { name: "Jamaica", iso: "JM" },
    { name: "Japan", iso: "JP" },
    { name: "Jersey", iso: "JE" },
    { name: "Jordan", iso: "JO" },
    { name: "Kazakhstan", iso: "KZ" },
    { name: "Kenya", iso: "KE" },
    { name: "Kiribati", iso: "KI" },
    { name: "Korea, Democratic People's Republic of", iso: "KP" },
    { name: "Korea, Republic of", iso: "KR" },
    { name: "Kuwait", iso: "KW" },
    { name: "Kyrgyzstan", iso: "KG" },
    { name: "Lao People's Democratic Republic", iso: "LA" },
    { name: "Latvia", iso: "LV" },
    { name: "Lebanon", iso: "LB" },
    { name: "Lesotho", iso: "LS" },
    { name: "Liberia", iso: "LR" },
    { name: "Libyan Arab Jamahiriya", iso: "LY" },
    { name: "Liechtenstein", iso: "LI" },
    { name: "Lithuania", iso: "LT" },
    { name: "Luxembourg", iso: "LU" },
    { name: "Macao", iso: "MO" },
    { name: "Macedonia, The Former Yugoslav Republic of", iso: "MK" },
    { name: "Madagascar", iso: "MG" },
    { name: "Malawi", iso: "MW" },
    { name: "Malaysia", iso: "MY" },
    { name: "Maldives", iso: "MV" },
    { name: "Mali", iso: "ML" },
    { name: "Malta", iso: "MT" },
    { name: "Marshall Islands", iso: "MH" },
    { name: "Martinique", iso: "MQ" },
    { name: "Mauritania", iso: "MR" },
    { name: "Mauritius", iso: "MU" },
    { name: "Mayotte", iso: "YT" },
    { name: "Mexico", iso: "MX" },
    { name: "Micronesia, Federated States of", iso: "FM" },
    { name: "Moldova, Republic of", iso: "MD" },
    { name: "Monaco", iso: "MC" },
    { name: "Mongolia", iso: "MN" },
    { name: "Montenegro", iso: "ME" },
    { name: "Montserrat", iso: "MS" },
    { name: "Morocco", iso: "MA" },
    { name: "Mozambique", iso: "MZ" },
    { name: "Myanmar", iso: "MM" },
    { name: "Namibia", iso: "NA" },
    { name: "Nauru", iso: "NR" },
    { name: "Nepal", iso: "NP" },
    { name: "Netherlands", iso: "NL" },
    { name: "Netherlands Antilles", iso: "AN" },
    { name: "New Caledonia", iso: "NC" },
    { name: "New Zealand", iso: "NZ" },
    { name: "Nicaragua", iso: "NI" },
    { name: "Niger", iso: "NE" },
    { name: "Nigeria", iso: "NG" },
    { name: "Niue", iso: "NU" },
    { name: "Norfolk Island", iso: "NF" },
    { name: "Northern Mariana Islands", iso: "MP" },
    { name: "Norway", iso: "NO" },
    { name: "Oman", iso: "OM" },
    { name: "Pakistan", iso: "PK" },
    { name: "Palau", iso: "PW" },
    { name: "Palestinian Territory, Occupied", iso: "PS" },
    { name: "Panama", iso: "PA" },
    { name: "Papua New Guinea", iso: "PG" },
    { name: "Paraguay", iso: "PY" },
    { name: "Peru", iso: "PE" },
    { name: "Philippines", iso: "PH" },
    { name: "Pitcairn", iso: "PN" },
    { name: "Poland", iso: "PL" },
    { name: "Portugal", iso: "PT" },
    { name: "Puerto Rico", iso: "PR" },
    { name: "Qatar", iso: "QA" },
    { name: "Reunion", iso: "RE" },
    { name: "Romania", iso: "RO" },
    { name: "Russian Federation", iso: "RU" },
    { name: "Rwanda", iso: "RW" },
    { name: "Saint Helena", iso: "SH" },
    { name: "Saint Kitts and Nevis", iso: "KN" },
    { name: "Saint Lucia", iso: "LC" },
    { name: "Saint Pierre and Miquelon", iso: "PM" },
    { name: "Saint Vincent and The Grenadines", iso: "VC" },
    { name: "Samoa", iso: "WS" },
    { name: "San Marino", iso: "SM" },
    { name: "Sao Tome and Principe", iso: "ST" },
    { name: "Saudi Arabia", iso: "SA" },
    { name: "Senegal", iso: "SN" },
    { name: "Serbia", iso: "RS" },
    { name: "Seychelles", iso: "SC" },
    { name: "Sierra Leone", iso: "SL" },
    { name: "Singapore", iso: "SG" },
    { name: "Slovakia", iso: "SK" },
    { name: "Slovenia", iso: "SI" },
    { name: "Solomon Islands", iso: "SB" },
    { name: "Somalia", iso: "SO" },
    { name: "South Africa", iso: "ZA" },
    { name: "South Georgia and The South Sandwich Islands", iso: "GS" },
    { name: "Spain", iso: "ES" },
    { name: "Sri Lanka", iso: "LK" },
    { name: "Sudan", iso: "SD" },
    { name: "Suriname", iso: "SR" },
    { name: "Svalbard and Jan Mayen", iso: "SJ" },
    { name: "Swaziland", iso: "SZ" },
    { name: "Sweden", iso: "SE" },
    { name: "Switzerland", iso: "CH" },
    { name: "Syrian Arab Republic", iso: "SY" },
    { name: "Taiwan, Province of China", iso: "TW" },
    { name: "Tajikistan", iso: "TJ" },
    { name: "Tanzania, United Republic of", iso: "TZ" },
    { name: "Thailand", iso: "TH" },
    { name: "Timor-leste", iso: "TL" },
    { name: "Togo", iso: "TG" },
    { name: "Tokelau", iso: "TK" },
    { name: "Tonga", iso: "TO" },
    { name: "Trinidad and Tobago", iso: "TT" },
    { name: "Tunisia", iso: "TN" },
    { name: "Turkey", iso: "TR" },
    { name: "Turkmenistan", iso: "TM" },
    { name: "Turks and Caicos Islands", iso: "TC" },
    { name: "Tuvalu", iso: "TV" },
    { name: "Uganda", iso: "UG" },
    { name: "Ukraine", iso: "UA" },
    { name: "United Arab Emirates", iso: "AE" },
    { name: "United Kingdom", iso: "GB" },
    { name: "United States", iso: "US" },
    { name: "United States Minor Outlying Islands", iso: "UM" },
    { name: "Uruguay", iso: "UY" },
    { name: "Uzbekistan", iso: "UZ" },
    { name: "Vanuatu", iso: "VU" },
    { name: "Venezuela", iso: "VE" },
    { name: "Viet Nam", iso: "VN" },
    { name: "Virgin Islands, British", iso: "VG" },
    { name: "Virgin Islands, U.S", iso: "VI" },
    { name: "Wallis and Futuna", iso: "WF" },
    { name: "Western Sahara", iso: "EH" },
    { name: "Yemen", iso: "YE" },
    { name: "Zambia", iso: "ZM" },
    { name: "Zimbabwe", iso: "ZW" }
  ]
  countries.each do |c|
    country = Country.create(name: c[:name], iso: c[:iso])
    country.save
  end
end