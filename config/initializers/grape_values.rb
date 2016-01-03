if Rails.env.test?
  CYCLE_TYPE_NAMES = ['bike']
  CTYPE_NAMES = ['wheel', 'headset']
  COLOR_NAMES = ['black']
  COUNTRY_ISOS = ['US']
else
  CYCLE_TYPE_NAMES = !!CycleType && CycleType.pluck(:name).any? &&
    CycleType.pluck(:name).map(&:downcase) rescue ['bike']
  CTYPE_NAMES = !!Ctype && Ctype.pluck(:name).map(&:downcase) rescue []
  COLOR_NAMES = !!Color && Color.pluck(:name).map(&:downcase) rescue []
  COUNTRY_ISOS = !!Color && Country.pluck(:iso) rescue []
end