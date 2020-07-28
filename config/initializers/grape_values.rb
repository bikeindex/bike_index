CYCLE_TYPE_NAMES = begin
                     CycleType::NAMES.values.map(&:downcase)
                   rescue
                     ["bike"]
                   end

if Rails.env.test?
  CTYPE_NAMES = ["wheel", "headset"]
  COLOR_NAMES = ["black", "orange"]
  COUNTRY_ISOS = ["US"]
else
  CTYPE_NAMES = begin
                  !!Ctype && Ctype.pluck(:name).map(&:downcase)
                rescue
                  []
                end
  COLOR_NAMES = begin
                  !!Color && Color.pluck(:name).map(&:downcase)
                rescue
                  []
                end
  COUNTRY_ISOS = begin
                   !!Color && Country.pluck(:iso)
                 rescue
                   []
                 end
end
