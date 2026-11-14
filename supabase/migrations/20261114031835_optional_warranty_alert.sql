alter table public.tickets
  drop constraint tickets_check1,
  add constraint ticket_reminder_requires_warranty
    check (lead_days is null or (lead_days in (1, 7) and warranty_until is not null));
