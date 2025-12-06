create type "public"."audit_action_scope" as enum ('auth', 'crud', 'config', 'billing', 'jobs', 'files', 'api', 'other');

create table "public"."audit_log" (
  "id" uuid not null default gen_random_uuid(),
  "created_at" timestamp with time zone not null default now(),
  "user_id" uuid,
  "request_id" uuid,
  "trace_id" text,
  "action" text not null,
  "action_scope" public.audit_action_scope not null default 'other'::public.audit_action_scope,
  "entity_schema" text,
  "entity_table" text,
  "entity_type" text,
  "entity_id" text,
  "entity_ids" jsonb,
  "row_pk" jsonb,
  "old_data" jsonb,
  "new_data" jsonb,
  "diff" jsonb,
  "metadata" jsonb not null default '{}'::jsonb,
  "success" boolean not null default true,
  "status_code" integer,
  "error_code" text,
  "error_message" text,
  "latency_ms" integer
);

alter table "public"."audit_log" enable row level security;

create table "public"."package_preset_rooms" (
  "package_id" uuid not null,
  "exercise_room_id" uuid not null,
  "tokens" integer not null
);

create table "public"."package_presets" (
  "id" uuid not null default gen_random_uuid(),
  "created_at" timestamp with time zone not null default now(),
  "name" text not null,
  "description" text default ''::text,
  "price_cents" integer not null,
  "currency" text not null default 'EUR'::text,
  "duration_days" integer not null default 30,
  "metadata" jsonb default '{}'::jsonb
);

create table "public"."user_subscription_rooms" (
  "subscription_id" uuid not null,
  "exercise_room_id" uuid not null,
  "tokens" integer not null
);

create table "public"."user_subscriptions" (
  "id" uuid not null default gen_random_uuid(),
  "created_at" timestamp with time zone not null default now(),
  "user_id" uuid not null,
  "type" text not null,
  "package_preset_id" uuid,
  "config" jsonb default '{}'::jsonb,
  "stripe_customer_id" text,
  "stripe_subscription_id" text,
  "stripe_checkout_session_id" text,
  "auto_renew" boolean default false,
  "status" text not null default 'pending'::text,
  "subscription_start_date" timestamp with time zone,
  "subscription_end_date" timestamp with time zone,
  "current_available_tokens" integer,
  "max_available_tokens" integer,
  "notes" text
);

CREATE INDEX audit_log_action_idx ON public.audit_log USING btree (action);
CREATE INDEX audit_log_created_at_idx ON public.audit_log USING btree (created_at DESC);
CREATE INDEX audit_log_entity_idx ON public.audit_log USING btree (entity_type, entity_id);
CREATE INDEX audit_log_metadata_gin_idx ON public.audit_log USING gin (metadata);
CREATE INDEX audit_log_new_gin_idx ON public.audit_log USING gin (new_data);
CREATE INDEX audit_log_old_gin_idx ON public.audit_log USING gin (old_data);
CREATE UNIQUE INDEX audit_log_pkey ON public.audit_log USING btree (id);
CREATE INDEX audit_log_request_idx ON public.audit_log USING btree (request_id);
CREATE INDEX audit_log_scope_idx ON public.audit_log USING btree (action_scope);
CREATE INDEX audit_log_success_idx ON public.audit_log USING btree (success);
CREATE INDEX audit_log_user_idx ON public.audit_log USING btree (user_id);

CREATE UNIQUE INDEX package_preset_rooms_pkey ON public.package_preset_rooms USING btree (package_id, exercise_room_id);
CREATE UNIQUE INDEX package_presets_pkey ON public.package_presets USING btree (id);
CREATE UNIQUE INDEX user_subscription_rooms_pkey ON public.user_subscription_rooms USING btree (subscription_id, exercise_room_id);
CREATE UNIQUE INDEX user_subscriptions_pkey ON public.user_subscriptions USING btree (id);

alter table "public"."audit_log" add constraint "audit_log_pkey" PRIMARY KEY using index "audit_log_pkey";
alter table "public"."package_preset_rooms" add constraint "package_preset_rooms_pkey" PRIMARY KEY using index "package_preset_rooms_pkey";
alter table "public"."package_presets" add constraint "package_presets_pkey" PRIMARY KEY using index "package_presets_pkey";
alter table "public"."user_subscription_rooms" add constraint "user_subscription_rooms_pkey" PRIMARY KEY using index "user_subscription_rooms_pkey";
alter table "public"."user_subscriptions" add constraint "user_subscriptions_pkey" PRIMARY KEY using index "user_subscriptions_pkey";

alter table "public"."audit_log" add constraint "action_not_blank" CHECK ((length(TRIM(BOTH FROM action)) > 0)) not valid;
alter table "public"."audit_log" validate constraint "action_not_blank";

alter table "public"."audit_log" add constraint "audit_log_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL not valid;
alter table "public"."audit_log" validate constraint "audit_log_user_id_fkey";

alter table "public"."package_preset_rooms" add constraint "package_preset_rooms_exercise_room_id_fkey" FOREIGN KEY (exercise_room_id) REFERENCES public.exercise_rooms(id) not valid;
alter table "public"."package_preset_rooms" validate constraint "package_preset_rooms_exercise_room_id_fkey";

alter table "public"."package_preset_rooms" add constraint "package_preset_rooms_package_id_fkey" FOREIGN KEY (package_id) REFERENCES public.package_presets(id) ON DELETE CASCADE not valid;
alter table "public"."package_preset_rooms" validate constraint "package_preset_rooms_package_id_fkey";

