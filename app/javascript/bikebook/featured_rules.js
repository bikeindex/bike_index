// What the page features with nothing picked, from the models the filters leave, shown in their order. Each pick is
// the model ranking first by `preferences`, then by which `quotas` it helps meet, of those passing every requirement.
// A quota narrows a pick to its models once the picks left are all it still needs, the first quotas first, and one
// with no models left gives way

export const COUNT = 12

// as the "Gravel bikes under $1,500" example's price_max counts it
const UNDER_PRICE_CENTS = 150000
const MAX_PRICE_CENTS = 1000000
const AROUND_PRICE_CENTS = [550000, 650000]

// The index carries no model group, which a model's first word stands in for
const modelGroup = ({ manufacturer, model }) => `${manufacturer}/${model.split(' ')[0]}`

// A model whose `key` none of the picks share
const unseen = (key) => (model, { picked }) => !picked.some((each) => key(each) === key(model))

// Each leaves out the models it fails, unless that would leave none. `legalEbike` is whether a model is an e-bike in a
// class legal where the visitor is: their state's in the US, the market's e-bike law elsewhere
export const requirements = [
  (model, { legalEbike }) => !model.electric || legalEbike(model),
  // none over $10,000 until the reader filters by price, but Reactive Adaptations' adaptive bikes, which rarely cost less
  (model, { params }) => params.price_min || params.price_max || !(model.msrp_cents > MAX_PRICE_CENTS) ||
    model.manufacturer === 'reactive_adaptations'
]

// In order, each deciding between the models the ones before it tie on
export const preferences = [
  unseen(({ manufacturer }) => manufacturer),
  unseen(({ primary_activity: activity }) => activity),
  unseen(modelGroup),
  ({ model_configuration: configuration }) => configuration === 'complete'
]

// `share` is the picks' fraction, those it leaves being the other models; `minimum` is a count
export const quotas = [
  { matches: ({ electric }) => electric, share: 0.5 },
  { matches: ({ msrp_cents: cents }) => cents > 0 && cents <= UNDER_PRICE_CENTS, minimum: 3 },
  { matches: ({ msrp_cents: cents }) => cents >= AROUND_PRICE_CENTS[0] && cents <= AROUND_PRICE_CENTS[1], minimum: 4 }
]
