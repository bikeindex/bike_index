CYCLE_TYPE_NAMES = CycleType::NAMES.values.map(&:downcase) rescue ["bike"]

if Rails.env.test?
  CTYPE_NAMES = ["wheel", "headset"]
  COLOR_NAMES = ["black"]
  COUNTRY_ISOS = ["US"]
else
  CTYPE_NAMES = !!Ctype && Ctype.pluck(:name).map(&:downcase) rescue []
  COLOR_NAMES = !!Color && Color.pluck(:name).map(&:downcase) rescue []
  COUNTRY_ISOS = !!Color && Country.pluck(:iso) rescue []
end
