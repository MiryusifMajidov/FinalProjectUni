// SMTP credentials have been moved to Firebase Secret Manager.
// This file is kept for backwards compatibility but no longer contains secrets.
// Set server-side secrets via: firebase functions:secrets:set SMTP_EMAIL / SMTP_PASSWORD
class AppSecrets {
  static const smtpEmail = '';
  static const smtpPassword = '';
}
