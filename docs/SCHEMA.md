# Database Schema Reference

> This file is loaded on-demand. Referenced from CLAUDE.md.
> Updated by the setup wizard and as tables are added/modified.

## Core Tables

### page_display_config
Controls which tabs are visible in each admin section.
- Columns: id (UUID PK), section, tab_key, tab_label, is_visible, sort_order, created_at, updated_at
- UNIQUE(section, tab_key)
- RLS: Authenticated read/update/insert

### profiles
Extends auth.users. Auto-created on signup via trigger.
- Columns: id (UUID PK → auth.users), email, full_name, avatar_url, phone, role (admin/staff/member/resident/associate), is_active, metadata (JSONB), created_at, updated_at
- RLS: Public read, self-update, admin insert

### spaces
Rooms, units, common areas, outdoor spaces.
- Columns: id (UUID PK), name, type (room/unit/common_area/office/outdoor/storage), description, capacity, floor, building, is_available, is_archived, amenities (JSONB), photos (JSONB), rate_daily/weekly/monthly (NUMERIC), metadata, created_at, updated_at
- RLS: Public read, authenticated write

### tenants
Residents linked to spaces.
- Columns: id (UUID PK), user_id (FK → profiles), full_name, email, phone, space_id (FK → spaces), move_in_date, move_out_date, status (active/inactive/pending/archived), emergency_contact (JSONB), notes, is_archived, metadata, created_at, updated_at
- RLS: Authenticated read/write

### bookings
Space reservations.
- Columns: id (UUID PK), space_id (FK → spaces), tenant_id (FK → tenants), guest_name/email/phone, check_in (DATE), check_out (DATE), status (pending/confirmed/checked_in/checked_out/cancelled), total_amount, payment_status (unpaid/partial/paid/refunded), notes, is_archived, metadata, created_at, updated_at
- RLS: Authenticated read/write

### events
Community events.
- Columns: id (UUID PK), title, description, location, space_id (FK → spaces), start_time (TIMESTAMPTZ), end_time, is_public, max_attendees, cover_image, organizer_id (FK → profiles), status (upcoming/active/completed/cancelled), is_archived, metadata, created_at, updated_at
- RLS: Public read (if is_public), authenticated write

### event_registrations
- Columns: id (UUID PK), event_id (FK → events), user_id (FK → profiles), name, email, status (registered/attended/cancelled), created_at
- RLS: Authenticated read, public insert

### devices
Smart home, equipment, vehicles.
- Columns: id (UUID PK), name, type (lock/camera/thermostat/light/sensor/appliance/vehicle/other), brand, model, serial_number, space_id (FK → spaces), status (online/offline/maintenance/retired), last_seen_at, config (JSONB), is_archived, metadata, created_at, updated_at
- RLS: Authenticated read/write

### contacts
CRM contacts.
- Columns: id (UUID PK), full_name, email, phone, company, role, type (general/vendor/partner/donor/volunteer/lead), notes, is_archived, metadata, created_at, updated_at
- RLS: Authenticated read/write

### communications
Email/SMS log.
- Columns: id (UUID PK), channel (email/sms/push/in_app), direction (inbound/outbound), recipient, sender, subject, body, status (queued/sent/delivered/failed/bounced), related_type, related_id, metadata, created_at
- RLS: Authenticated read/insert

### payments
- Columns: id (UUID PK), tenant_id (FK → tenants), booking_id (FK → bookings), amount (NUMERIC), currency, provider (square/stripe/cash/check/other), provider_payment_id, status (pending/completed/failed/refunded), description, metadata, created_at
- RLS: Authenticated read/write

### documents
Leases, agreements, e-signatures.
- Columns: id (UUID PK), title, type (lease/agreement/invoice/receipt/general/policy), file_url, file_path, tenant_id (FK → tenants), signwell_document_id, signature_status (unsigned/pending/signed/declined/expired), signed_at, metadata, created_at, updated_at
- RLS: Authenticated read/write

### photos
Gallery photos.
- Columns: id (UUID PK), title, description, url, storage_path, space_id (FK → spaces), event_id (FK → events), uploaded_by (FK → profiles), is_public, is_archived, tags (JSONB), metadata, created_at
- RLS: Public read (if is_public), authenticated write

## Service Config Tables

### telnyx_config
- Columns: id (UUID PK), api_key, messaging_profile_id, phone_number, webhook_url, is_active, created_at
- RLS: Authenticated read

### sms_messages
- Columns: id (UUID PK), direction, from_number, to_number, body, status, provider_message_id, metadata, created_at
- RLS: Authenticated read/insert

### square_config
- Columns: id (UUID PK), application_id, location_id, environment (sandbox/production), is_active, created_at
- RLS: Authenticated read

### stripe_config
- Columns: id (UUID PK), publishable_key, environment (test/live), webhook_url, is_active, created_at
- RLS: Authenticated read

### stripe_payments
- Columns: id (UUID PK), payment_intent_id, amount, currency, status, payment_method_type, customer_email, description, metadata, created_at
- RLS: Authenticated read, public insert

### signwell_config
- Columns: id (UUID PK), api_key, webhook_url, is_active, created_at
- RLS: Authenticated read

### r2_config
- Columns: id (UUID PK), account_id, bucket_name, public_url, is_active, created_at
- RLS: Authenticated read

## Storage Buckets

- `photos` — Public read, authenticated upload. For gallery/space images.
- `documents` — Private. For leases, agreements, invoices.

## Common Patterns

- All tables use UUID primary keys
- All tables have `created_at` and `updated_at` timestamps
- RLS is enabled on all tables
- `is_archived` flag for soft deletes (filter client-side)
- `updated_at` auto-updates via trigger on all relevant tables
