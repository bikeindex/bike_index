// What a bike is drawn with where it lists a figure that nothing it does list works out, by its primary activity, each
// the median of its kind's that list it. A bike's note names its `kind` as what each was estimated from.
//   rim: the bead seat diameter in mm, where it lists none. Null where its kind's are split between sizes, which leaves
//     one listing none undrawn
//   tire: the width in mm, where it lists none
//   fork_rake: the fork's offset in mm
//   head_tube, crown: a BMX's head tube in mm, and its fork crown's height above the front tire, as BMX spec sheets list
//     no stack, reach or fork length
// Touring's are drawn on the road wheels they're built from, and `mtb` gets no wheel for its fat bikes, which no one tire
// draws

const inches = (width) => Math.round(width * 25.4)

export const TYPICAL_GEOMETRY = {
  track_racing: { kind: 'track bike', rim: 622, tire: 23, fork_rake: 40 },
  road_biking: { kind: 'road bike', rim: 622, tire: 25, fork_rake: 45 },
  road_triathlon: { kind: 'triathlon bike', rim: 622, tire: 25, fork_rake: 43 },
  road_time_trial: { kind: 'time trial bike', rim: 622, tire: 25, fork_rake: 43 },
  road_aero: { kind: 'aero road bike', rim: 622, tire: 28, fork_rake: 45 },
  road_endurance: { kind: 'endurance road bike', rim: 622, tire: 28, fork_rake: 49 },
  road_climbing: { kind: 'climbing road bike', rim: 622, tire: 28, fork_rake: 47 },
  road_all_road: { kind: 'all-road bike', rim: 622, tire: 32, fork_rake: 50 },
  road_bike_touring: { kind: 'touring bike', rim: 622, tire: 33, fork_rake: 50 },
  atb_cyclocross: { kind: 'cyclocross bike', rim: 622, tire: 33, fork_rake: 50 },
  atb_gravel: { kind: 'gravel bike', rim: 622, tire: 44, fork_rake: 50 },
  commuting: { kind: 'commuter bike', rim: null, tire: 50, fork_rake: 50 },
  cargo: { kind: 'cargo bike', rim: null, tire: 58 },
  mtb: { kind: 'mountain bike', fork_rake: 48 },
  mtb_cross_country: { kind: 'cross-country mountain bike', rim: 622, tire: inches(2.25), fork_rake: 44 },
  mtb_bikepacking: { kind: 'bikepacking bike', rim: 622, tire: inches(2.2), fork_rake: 45 },
  mtb_trail_all_mountain: { kind: 'trail mountain bike', rim: null, tire: inches(2.4), fork_rake: 44 },
  mtb_enduro: { kind: 'enduro mountain bike', rim: null, tire: inches(2.5), fork_rake: 44 },
  mtb_downhill: { kind: 'downhill mountain bike', rim: null, tire: inches(2.5), fork_rake: 52 },
  mtb_freeride: { kind: 'freeride mountain bike', rim: null, tire: inches(2.3) },
  dj: { kind: 'dirt jump bike', rim: 559, tire: inches(2.25) },
  bmx: { kind: 'BMX', fork_rake: 28, head_tube: 119, crown: 63 },
  bmx_race: { kind: 'BMX', fork_rake: 28, head_tube: 119, crown: 63 },
  bmx_freestyle: { kind: 'BMX', fork_rake: 28, head_tube: 119, crown: 63 }
}
