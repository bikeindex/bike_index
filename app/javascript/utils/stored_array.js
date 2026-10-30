import { storage } from 'utils/storage'

// The array saved under key, or null - clearing anything else saved there
export function storedArray (key) {
  try {
    const value = JSON.parse(storage.getItem(key))
    if (value === null || Array.isArray(value)) return value
  } catch {}
  storage.removeItem(key)
  return null
}
