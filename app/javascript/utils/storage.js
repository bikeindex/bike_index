/* global localStorage */

// Where site data is blocked, even reading the localStorage property throws, and a full
// quota throws on write - so a blocked read is null, as if nothing were stored, and a
// blocked write does nothing
const attempt = (callback) => {
  try {
    return callback(localStorage)
  } catch {
    return null
  }
}

export const storage = {
  getItem: (key) => attempt((store) => store.getItem(key)),
  setItem: (key, value) => attempt((store) => store.setItem(key, value)),
  removeItem: (key) => attempt((store) => store.removeItem(key))
}
