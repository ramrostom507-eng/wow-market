-- WOW MARKET analytics foundation
-- Run once in the Supabase SQL Editor for project nxjrfphelxtwxembxuel.
create table if not exists public.site_analytics_events (
  id bigint generated always as identity primary key,
  event_type text not null check (event_type in ('page_view','product_impression','product_click','add_to_cart','checkout_start','purchase')),
  visitor_id uuid not null,
  session_id uuid not null,
  path text not null default '/',
  referrer_host text,
  product_id uuid references public.products(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint site_analytics_path_length check (char_length(path) <= 500),
  constraint site_analytics_referrer_length check (referrer_host is null or char_length(referrer_host) <= 255)
);

create index if not exists site_analytics_created_at_idx on public.site_analytics_events(created_at desc);
create index if not exists site_analytics_type_created_idx on public.site_analytics_events(event_type, created_at desc);
create index if not exists site_analytics_product_idx on public.site_analytics_events(product_id, created_at desc);

alter table public.site_analytics_events enable row level security;

drop policy if exists "analytics insert events" on public.site_analytics_events;
create policy "analytics insert events" on public.site_analytics_events
for insert to anon, authenticated
with check (
  event_type in ('page_view','product_impression','product_click','add_to_cart','checkout_start','purchase')
  and visitor_id is not null
  and session_id is not null
  and char_length(path) <= 500
  and (referrer_host is null or char_length(referrer_host) <= 255)
);

drop policy if exists "admins read analytics" on public.site_analytics_events;
create policy "admins read analytics" on public.site_analytics_events
for select to authenticated
using ((select private.is_admin()));

revoke all on public.site_analytics_events from public;
grant insert on public.site_analytics_events to anon, authenticated;
grant select on public.site_analytics_events to authenticated;

create or replace function public.get_site_analytics(p_days integer default 30)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
with filtered as (
  select event_type, visitor_id, product_id, referrer_host, created_at
  from public.site_analytics_events
  where created_at >= now() - make_interval(days => least(greatest(coalesce(p_days,30),1),365))
)
select jsonb_build_object(
  'views', count(*) filter (where event_type = 'page_view'),
  'visitors', count(distinct visitor_id),
  'product_views', count(*) filter (where event_type = 'product_impression'),
  'daily', coalesce((
    select jsonb_agg(jsonb_build_object('day', d.day, 'views', d.views, 'visitors', d.visitors) order by d.day)
    from (
      select created_at::date as day,
             count(*) filter (where event_type = 'page_view') as views,
             count(distinct visitor_id) as visitors
      from filtered
      group by created_at::date
    ) d
  ), '[]'::jsonb),
  'top_products', coalesce((
    select jsonb_agg(jsonb_build_object('title', q.title, 'views', q.views) order by q.views desc)
    from (
      select coalesce(p.title, 'منتج محذوف') as title, count(*) as views
      from filtered f
      left join public.products p on p.id = f.product_id
      where f.event_type = 'product_impression'
      group by p.title
      order by views desc
      limit 5
    ) q
  ), '[]'::jsonb),
  'top_sources', coalesce((
    select jsonb_agg(jsonb_build_object('source', q.source, 'visits', q.visits) order by q.visits desc)
    from (
      select coalesce(referrer_host, 'مباشر') as source, count(*) as visits
      from filtered
      where event_type = 'page_view'
      group by coalesce(referrer_host, 'مباشر')
      order by visits desc
      limit 8
    ) q
  ), '[]'::jsonb)
)
from filtered;
$$;

revoke all on function public.get_site_analytics(integer) from public;
grant execute on function public.get_site_analytics(integer) to authenticated;
