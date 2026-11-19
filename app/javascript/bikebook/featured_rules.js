// What the page features with nothing picked, from the models the filters leave. Each pick is the model ranking first
// by `preferences`, then by which `quotas` it helps meet, of those passing every requirement. A quota narrows a pick to
// its models once the picks left are all it still needs, the first quotas first, and one with no models left gives way

export const COUNT = 12

const MIN_PRICE_CENTS = 60000
const LOW_PRICE_CENTS = 140000
const MID_PRICE_CENTS = 250000
const HIGH_PRICE_CENTS = 500000
const TOP_PRICE_CENTS = 800000
const MAX_PRICE_CENTS = 1000000
const CURRENCIES = { EU: 'EUR', AU: 'AUD', CA: 'CAD', CH: 'CHF', GB: 'GBP', HK: 'HKD', ID: 'IDR', IN: 'INR', JP: 'JPY', NZ: 'NZD', TW: 'TWD' }
const CYCLE_TYPES = ['bike', 'cargo_bike', 'cargo_bike_rear', 'tandem', 'recumbent']

// A model whose `key` none of the picks share
const unseen = (key) => (model, { picked }) => !picked.some((each) => key(each) === key(model))
const priced = (min, max = Infinity) => ({ msrp_cents: cents }) => cents > min && cents <= max
const local = ({ market }) => CURRENCIES[market] ?? 'USD'
const riders = (rider) => ({ target_riders: targets }) => Boolean(targets?.includes(rider))

// Each leaves out the models it fails, unless that would leave none. `legalEbike` is whether a model is an e-bike in a
// class legal where the visitor is: their state's in the US, the market's e-bike law elsewhere
export const requirements = [
  // an incomplete model's listed photo is often missing
  ({ photo, incomplete }) => Boolean(photo) && !incomplete,
  ({ msrp_cents: cents }) => cents >= MIN_PRICE_CENTS,
  ({ vehicle_type: type }) => CYCLE_TYPES.includes(type),
  (model, { legalEbike }) => !model.electric || (legalEbike(model) && !model.e_vehicle_classifications?.includes('evc/out_of_class')),
  ({ target_riders: targets }) => !targets?.includes('kid'),
  ({ primary_activity: activity }) => !activity?.startsWith('bmx'),
  // the market's currency, else the dollar, as the quotas' prices are in it
  ({ msrp_currency: currency }, { params }) => [local(params), 'USD'].includes(currency),
  ({ msrp_currency: currency }, { params }) => currency === local(params),
  // none over $10,000 until the reader filters by price, but Reactive Adaptations' adaptive bikes, which rarely cost less
  (model, { params }) => params.price_min || params.price_max || !priced(MAX_PRICE_CENTS)(model) ||
    model.manufacturer === 'reactive_adaptations'
]

// In order, each deciding between the models the ones before it tie on
export const preferences = [
  unseen(({ manufacturer }) => manufacturer),
  unseen(({ primary_activity: activity }) => activity),
  unseen(({ group_key: group }) => group),
  ({ model_configuration: configuration }) => configuration === 'complete',
  ({ final_year: finalYear }) => finalYear == null
]

// `share` is the picks' fraction, those it leaves being the other models; `minimum` is a count
export const quotas = [
  { matches: ({ electric }) => electric, share: 0.5 },
  { matches: riders('woman'), minimum: 3 },
  { matches: priced(0, LOW_PRICE_CENTS), minimum: 4 },
  { matches: (model) => model.electric && priced(0, LOW_PRICE_CENTS)(model), minimum: 2 },
  { matches: priced(LOW_PRICE_CENTS, MID_PRICE_CENTS), minimum: 4 }
]

// Each leaves its models out of the picks once they number `maximum`, unless that would leave none
export const maximums = [
  { matches: priced(HIGH_PRICE_CENTS), maximum: 2 },
  { matches: priced(TOP_PRICE_CENTS), maximum: 1 }
]
