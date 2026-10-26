-- Team Jahja นักล่า PM: ตั้งค่าฐานข้อมูล (รันครั้งเดียวใน Supabase > SQL Editor)

-- 1) รายชื่อทีม: เฉพาะอีเมลในตารางนี้ที่ดู/แก้นัดได้
create table if not exists public.team_members (
  email text primary key,
  name  text
);
alter table public.team_members enable row level security;

create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.team_members
                 where lower(email) = lower(coalesce(auth.jwt() ->> 'email','')));
$$;

drop policy if exists "members read team" on public.team_members;
create policy "members read team" on public.team_members
  for select to authenticated
  using (public.is_member() or lower(email) = lower(auth.jwt() ->> 'email'));

-- 2) ข้อมูลแอป: นัด (appts), Booking (bookings), Success (successes), รายชื่อเซลล์ (config/agents)
create table if not exists public.docs (
  collection text not null,
  id         text not null,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (collection, id)
);
create index if not exists docs_date_idx on public.docs (collection, (data ->> 'date'));
alter table public.docs enable row level security;
alter table public.docs replica identity full;

drop policy if exists "members all" on public.docs;
create policy "members all" on public.docs
  for all to authenticated
  using (public.is_member()) with check (public.is_member());

-- แก้บางช่องของนัด (เช่น สถานะ) โดยไม่ทับช่องอื่น
create or replace function public.docs_merge(p_collection text, p_id text, p_patch jsonb)
returns void language sql security invoker set search_path = public as $$
  update public.docs set data = data || p_patch, updated_at = now()
  where collection = p_collection and id = p_id;
$$;

-- 3) อัปเดตแบบเรียลไทม์: ทุกคนเห็นนัดใหม่ทันทีโดยไม่ต้องรีเฟรช
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;

-- 4) เพิ่มสมาชิกทีม (แก้อีเมลให้ถูก แล้วเพิ่มคนอื่นได้ใน Table Editor > team_members)
insert into public.team_members (email, name) values
  ('ratthatham.pa@connexproperty.co.th', 'Max')
on conflict (email) do nothing;
