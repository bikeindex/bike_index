/* global localStorage */

// The array saved under key, or null - clearing anything else saved there
export function storedArray (key) {
  try {
    const value = JSON.parse(localStorage.getItem(key))
    if (value === null || Array.isArray(value)) return value
  } catch {}
  localStorage.removeItem(key)
  return null
}
