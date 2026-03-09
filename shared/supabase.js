// Supabase Configuration
// These values are set during infrastructure setup (/setup-alpacapps-infra)
const SUPABASE_URL = 'https://bjrbtfcdnpoiguhngbch.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJqcmJ0ZmNkbnBvaWd1aG5nYmNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMwODE4MjIsImV4cCI6MjA4ODY1NzgyMn0.QI-BoWVYoYMVX6SNXSt8xaWLPfpL6fdEl_aHtkSV6WA';

// Initialize Supabase client
const supabase = window.supabase
    ? window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
    : null;

// Storage helpers
const STORAGE = {
    photos: {
        bucket: 'photos',
        getPublicUrl: (path) => `${SUPABASE_URL}/storage/v1/object/public/photos/${path}`,
    },
    documents: {
        bucket: 'documents',
    },
};
