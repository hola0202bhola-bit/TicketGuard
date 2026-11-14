create schema if not exists ticketguard_private;
revoke all on schema ticketguard_private from public;

create table public.tickets (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users(id) on delete restrict,
  notification_id integer generated always as identity unique,
  product text not null check (char_length(btrim(product)) between 1 and 100),
  store text not null check (char_length(btrim(store)) between 1 and 100),
  purchased_on date not null check (purchased_on >= date '1900-01-01'),
  amount_cents integer not null check (amount_cents between 1 and 999999999),
  warranty_until date check (
    warranty_until >= purchased_on and warranty_until <= date '2199-12-31'
  ),
  lead_days smallint check (lead_days in (1, 7) and warranty_until is not null),
  status text not null default 'pending'
    check (status in ('pending', 'ready', 'deleting')),
  created_at timestamptz not null default now()
);

create index tickets_owner_notification on public.tickets (user_id, notification_id);

alter table public.tickets enable row level security;
revoke all on table public.tickets from public, anon, authenticated;

grant select, delete on table public.tickets to authenticated;
grant insert (id, user_id, product, store, purchased_on, amount_cents, warranty_until, lead_days)
  on table public.tickets to authenticated;
grant update (product, store, purchased_on, amount_cents, warranty_until, lead_days, status)
  on table public.tickets to authenticated;

create policy ticket_read on public.tickets for select to authenticated
  using (user_id = (select auth.uid()));

create policy ticket_create on public.tickets for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'pending');

create policy ticket_update on public.tickets for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy ticket_delete on public.tickets for delete to authenticated
  using (user_id = (select auth.uid()) and status = 'deleting');

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('receipt-images', 'receipt-images', false, 5242880, array['image/jpeg']);

create policy receipt_read on storage.objects for select to authenticated
  using (
    bucket_id = 'receipt-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.tickets t
      where t.user_id = (select auth.uid()) and storage.filename(name) = t.id || '.jpg'
        and name = t.user_id || '/' || t.id || '.jpg'
    )
  );

create policy receipt_create on storage.objects for insert to authenticated
  with check (
    bucket_id = 'receipt-images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.tickets t
      where t.user_id = (select auth.uid())
        and name = t.user_id || '/' || t.id || '.jpg' and t.status = 'pending'
    )
  );

create policy receipt_retry on storage.objects for update to authenticated
  using (
    bucket_id = 'receipt-images'
    and exists (
      select 1 from public.tickets t
      where t.user_id = (select auth.uid())
        and name = t.user_id || '/' || t.id || '.jpg' and t.status = 'pending'
    )
  )
  with check (
    bucket_id = 'receipt-images'
    and exists (
      select 1 from public.tickets t
      where t.user_id = (select auth.uid())
        and name = t.user_id || '/' || t.id || '.jpg' and t.status = 'pending'
    )
  );

create policy receipt_delete on storage.objects for delete to authenticated
  using (
    bucket_id = 'receipt-images'
    and exists (
      select 1 from public.tickets t
      where t.user_id = (select auth.uid())
        and name = t.user_id || '/' || t.id || '.jpg' and t.status = 'deleting'
    )
  );

create function ticketguard_private.check_ticket()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if exists (
      select 1 from storage.objects o
      where o.bucket_id = 'receipt-images' and o.name = old.user_id || '/' || old.id || '.jpg'
    ) then
      raise exception 'Retira primero el comprobante' using errcode = '23514';
    end if;
    return old;
  end if;

  if new.purchased_on > (now() at time zone 'UTC')::date + 1 then
    raise exception 'La compra es futura' using errcode = '23514';
  end if;

  if tg_op = 'UPDATE' then
    if (old.status = 'deleting' and new.status <> 'deleting')
      or (old.status = 'ready' and new.status = 'pending') then
      raise exception 'Transición de ticket inválida' using errcode = '23514';
    end if;

    if old.status = 'pending' and new.status = 'ready' and not exists (
      select 1 from storage.objects o
      where o.bucket_id = 'receipt-images' and o.name = new.user_id || '/' || new.id || '.jpg'
    ) then
      raise exception 'Falta el comprobante' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function ticketguard_private.check_ticket() from public, anon, authenticated;

create trigger validate_ticket
before insert or update or delete on public.tickets
for each row execute function ticketguard_private.check_ticket();
