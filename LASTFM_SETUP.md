# Last.fm Integration Setup

This app now includes Last.fm integration for tracking your listening history and getting personalized music recommendations.

## Setup Instructions

### 1. Get Last.fm API Credentials

1. Go to [https://www.last.fm/api/account/create](https://www.last.fm/api/account/create)
2. Create a Last.fm API account
3. Fill in the application details:
   - Application name: Prism Music
   - Application description: A beautiful music streaming app
   - Callback URL: (leave empty for mobile apps)
4. Save your **API Key** and **Shared Secret**

### 2. Configure the App

Open `lib/core/services/lastfm_service.dart` and replace the placeholder values:

```dart
static const String _apiKey = 'YOUR_LASTFM_API_KEY'; // Replace with your API key
static const String _apiSecret = 'YOUR_LASTFM_API_SECRET'; // Replace with your API secret
```

**IMPORTANT:** Never commit your API credentials to version control!

### 3. Features

Once configured, users can:

- **Login to Last.fm** - Authenticate with their Last.fm credentials
- **Automatic Scrobbling** - Tracks are automatically scrobbled when:
  - Played for more than 4 minutes, OR
  - Played for more than 50% of the track duration
- **Now Playing Updates** - Updates Last.fm with the current playing track
- **Personalized Recommendations** - View top tracks in the Discover tab
- **Track Loving** - Love/unlove tracks (future feature)

### 4. User Flow

1. Open the app and navigate to the **Settings** page
2. Scroll to the **Last.fm** section at the top
3. Click **Login** button
4. Enter Last.fm username and password
5. Start playing music - scrobbling happens automatically
6. View your top tracks and personalized recommendations in the **Discover** tab

### 5. Privacy & Security

- API credentials are stored in memory only
- User session tokens are securely stored in Hive local database
- Password is sent directly to Last.fm API (not stored locally)
- Users can logout anytime to clear session

## Development Notes

### Architecture

- **LastFmService** - Core service handling authentication, scrobbling, and API calls
- **PlayerBloc** - Integrated with scrobbling logic (auto-scrobble at playback milestones)
- **Discover Tab** - Shows Last.fm login prompt and personalized recommendations
- **Hive Storage** - Persists session key across app restarts

### API Methods Used

- `auth.getMobileSession` - Username/password authentication
- `track.updateNowPlaying` - Update current playing track
- `track.scrobble` - Submit listening history
- `user.getTopTracks` - Get user's top tracks for recommendations
- `user.getRecentTracks` - Get recently played tracks
- `track.love` / `track.unlove` - Love/unlove tracks

### Testing

To test Last.fm integration:

1. Create a test Last.fm account at [https://www.last.fm/join](https://www.last.fm/join)
2. Configure API credentials
3. Login with test account
4. Play songs and verify scrobbles at [https://www.last.fm/user/YOUR_USERNAME](https://www.last.fm/user/YOUR_USERNAME)

## Troubleshooting

**Login fails:**
- Verify API credentials are correct
- Check Last.fm account is active
- Ensure internet connection is available

**Scrobbles not showing:**
- Play tracks for at least 50% duration or 4 minutes
- Check Last.fm service status at [https://status.last.fm/](https://status.last.fm/)
- Verify user is logged in (check account icon in Discover tab)

**Recommendations not loading:**
- New users may have no recommendations initially
- Listen to more tracks to build listening history
- Recommendations update based on recent listening patterns
