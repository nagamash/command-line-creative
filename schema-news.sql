create table public.news_items (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  url text not null,
  source text not null,
  description text,
  image_url text,
  published_at timestamptz default now(),
  tags text[] default '{}',
  created_at timestamptz default now(),
  constraint news_items_url_key unique (url)
);

alter table public.news_items enable row level security;

create policy "News readable by all" on public.news_items
  for select using (true);

create or replace function public.trim_news_items()
returns void as $$
begin
  delete from public.news_items
  where id not in (
    select id from public.news_items
    order by published_at desc
    limit 200
  );
end;
$$ language plpgsql security definer;
