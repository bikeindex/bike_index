# Testing Utilities

This directory contains testing utilities for the Strava Search application.

## VCR (Video Cassette Recorder)

The VCR module provides a way to record and replay Strava API responses, similar to Ruby's VCR gem. This is useful for:

- Writing tests without hitting the actual Strava API
- Developing features offline
- Ensuring consistent test data

### Key Features

- **Automatic credential sanitization**: API tokens, client secrets, and other sensitive data are automatically removed from recordings
- **Request matching**: Replays the correct response based on URL and HTTP method
- **Browser-compatible**: Works in the browser during development

### Recording API Responses

1. Open your browser's developer console
2. Start recording:

```javascript
vcr.startRecording('my-cassette-name');
```

3. Use the app normally to trigger the API calls you want to record
4. Stop recording and download the cassette:

```javascript
const cassette = vcr.stopRecording();
vcr.downloadCassette(cassette);
```

5. The downloaded JSON file will have all sensitive data automatically redacted

### Using Cassettes in Tests

```typescript
import { vcr } from '../testing/vcr';
import cassette from './cassettes/my-cassette.json';

describe('My Feature', () => {
  beforeEach(() => {
    vcr.loadCassette(cassette);
  });

  afterEach(() => {
    vcr.eject();
  });

  it('should load activities', async () => {
    // API calls will use recorded responses
    const activities = await getActivities();
    expect(activities).toHaveLength(2);
  });
});
```

### Sanitized Data

The following data is automatically redacted from recordings:

| Data Type | Replacement |
|-----------|-------------|
| `access_token` | `[REDACTED]` |
| `refresh_token` | `[REDACTED]` |
| `client_id` | `[REDACTED]` |
| `client_secret` | `[REDACTED]` |
| `code` (OAuth) | `[REDACTED]` |
| `email` | `[REDACTED]@example.com` |
| Athlete IDs in URLs | `[ATHLETE_ID]` |
| Authorization headers | `Bearer [REDACTED]` |

### Cassette Format

Cassettes are JSON files with the following structure:

```json
{
  "name": "cassette-name",
  "recordedAt": "2024-01-15T10:00:00.000Z",
  "interactions": [
    {
      "request": {
        "url": "https://www.strava.com/api/v3/athlete/activities",
        "method": "GET",
        "headers": { "Authorization": "Bearer [REDACTED]" }
      },
      "response": {
        "status": 200,
        "statusText": "OK",
        "headers": { "content-type": "application/json" },
        "body": [/* activity data */]
      },
      "recordedAt": "2024-01-15T10:00:00.000Z"
    }
  ]
}
```

### Best Practices

1. **Name cassettes descriptively**: Use names like `get-activities-page-1` or `oauth-token-exchange`
2. **Review cassettes before committing**: Double-check that no sensitive data slipped through
3. **Keep cassettes focused**: Record only the interactions needed for a specific test
4. **Update cassettes when API changes**: If Strava's API response format changes, re-record affected cassettes

## Mock Data

The `mocks.ts` file in the stories directory contains mock data for Storybook stories. This data is not recorded from the API but manually created to showcase various component states.
