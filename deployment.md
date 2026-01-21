# TrackMapper Deployment Guide

This document outlines the architecture and deployment steps for the TrackMapper application, including the Flask backend, PostgreSQL database, and S3 file storage.

## 1. Architecture Overview

- **Backend**: Flask application using SQLAlchemy (v2.x) and PostgreSQL.
- **Frontend**: iOS (SwiftUI) app.
- **Database**: PostgreSQL with UUIDs for all primary/foreign keys.
- **Storage**: Hybrid storage system (AWS S3 or Local Filesystem).
- **Authentication**: Google OAuth 2.0 with backend user synchronization.

## 2. Backend Configuration (`track_mapper_flask`)

The backend uses a `.env` file for configuration. Ensure the following variables are set:

### Database
- `DATABASE_URL`: Connection string for PostgreSQL.
  - Local: `postgresql://localhost:5432/trackmapper`
  - Production (Render/Neon): `postgresql://user:pass@host:port/dbname`

### Storage
- `FILE_STORE_LOCATION`: Set to `S3` for production, `LOCAL` for development.
- `S3_BUCKET`: Name of your S3 bucket (e.g., `trackmapper`).
- `S3_ACCESS_KEY`: AWS Access Key ID.
- `S3_SECRET_KEY`: AWS Secret Access Key.
- `S3_REGION`: S3 bucket region (e.g., `us-east-1`).
- `S3_ENDPOINT_URL`: (Optional) Custom endpoint for S3-compatible storage (e.g., Cloudflare R2).

### File Structure
Files are organized into subfolders within the bucket/upload directory:
- `images/`: Map image files (`<uuid>.jpg`)
- `points/`: Map coordinate JSON files (`<uuid>.json`)
- `activities/`: Activity GPX files (`<uuid>.gpx`)

## 3. Infrastructure Setup

### AWS S3 & IAM
1.  **Create Bucket**: Create a private S3 bucket named `trackmapper`.
2.  **Enable S3 Bucket Key**: Keep this enabled to reduce encryption costs (SSE-KMS).
3.  **IAM Policy**: Created a user (trackmapper_server) with the following restricted policy:
    ```json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ],
                "Resource": [
                    "arn:aws:s3:::trackmapper",
                    "arn:aws:s3:::trackmapper/*"
                ]
            }
        ]
    }
    ```

### Hosting (Render.com)
1.  **Web Service**: Deploy the `track_mapper_flask` directory.
2.  **Environment Groups**: Add all `.env` variables to Render's Environment Variables dashboard.
3.  **PostgreSQL**: Provision a Render PostgreSQL instance and copy the Internal Database URL to `DATABASE_URL`.
4.  **Start Command**: Set the start command to:
    ```bash
    gunicorn run:app
    ```

## 4. Frontend Configuration (`TrackMapper`)

### Global Constants
Update `TrackMapper/Util/Config.swift` with production values:
- `baseURL`: The URL of your deployed Flask app.
- `fileURL`: The base download endpoint (usually `baseURL + "/download"`).
- `googleOAuthClientID`: Your iOS Google OAuth Client ID.

### Authentication
- Google Sign-In is configured in `TrackMapperApp.swift`.
- Redirect URLs are handled via `onOpenURL`.
- The app synchronizes with the backend via the `/auth/google` endpoint.

## 5. Deployment Steps

1.  **Database Migration**:
    - For initial setup, the app uses `db.create_all()` in `app/__init__.py`.
    - For future schema changes, use Flask-Migrate (Alembic).
2.  **Seed Data**:
    - Use `synthetic.py` to populate the database with test data if needed.
3.  **File Migration**:
    - Use `migrate.py` to move data from local SQLite/uploads to Postgres/S3.

## 6. Security Notes
- All sensitive routes are protected by the `@require_auth` decorator in `app/routes.py`.
- Tokens are generated using the `token-<uuid>` format.
- S3 files are served via 1-hour presigned URLs for secure, direct-from-S3 downloads.
