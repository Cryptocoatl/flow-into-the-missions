-- Storage bucket policies

-- Photos bucket: public read, authenticated upload
CREATE POLICY "Anyone can view photos" ON storage.objects
  FOR SELECT USING (bucket_id = 'photos');

CREATE POLICY "Authenticated users can upload photos" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'photos');

CREATE POLICY "Authenticated users can update photos" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'photos');

CREATE POLICY "Authenticated users can delete photos" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'photos');

-- Documents bucket: authenticated only
CREATE POLICY "Authenticated users can view documents" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'documents');

CREATE POLICY "Authenticated users can upload documents" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'documents');

CREATE POLICY "Authenticated users can update documents" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'documents');

CREATE POLICY "Authenticated users can delete documents" ON storage.objects
  FOR DELETE TO authenticated USING (bucket_id = 'documents');
