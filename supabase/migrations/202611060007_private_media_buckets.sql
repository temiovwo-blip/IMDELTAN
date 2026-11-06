-- Private bucket foundation for a NEW IMDELTAN environment only.
-- Draft: no storage.objects policies are created and no uploads are enabled.
-- Limits are initial development defaults; review them before product launch.
-- The bucket MIME allowlist is not content validation, scanning or compression.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('profile-pictures', 'profile-pictures', false, 5242880, array['image/jpeg','image/png','image/webp']),
  ('cover-pictures', 'cover-pictures', false, 10485760, array['image/jpeg','image/png','image/webp']),
  ('post-images', 'post-images', false, 10485760, array['image/jpeg','image/png','image/webp']),
  ('community-images', 'community-images', false, 10485760, array['image/jpeg','image/png','image/webp']),
  ('video-uploads', 'video-uploads', false, 104857600, array['video/mp4','video/webm']),
  ('message-attachments', 'message-attachments', false, 10485760, array['image/jpeg','image/png','image/webp','application/pdf']);
-- PRIVATE alone does not guarantee safety if a storage.objects policy already
-- grants access. Review all existing storage policies and test direct access.
-- Verified content, scanning, compression, signed-URL authorization, deletion,
-- backups and retention are not implemented here.
