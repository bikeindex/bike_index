# Strava Search

A static web application for searching, filtering, and bulk-updating your Strava activities. Deployed via GitHub Pages - all data is stored locally in your browser.

## Features

- **OAuth Authentication**: Securely connect with your Strava account
- **Local Storage**: All activities stored in IndexedDB - works offline after initial sync
- **Powerful Search**: Search activities by name, description, location, recorded by
- **Advanced Filters**:
  - Filter by activity type (Run, Ride, Swim, etc.)
  - Filter by date range
  - Filter by equipment/gear
  - Combine multiple filters
- **Bulk Updates**: Select multiple activities and update:
  - Activity type
  - Equipment/gear
- **Auto-Sync**: Automatically checks for new activities
- **Responsive Design**: Works on desktop and mobile

## Setup

### 1. Create a Strava API Application

1. Go to [Strava API Settings](https://www.strava.com/settings/api)
2. Create a new application (or use an existing one)
3. Set the **Authorization Callback Domain** to your GitHub Pages URL (e.g., `yourusername.github.io`)
4. Note your **Client ID** and **Client Secret**

### 2. Deploy to GitHub Pages

1. Fork this repository
2. Go to repository **Settings** > **Pages**
3. Set **Source** to "GitHub Actions"
4. Push to main branch to trigger deployment

### 3. Configure the App

1. Visit your deployed app
2. Enter your Strava Client ID and Client Secret
3. Click "Connect with Strava"
4. Authorize the app
5. Download your activities

## Development

Install dependencies and start dev server with `./start.sh`

Other commands

```bash
# Install dependencies. Uses legacy-peer-deps because storybook/vite version problem
npm install --legacy-peer-deps

# Start development server and storybook
npm run dev

# Build for production
npm run build

# Preview production build
npm run preview
```

Some commands to run in your browser console (after authenticated with Strava):

```js
// Get a download of an activity (with tokens removed)
vcr.startRecording('activity-detail')
await strava.getActivity(17145907973)
const cassette = vcr.stopRecording()
vcr.downloadCassette(cassette)

// See the data that is stored for an activity:
await db.getActivityById(17145907973)

// Enrich the activities on the page
fetchFullActivityData()
// enrich an individual activity
fetchFullActivityData([9677113832])
```

## Tech Stack

- **React** with TypeScript
- **Vite** for building
- **Tailwind CSS** for styling
- **Dexie.js** for IndexedDB storage
- **Lucide React** for icons

## Privacy

- All data is stored locally in your browser's IndexedDB
- Your Strava credentials are stored in localStorage
- No data is sent to any server except Strava's API
- You can clear all local data from the Settings page

## License

AGPL - See [LICENSE](LICENSE)
