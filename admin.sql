-- Team Jahja: ระบบจัดการสมาชิกในเว็บ (รันครั้งเดียวใน Supabase > SQL Editor)
-- แอดมินเพิ่ม/ลบ/รีเซ็ตรหัสสมาชิกได้จากปุ่ม "จัดการสมาชิก" ในเว็บ

alter table public.team_members add column if not exists is_admin boolean not null default false;
update public.team_members set is_admin = true
  where email in ('admin@pmjj.team', 'max@pmjj.team', 'ratthatham.pa@connexproperty.co.th');

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.team_members
                 where lower(email) = lower(coalesce(auth.jwt() ->> 'email','')) and is_admin);
$$;

create or replace function public._jj_email(p_user text) returns text
language sql immutable as $$
  select case when position('@' in p_user) > 0 then lower(trim(p_user))
              else lower(trim(p_user)) || '@pmjj.team' end;
$$;

-- รายชื่อสมาชิก
create or replace function public.admin_list_members()
returns table (username text, email text, name text, is_admin boolean, last_sign_in timestamptz)
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  return query
    select case when m.email like '%@pmjj.team' then split_part(m.email,'@',1) else m.email end,
           m.email, m.name, m.is_admin, u.last_sign_in_at
    from public.team_members m left join auth.users u on lower(u.email) = lower(m.email)
    order by m.is_admin desc, m.name;
end $$;

-- เพิ่มสมาชิก (ถ้ามีบัญชีอยู่แล้วจะตั้งรหัสใหม่และให้สิทธิ์)
create or replace function public.admin_add_member(p_user text, p_name text, p_password text, p_admin boolean default false)
returns void language plpgsql security definer set search_path = public, auth, extensions as $$
declare e text := public._jj_email(p_user); uid uuid;
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  if coalesce(trim(p_user),'') = '' or e !~ '^[a-z0-9._-]+@[a-z0-9.-]+$' then raise exception 'bad_username'; end if;
  if length(coalesce(p_password,'')) < 6 then raise exception 'short_password'; end if;
  select id into uid from auth.users where lower(email) = e;
  if uid is null then
    uid := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', e,
      extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), uid, uid::text,
      jsonb_build_object('sub', uid::text, 'email', e, 'email_verified', true), 'email', now(), now(), now());
  else
    update auth.users set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
      email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now() where id = uid;
  end if;
  insert into public.team_members (email, name, is_admin)
  values (e, coalesce(nullif(trim(p_name),''), split_part(e,'@',1)), coalesce(p_admin,false))
  on conflict (email) do update set name = excluded.name, is_admin = excluded.is_admin;
end $$;

-- รีเซ็ตรหัสผ่าน
create or replace function public.admin_set_password(p_user text, p_password text)
returns void language plpgsql security definer set search_path = public, auth, extensions as $$
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  if length(coalesce(p_password,'')) < 6 then raise exception 'short_password'; end if;
  update auth.users set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')), updated_at = now()
  where lower(email) = public._jj_email(p_user);
  if not found then raise exception 'no_user'; end if;
end $$;

-- ลบสมาชิก (ลบสิทธิ์และบัญชีล็อกอิน นัดที่เคยลงไว้ยังอยู่ครบ)
create or replace function public.admin_remove_member(p_user text)
returns void language plpgsql security definer set search_path = public, auth as $$
declare e text := public._jj_email(p_user);
begin
  if not public.is_admin() then raise exception 'not_admin'; end if;
  if e = lower(coalesce(auth.jwt() ->> 'email','')) then raise exception 'cannot_remove_self'; end if;
  delete from public.team_members where lower(email) = e;
  delete from auth.users where lower(email) = e;
end $$;

revoke all on function public.admin_list_members(), public.admin_add_member(text,text,text,boolean),
  public.admin_set_password(text,text), public.admin_remove_member(text) from public, anon;
grant execute on function public.admin_list_members(), public.admin_add_member(text,text,text,boolean),
  public.admin_set_password(text,text), public.admin_remove_member(text), public.is_admin() to authenticated;
