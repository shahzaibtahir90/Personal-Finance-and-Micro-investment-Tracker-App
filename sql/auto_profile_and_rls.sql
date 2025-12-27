-- Auto-create profile trigger + recommended RLS policies
-- Run this in the Supabase SQL editor (adjust schema if needed).

-- 1) Function: create profile row when auth user is created
create or replace function public.handle_new_auth_user()
returns trigger as $$
begin
  -- Insert into users table (if not exists)
  insert into public.users (id, email, name, role, created_at)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', new.email),
    case
      when (new.raw_user_meta_data->>'is_consultant')::boolean is true then 'Consultant'
      else 'User'
    end,
    now()
  )
  on conflict (id) do nothing;

  -- If the user registered as a consultant, also populate consultants
  if (new.raw_user_meta_data->>'is_consultant')::boolean is true then
    insert into public.consultants (id, email, name, specialization, created_at)
    values (
      new.id,
      new.email,
      coalesce(new.raw_user_meta_data->>'name', new.email),
      coalesce(new.raw_user_meta_data->>'specialization', 'General'),
      now()
    )
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$ language plpgsql security definer;

-- 2) Trigger: call the function after auth user creation
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_auth_user();

-- 3) Enable RLS on data tables (do this if not already enabled)
alter table if exists public.transactions enable row level security;
alter table if exists public.expenses enable row level security;
alter table if exists public.investments enable row level security;
alter table if exists public.consultations enable row level security;
alter table if exists public.users enable row level security;
alter table if exists public.consultants enable row level security;

-- 4) Recommended RLS policies (use clear names without spaces)
-- Transactions policy
drop policy if exists transactions_manage_own on public.transactions;
create policy transactions_manage_own on public.transactions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Expenses policy
drop policy if exists expenses_manage_own on public.expenses;
create policy expenses_manage_own on public.expenses
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Investments policy
drop policy if exists investments_manage_own on public.investments;
create policy investments_manage_own on public.investments
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Consultations policy (user or consultant can act on a consultation row)
drop policy if exists consultations_user_consultant on public.consultations;
create policy consultations_user_consultant on public.consultations
  for all
  using (auth.uid() = user_id OR auth.uid() = consultant_id)
  with check (auth.uid() = user_id OR auth.uid() = consultant_id);

-- Users table: allow users to select/update their own profile
drop policy if exists users_select_own on public.users;
create policy users_select_own on public.users
  for select
  using (auth.uid() = id);

drop policy if exists users_update_own on public.users;
create policy users_update_own on public.users
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Consultants table: allow consultants to select/update their own profile
drop policy if exists consultants_select_own on public.consultants;
create policy consultants_select_own on public.consultants
  for select
  using (auth.uid() = id);

drop policy if exists consultants_update_own on public.consultants;
create policy consultants_update_own on public.consultants
  for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- End of file
