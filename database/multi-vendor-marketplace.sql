-- WOW MARKET multi-vendor marketplace foundation
-- Applied to Supabase project nxjrfphelxtwxembxuel on 2026-11-19.
create table if not exists public.seller_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  store_name text not null check (char_length(store_name) between 2 and 80),
  display_name text not null check (char_length(display_name) between 2 and 80),
  country text not null,
  description text not null default '' check (char_length(description) <= 600),
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  reviewed_at timestamptz,
  reviewed_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null references auth.users(id),
  order_number text not null unique default ('WOW-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))),
  currency text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  subtotal numeric(12,2) not null check (subtotal >= 0),
  platform_fee numeric(12,2) not null default 0 check (platform_fee >= 0),
  total numeric(12,2) not null check (total >= 0),
  payment_provider text not null default 'not_configured',
  payment_reference text,
  payment_status text not null default 'pending' check (payment_status in ('pending','paid','failed','refunded','partially_refunded')),
  fulfillment_status text not null default 'pending' check (fulfillment_status in ('pending','processing','completed','cancelled')),
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  seller_id uuid not null references auth.users(id),
  product_title text not null,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  quantity integer not null default 1 check (quantity between 1 and 20),
  commission_rate numeric(5,4) not null default 0.02 check (commission_rate >= 0 and commission_rate <= 0.25),
  seller_amount numeric(12,2) not null check (seller_amount >= 0),
  created_at timestamptz not null default now()
);
create table if not exists public.seller_payouts (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references auth.users(id),
  amount numeric(12,2) not null check (amount > 0),
  currency text not null default 'EUR' check (currency ~ '^[A-Z]{3}$'),
  status text not null default 'pending' check (status in ('pending','processing','paid','failed')),
  payout_method text,
  payout_reference text,
  notes text,
  created_at timestamptz not null default now(),
  paid_at timestamptz
);
create table if not exists public.platform_settings (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);
insert into public.platform_settings(key,value) values
 ('commission_launch', '{"rate":0.02,"duration_months":6,"label":"عمولة الإطلاق"}'::jsonb),
 ('commission_standard', '{"rate":0.05,"label":"العمولة العادية"}'::jsonb),
 ('seller_registration', '{"fee":0,"monthly_fee":0}'::jsonb)
on conflict (key) do nothing;
create index if not exists orders_buyer_created_idx on public.orders(buyer_id, created_at desc);
create index if not exists order_items_seller_idx on public.order_items(seller_id, created_at desc);
create index if not exists seller_payouts_seller_idx on public.seller_payouts(seller_id, created_at desc);
create index if not exists seller_profiles_status_idx on public.seller_profiles(status);
create index if not exists products_status_created_idx on public.products(status, created_at desc);
alter table public.seller_profiles enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.seller_payouts enable row level security;
alter table public.platform_settings enable row level security;
drop policy if exists "seller profile read own or approved" on public.seller_profiles;
create policy "seller profile read own or approved" on public.seller_profiles for select to anon, authenticated
using (status = 'approved' or user_id = (select auth.uid()) or (select private.is_admin()));
drop policy if exists "seller apply own pending profile" on public.seller_profiles;
create policy "seller apply own pending profile" on public.seller_profiles for insert to authenticated
with check (user_id = (select auth.uid()) and status = 'pending');
drop policy if exists "seller update own pending profile" on public.seller_profiles;
create policy "seller update own pending profile" on public.seller_profiles for update to authenticated
using (user_id = (select auth.uid()) and status in ('pending','rejected'))
with check (user_id = (select auth.uid()) and status = 'pending');
drop policy if exists "admin manage seller profiles" on public.seller_profiles;
create policy "admin manage seller profiles" on public.seller_profiles for all to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));
drop policy if exists "buyer or admin read orders" on public.orders;
create policy "buyer or admin read orders" on public.orders for select to authenticated
using (buyer_id = (select auth.uid()) or (select private.is_admin()));
drop policy if exists "buyer or seller read order items" on public.order_items;
create policy "buyer or seller read order items" on public.order_items for select to authenticated
using (seller_id = (select auth.uid()) or exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = (select auth.uid())) or (select private.is_admin()));
drop policy if exists "seller read own payouts" on public.seller_payouts;
create policy "seller read own payouts" on public.seller_payouts for select to authenticated
using (seller_id = (select auth.uid()) or (select private.is_admin()));
drop policy if exists "admin manage orders" on public.orders;
create policy "admin manage orders" on public.orders for all to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));
drop policy if exists "admin manage order items" on public.order_items;
create policy "admin manage order items" on public.order_items for all to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));
drop policy if exists "admin manage seller payouts" on public.seller_payouts;
create policy "admin manage seller payouts" on public.seller_payouts for all to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));
drop policy if exists "public read platform settings" on public.platform_settings;
create policy "public read platform settings" on public.platform_settings for select to anon, authenticated using (true);
drop policy if exists "admin manage platform settings" on public.platform_settings;
create policy "admin manage platform settings" on public.platform_settings for all to authenticated
using ((select private.is_admin())) with check ((select private.is_admin()));
grant select on public.seller_profiles to anon, authenticated;
grant insert, update on public.seller_profiles to authenticated;
grant select on public.orders, public.order_items, public.seller_payouts to authenticated;
grant select on public.platform_settings to anon, authenticated;
grant insert, update, delete on public.orders, public.order_items, public.seller_payouts, public.platform_settings to authenticated;
drop policy if exists "seller submit own pending products" on public.products;
create policy "seller submit own pending products" on public.products for insert to authenticated
with check (seller_id = (select auth.uid()) and status = 'pending' and exists (select 1 from public.seller_profiles sp where sp.user_id = (select auth.uid()) and sp.status = 'approved'));
drop policy if exists "seller update own unapproved products" on public.products;
create policy "seller update own unapproved products" on public.products for update to authenticated
using (seller_id = (select auth.uid()) and status in ('pending','rejected') and exists (select 1 from public.seller_profiles sp where sp.user_id = (select auth.uid()) and sp.status = 'approved'))
with check (seller_id = (select auth.uid()) and status in ('pending','rejected') and exists (select 1 from public.seller_profiles sp where sp.user_id = (select auth.uid()) and sp.status = 'approved'));
