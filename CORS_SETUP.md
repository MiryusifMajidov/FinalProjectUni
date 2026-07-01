# Firebase Storage CORS Setup

## Apply CORS Configuration

Run this command from the project root to apply CORS rules to your Firebase Storage bucket.
Replace `YOUR_BUCKET` with your actual bucket name (e.g. `your-project-id.appspot.com`).

```bash
gsutil cors set cors.json gs://YOUR_BUCKET
```

To verify the CORS configuration was applied:

```bash
gsutil cors get gs://YOUR_BUCKET
```

## Firebase Storage Security Rules

Add these rules in the Firebase console under Storage > Rules:

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_photos/{userId}.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

## Notes

- The `cors.json` file allows all origins (`*`). For production, replace `"*"` with your specific domain(s).
- CORS must be set on the Storage bucket before web uploads will work.
- The `gsutil` tool is part of the Google Cloud SDK. Install it from https://cloud.google.com/sdk/docs/install
