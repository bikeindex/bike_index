// What the catalog has for e-vehicle classifications (db/e_vehicle_classifications) but doesn't publish
// yet: each one's jurisdiction, "US-CA Moped", and the description its "?" opens

const CLASSIFICATIONS = 'motors.e_vehicle_classifications'

const DESCRIPTIONS = {
  'ec/us/class_1': 'A pedal-assist electric bicycle: the motor helps only while the rider pedals, and stops helping at 20 mph. Defined by the three-class model law most states have adopted; state and local rules can add to these.',
  'ec/us/class_2': 'A throttle electric bicycle: the motor can propel it without pedaling, and stops helping at 20 mph, by throttle or by pedal assist. Defined by the three-class model law most states have adopted; state and local rules can add to these.',
  'ec/us/class_3': 'A speed pedal-assist electric bicycle: the motor helps only while the rider pedals, and stops helping at 28 mph. Defined by the three-class model law most states have adopted; state and local rules can add to these.',
  'ec/us/ca/moped': 'A moped or motorized bicycle: two or three wheels, a motor under 4 gross brake horsepower (3,000 W), and a top speed of 30 mph on level ground. Defined by California Vehicle Code §406, as amended by SB 1167 (Chapter 846, Statutes of 2026).',
  'ec/us/ca/motor_driven_cycle': 'A light electric motorcycle: its motor produces 5 gross brake horsepower (3,750 W) or less, the electric counterpart of a motorcycle under 150 cc. Defined by California Vehicle Code §405, as amended by SB 1167 (Chapter 846, Statutes of 2026).',
  'ec/us/ca/motorcycle': 'A road-registered electric motorcycle: its motor produces more than 5 gross brake horsepower (3,750 W), above what a motor-driven cycle may. Defined by California Vehicle Code §400, with the line set by SB 1167 (Chapter 846, Statutes of 2026).',
  'ec/us/ca/off_highway_electric_motorcycle': 'An electric motorcycle built for riding off the highway, an "eMoto": two wheels, handlebars, a straddle seat and no pedals from the manufacturer, with no limit on power or speed. Defined by California Vehicle Code §436.1, added by SB 586 (2025).'
}

export const withUnpublished = ({ vocabulary, kit, ...catalog }) => {
  const names = Object.fromEntries(Object.entries(vocabulary.names[CLASSIFICATIONS] ?? {})
    .map(([slug, name]) => [slug, `${slug.split('/').slice(1, -1).join('-').toUpperCase()} ${name}`]))
  const labels = { ...kit.motor.labels, e_vehicle_classifications: 'Classification' }
  const classificationTooltips = Object.fromEntries(Object.entries(names).map(([slug, name]) => [name, DESCRIPTIONS[slug]]))
  return {
    ...catalog,
    vocabulary: { ...vocabulary, names: { ...vocabulary.names, [CLASSIFICATIONS]: names } },
    kit: { ...kit, motor: { ...kit.motor, labels, classification_tooltips: classificationTooltips } }
  }
}
