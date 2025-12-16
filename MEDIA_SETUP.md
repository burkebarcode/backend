# Media Upload Setup Guide

## Backend Complete ✅

The backend is ready for photo uploads using Tigris (S3-compatible storage).

### What's Been Implemented:

1. **Database Schema** (`migrations/0009_media_storage.sql`)
   - `media` table: stores all photo metadata
   - `post_media` table: links photos to posts (many-to-many)
   - Status tracking: `staged` → `attached` → `deleted`

2. **SQL Queries** (`queries/media.sql`)
   - Create/get/update media records
   - Attach media to posts
   - Get all media for a post (ordered)
   - Cleanup old staged uploads

3. **S3 Client** (`internal/media/s3.go`)
   - Generate pre-signed PUT URLs (for uploads)
   - Generate pre-signed GET URLs (for viewing)
   - Verify uploads with HeadObject
   - Object key format: `user/{userId}/posts/{postId}/{uuid}_original.jpg`

4. **API Endpoints** (`internal/api/handlers/media.go`)
   - `POST /v1/media/uploads` - Request upload URL
   - `POST /v1/media/uploads/complete` - Verify upload
   - `GET /v1/media/:id/url` - Get view URL
   - `POST /v1/posts/:post_id/media/:media_id` - Attach media to post

5. **Response Model** Updated to include `media` array in PostResponse

## Configuration Needed

### 1. Create Tigris Bucket

```bash
# Create a private bucket named "barcode-media"
# Access: Private (no public ACLs)
# Region: auto
```

### 2. Environment Variables

Add these to your `.env` or docker-compose environment:

```env
# Tigris S3 Configuration
TIGRIS_ENDPOINT=https://fly.storage.tigris.dev
TIGRIS_ACCESS_KEY=your_access_key_here
TIGRIS_SECRET_KEY=your_secret_key_here
TIGRIS_BUCKET=barcode-media
TIGRIS_REGION=auto
```

### 3. Wire Up Endpoints in Server

In `internal/api/server.go`, add:

```go
// Initialize S3 client
s3Client, err := media.NewS3Client(
    os.Getenv("TIGRIS_ENDPOINT"),
    os.Getenv("TIGRIS_ACCESS_KEY"),
    os.Getenv("TIGRIS_SECRET_KEY"),
    os.Getenv("TIGRIS_BUCKET"),
)
if err != nil {
    log.Fatal(err)
}

// Initialize media handler
mediaHandler := handlers.NewMediaHandler(queries, s3Client, os.Getenv("TIGRIS_BUCKET"))

// Register routes
v1 := router.Group("/v1")
{
    media := v1.Group("/media")
    {
        media.POST("/uploads", authMiddleware, mediaHandler.RequestUpload)
        media.POST("/uploads/complete", authMiddleware, mediaHandler.CompleteUpload)
        media.GET("/:id/url", mediaHandler.GetMediaURL)
    }

    posts := v1.Group("/posts")
    {
        posts.POST("/:post_id/media/:media_id", authMiddleware, mediaHandler.AttachMediaToPost)
    }
}
```

## Security Features

✅ **Content-type validation**: Only image/jpeg, image/png, image/heic, image/webp
✅ **Size limits**: Max 20MB per image
✅ **Pre-signed URL expiry**: 10min for uploads, 30min for viewing
✅ **Authentication required**: All upload endpoints require auth
✅ **Upload verification**: HeadObject confirms file exists before marking complete

## Upload Flow

### Client → Server → S3:

1. User picks photo in iOS
2. iOS calls `POST /v1/media/uploads` with metadata
3. Server responds with `{ uploadUrl, objectKey, mediaId }`
4. iOS uploads directly to S3 using `uploadUrl`
5. iOS calls `POST /v1/media/uploads/complete` with `mediaId`
6. Server verifies upload exists in S3
7. iOS attaches media to post using `POST /v1/posts/:post_id/media/:media_id`

## Object Key Format

- **With post**: `user/{userId}/posts/{postId}/{uuid}_original.jpg`
- **Staging**: `user/{userId}/staging/{uuid}_original.jpg`
- **Thumbnail**: `user/{userId}/posts/{postId}/{uuid}_thumb.jpg`

## Next Steps

1. Add environment variables to docker-compose.yaml
2. Wire up endpoints in server.go
3. Test with Postman or curl
4. Implement iOS photo upload flow

## iOS Implementation TODO

1. Photo picker with compression
2. Direct S3 upload using pre-signed URL
3. Media attachment to posts
4. Display photos in feed/detail views
