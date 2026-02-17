# Strava Search

A React SPA for searching, filtering, and bulk-updating your Strava activities. Vendored from [bikeindex/strava_search](https://github.com/bikeindex/strava_search) and served at `/strava_search` inside the Bike Index Rails app.

All data is stored locally in the user's browser (IndexedDB/localStorage).

## Features

- **OAuth Authentication**: Connect with your Strava account
- **Local Storage**: Activities stored in IndexedDB - works offline after initial sync
- **Search & Filters**: By name, location, activity type, date range, equipment
- **Bulk Updates**: Update activity type or equipment for multiple activities
- **Auto-Sync**: Automatically checks for new activities

## Development

The SPA is served via a Rails controller using pre-built assets in `public/strava_search/assets/`.

To develop with HMR (hot module replacement):

```bash
BUILD_STRAVA_SEARCH=true bin/dev
```

This starts the Vite dev server on port 3143 alongside Rails. The Rails view loads assets from the Vite dev server when `BUILD_STRAVA_SEARCH=true`.

To run the SPA's own tests/linting:

```bash
cd vendor/strava_search
npm install --legacy-peer-deps
npm run test:run    # run tests
npm run lint        # lint
npm run typecheck   # type check
npm run build       # production build (outputs to dist/)
```

After changing source, rebuild and copy assets to public:

```bash
cd vendor/strava_search
npm run build
cp -r dist/assets ../../public/strava_search/
```

## Tech Stack

- **React 19** with TypeScript
- **Vite** for building
- **Tailwind CSS 4** for styling
- **Dexie.js** for IndexedDB storage
- **Vitest** for testing
