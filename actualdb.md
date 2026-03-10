-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.active_rescuers_location (
rescuer_id uuid NOT NULL,
current_location USER-DEFINED NOT NULL,
is_available boolean DEFAULT true,
last_updated timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT active_rescuers_location_pkey PRIMARY KEY (rescuer_id),
CONSTRAINT active_rescuers_location_rescuer_id_fkey FOREIGN KEY (rescuer_id) REFERENCES public.users(id)
);
CREATE TABLE public.dispatch_ring_config (
severity text NOT NULL,
ring integer NOT NULL,
radius_m integer NOT NULL,
wait_seconds integer NOT NULL,
CONSTRAINT dispatch_ring_config_pkey PRIMARY KEY (severity, ring)
);
CREATE TABLE public.incidents (
id uuid NOT NULL DEFAULT uuid_generate_v4(),
reporter_id uuid NOT NULL,
photo_url text NOT NULL,
geo_location USER-DEFINED NOT NULL,
severity text NOT NULL CHECK (severity = ANY (ARRAY['Severe'::text, 'Moderate'::text, 'Minor'::text])),
status text NOT NULL DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'dispatched'::text, 'active'::text, 'rehabilitated'::text, 'cancelled'::text, 'unresponded'::text])),
assigned_rescuer_id uuid,
duplicate_case_of uuid,
created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
dispatch_ring integer NOT NULL DEFAULT 1,
last_broadcast_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
notified_rescuers ARRAY DEFAULT '{}'::uuid[],
title text,
location_name text,
rescue_photo_url text,
drop_off_type text CHECK (drop_off_type IS NULL OR (drop_off_type = ANY (ARRAY['vet_hospital'::text, 'ngo_shelter'::text, 'treated_on_scene'::text]))),
witness_count integer NOT NULL DEFAULT 0,
urgency_score integer NOT NULL DEFAULT 0,
CONSTRAINT incidents_pkey PRIMARY KEY (id),
CONSTRAINT incidents_duplicate_case_of_fkey FOREIGN KEY (duplicate_case_of) REFERENCES public.incidents(id),
CONSTRAINT incidents_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id),
CONSTRAINT incidents_assigned_rescuer_id_fkey FOREIGN KEY (assigned_rescuer_id) REFERENCES public.users(id)
);
CREATE TABLE public.ngos (
id uuid NOT NULL DEFAULT uuid_generate_v4(),
name text NOT NULL,
contact_email text,
contact_phone text,
operating_city text,
verified boolean DEFAULT false,
created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT ngos_pkey PRIMARY KEY (id)
);
CREATE TABLE public.notifications (
id uuid NOT NULL DEFAULT uuid_generate_v4(),
user_id uuid NOT NULL,
incident_id uuid,
type text NOT NULL CHECK (type = ANY (ARRAY['sos_broadcast'::text, 'dispatched'::text, 'eta_update'::text, 'rescued'::text, 'cancelled'::text])),
payload jsonb DEFAULT '{}'::jsonb,
sent_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
delivered boolean DEFAULT false,
CONSTRAINT notifications_pkey PRIMARY KEY (id),
CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id),
CONSTRAINT notifications_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id)
);
CREATE TABLE public.rescue_condition_log (
id uuid NOT NULL DEFAULT uuid_generate_v4(),
incident_id uuid NOT NULL,
rescuer_id uuid NOT NULL,
stage text NOT NULL CHECK (stage = ANY (ARRAY['en_route'::text, 'on_scene'::text, 'first_aid'::text, 'in_transport'::text, 'at_vet'::text, 'recovered'::text])),
note text,
photo_url text,
created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT rescue_condition_log_pkey PRIMARY KEY (id),
CONSTRAINT rescue_condition_log_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id),
CONSTRAINT rescue_condition_log_rescuer_id_fkey FOREIGN KEY (rescuer_id) REFERENCES public.users(id)
);
CREATE TABLE public.rescue_location_history (
id uuid NOT NULL DEFAULT uuid_generate_v4(),
incident_id uuid NOT NULL,
rescuer_id uuid NOT NULL,
location USER-DEFINED NOT NULL,
recorded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT rescue_location_history_pkey PRIMARY KEY (id),
CONSTRAINT rescue_location_history_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id),
CONSTRAINT rescue_location_history_rescuer_id_fkey FOREIGN KEY (rescuer_id) REFERENCES public.users(id)
);
CREATE TABLE public.rescuer_credits (
id uuid NOT NULL DEFAULT uuid_generate_v4(),
rescuer_id uuid NOT NULL,
incident_id uuid,
credits_earned integer NOT NULL DEFAULT 0,
reason text NOT NULL,
created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
CONSTRAINT rescuer_credits_pkey PRIMARY KEY (id),
CONSTRAINT rescuer_credits_rescuer_id_fkey FOREIGN KEY (rescuer_id) REFERENCES public.users(id),
CONSTRAINT rescuer_credits_incident_id_fkey FOREIGN KEY (incident_id) REFERENCES public.incidents(id)
);
CREATE TABLE public.spatial_ref_sys (
srid integer NOT NULL CHECK (srid > 0 AND srid <= 998999),
auth_name character varying,
auth_srid integer,
srtext character varying,
proj4text character varying,
CONSTRAINT spatial_ref_sys_pkey PRIMARY KEY (srid)
);
CREATE TABLE public.users (
id uuid NOT NULL,
full_name text NOT NULL DEFAULT ''::text,
email text NOT NULL UNIQUE,
role text NOT NULL DEFAULT 'citizen'::text CHECK (role = ANY (ARRAY['citizen'::text, 'rescuer'::text, 'admin'::text])),
verified_rescuer boolean DEFAULT false,
associated_ngo_id uuid,
created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
phone text,
avatar_url text,
CONSTRAINT users_pkey PRIMARY KEY (id),
CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
CONSTRAINT users_associated_ngo_id_fkey FOREIGN KEY (associated_ngo_id) REFERENCES public.ngos(id)
);
