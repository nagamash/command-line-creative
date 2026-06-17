create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  bio text default '',
  created_at timestamptz default now()
);

create table public.threads (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  body text not null,
  author_id uuid references public.profiles(id),
  category text not null,
  pinned boolean default false,
  views integer default 0,
  created_at timestamptz default now()
);

create table public.replies (
  id uuid default gen_random_uuid() primary key,
  thread_id uuid references public.threads(id) on delete cascade not null,
  author_id uuid references public.profiles(id),
  body text not null,
  created_at timestamptz default now()
);

create table public.messages (
  id uuid default gen_random_uuid() primary key,
  room text not null,
  author_id uuid references public.profiles(id),
  body text not null,
  created_at timestamptz default now()
);

create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username, bio)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', 'user_' || substr(new.id::text, 1, 8)),
    coalesce(new.raw_user_meta_data->>'bio', '')
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.threads  enable row level security;
alter table public.replies  enable row level security;
alter table public.messages enable row level security;

create policy "Profiles readable" on public.profiles
  for select using (true);
create policy "Users insert own profile" on public.profiles
  for insert with check (auth.uid() = id);
create policy "Users update own profile" on public.profiles
  for update using (auth.uid() = id);

create policy "Threads readable" on public.threads
  for select using (true);
create policy "Auth users create threads" on public.threads
  for insert with check (auth.uid() = author_id);
create policy "Anyone update thread views" on public.threads
  for update using (true);

create policy "Replies readable" on public.replies
  for select using (true);
create policy "Auth users create replies" on public.replies
  for insert with check (auth.uid() = author_id);

create policy "Auth users read messages" on public.messages
  for select using (auth.uid() is not null);
create policy "Auth users send messages" on public.messages
  for insert with check (auth.uid() = author_id);

alter publication supabase_realtime add table public.messages;