alter table "public"."user_subscription_rooms" add constraint "user_subscription_rooms_exercise_room_id_fkey" FOREIGN KEY (exercise_room_id) REFERENCES public.exercise_rooms(id) not valid;
alter table "public"."user_subscription_rooms" validate constraint "user_subscription_rooms_exercise_room_id_fkey";

alter table "public"."user_subscription_rooms" add constraint "user_subscription_rooms_subscription_id_fkey" FOREIGN KEY (subscription_id) REFERENCES public.user_subscriptions(id) ON DELETE CASCADE not valid;
alter table "public"."user_subscription_rooms" validate constraint "user_subscription_rooms_subscription_id_fkey";

alter table "public"."user_subscriptions" add constraint "user_subscriptions_package_preset_id_fkey" FOREIGN KEY (package_preset_id) REFERENCES public.package_presets(id) not valid;
alter table "public"."user_subscriptions" validate constraint "user_subscriptions_package_preset_id_fkey";

alter table "public"."user_subscriptions" add constraint "user_subscriptions_type_check" CHECK ((type = ANY (ARRAY['preset'::text, 'custom'::text]))) not valid;
alter table "public"."user_subscriptions" validate constraint "user_subscriptions_type_check";

alter table "public"."user_subscriptions" add constraint "user_subscriptions_user_id_fkey" FOREIGN KEY (user_id) REFERENCES public.users(id) not valid;
alter table "public"."user_subscriptions" validate constraint "user_subscriptions_user_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.log_event(
  p_action text,
  p_action_scope public.audit_action_scope DEFAULT 'other'::public.audit_action_scope,
  p_entity_schema text DEFAULT NULL::text,
  p_entity_table text DEFAULT NULL::text,
  p_entity_type text DEFAULT NULL::text,
  p_entity_id text DEFAULT NULL::text,
  p_entity_ids jsonb DEFAULT NULL::jsonb,
  p_row_pk jsonb DEFAULT NULL::jsonb,
  p_old_data jsonb DEFAULT NULL::jsonb,
  p_new_data jsonb DEFAULT NULL::jsonb,
  p_diff jsonb DEFAULT NULL::jsonb,
  p_success boolean DEFAULT true,
  p_status_code integer DEFAULT NULL::integer,
  p_error_code text DEFAULT NULL::text,
  p_error_message text DEFAULT NULL::text,
  p_latency_ms integer DEFAULT NULL::integer,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_request_id uuid DEFAULT NULL::uuid,
  p_trace_id text DEFAULT NULL::text,
  p_user_id uuid DEFAULT NULL::uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
declare
  v_user_id uuid := p_user_id;
  v_id uuid;
begin
  -- Infer user_id from auth.uid() via public.users.auth_id when not provided
  if v_user_id is null then
    select u.id into v_user_id
    from public.users u
    where u.auth_id is not distinct from auth.uid()
    limit 1;
  end if;

  insert into public.audit_log (
    id, created_at,
    user_id,
    request_id, trace_id,
    action, action_scope,
    entity_schema, entity_table, entity_type, entity_id, entity_ids, row_pk,
    old_data, new_data, diff, metadata,
    success, status_code, error_code, error_message, latency_ms
  )
  values (
    gen_random_uuid(), now(),
    v_user_id,
    p_request_id, p_trace_id,
    p_action, p_action_scope,
    p_entity_schema, p_entity_table, p_entity_type, p_entity_id, p_entity_ids, p_row_pk,
    p_old_data, p_new_data, p_diff, p_metadata,
    p_success, p_status_code, p_error_code, p_error_message, p_latency_ms
  )
  returning id into v_id;

  return v_id;
end
$function$
;

create or replace view "public"."v_recent_events" as
select
  audit_log.id,
  audit_log.created_at,
  audit_log.user_id,
  audit_log.request_id,
  audit_log.trace_id,
  audit_log.action,
  audit_log.action_scope,
  audit_log.entity_schema,
  audit_log.entity_table,
  audit_log.entity_type,
  audit_log.entity_id,
  audit_log.entity_ids,
  audit_log.row_pk,
  audit_log.old_data,
  audit_log.new_data,
  audit_log.diff,
  audit_log.metadata,
  audit_log.success,
  audit_log.status_code,
  audit_log.error_code,
  audit_log.error_message,
  audit_log.latency_ms
from public.audit_log
order by audit_log.created_at desc
limit 1000;

create policy "audit_log_insert_service_only"
on "public"."audit_log"
as permissive
for insert
to public
with check ((auth.role() = 'service_role'::text));

create policy "audit_log_select_admin"
on "public"."audit_log"
as permissive
for select
to authenticated
using (
  (auth.role() = 'service_role'::text)
  OR COALESCE(((auth.jwt() ->> 'role'::text) = 'admin'::text), false)
  OR COALESCE(((auth.jwt() ->> 'is_admin'::text))::boolean, false)
);

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."audit_log" to "anon";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."audit_log" to "authenticated";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."audit_log" to "service_role";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."package_preset_rooms" to "anon";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."package_preset_rooms" to "authenticated";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."package_preset_rooms" to "service_role";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."package_presets" to "anon";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."package_presets" to "authenticated";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."package_presets" to "service_role";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."user_subscription_rooms" to "anon";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."user_subscription_rooms" to "authenticated";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."user_subscription_rooms" to "service_role";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."user_subscriptions" to "anon";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."user_subscriptions" to "authenticated";

grant delete, insert, references, select, trigger, truncate, update
  on table "public"."user_subscriptions" to "service_role";
