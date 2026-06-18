-- ── SCHEMA COMPATIBILITY ────────────────────────────────────────────────────
-- Safe to rerun before inserting preview data.

alter table public.profiles
  add column if not exists created_at timestamptz default now();

create table if not exists public.news_items (
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

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'news_items'
      and policyname = 'News readable by all'
  ) then
    create policy "News readable by all" on public.news_items
      for select using (true);
  end if;
end $$;

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


-- ── CLEAN EXISTING MOCK DATA ────────────────────────────────────────────────
-- Safe to rerun: this removes only the known CLC mock users/content below.

delete from public.messages
where author_id in (
  'aaaaaaaa-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000002',
  'aaaaaaaa-0000-0000-0000-000000000003',
  'aaaaaaaa-0000-0000-0000-000000000004',
  'aaaaaaaa-0000-0000-0000-000000000005'
);

delete from public.replies
where id in (
  '00000011-0000-0000-0000-000000000001',
  '00000011-0000-0000-0000-000000000002',
  '00000011-0000-0000-0000-000000000003',
  '00000011-0000-0000-0000-000000000004',
  '00000011-0000-0000-0000-000000000005',
  '00000011-0000-0000-0000-000000000006',
  '00000011-0000-0000-0000-000000000007',
  '00000011-0000-0000-0000-000000000008',
  '00000011-0000-0000-0000-000000000009'
);

delete from public.threads
where id in (
  '00000001-0000-0000-0000-000000000001',
  '00000001-0000-0000-0000-000000000002',
  '00000001-0000-0000-0000-000000000003',
  '00000002-0000-0000-0000-000000000001',
  '00000002-0000-0000-0000-000000000002',
  '00000002-0000-0000-0000-000000000003',
  '00000003-0000-0000-0000-000000000001',
  '00000003-0000-0000-0000-000000000002',
  '00000004-0000-0000-0000-000000000001',
  '00000004-0000-0000-0000-000000000002',
  '00000005-0000-0000-0000-000000000001',
  '00000005-0000-0000-0000-000000000002'
);

delete from public.news_items
where url like 'https://example.com/news/%';

delete from auth.users
where email in (
  'alice@clc.test',
  'bob@clc.test',
  'caro@clc.test',
  'julius@clc.test',
  'petra@clc.test',
  'alice.clc.seed@m4ix.com',
  'alice.seed@m4ix.com',
  'bob.seed@m4ix.com',
  'caro.seed@m4ix.com',
  'julius.seed@m4ix.com',
  'petra.seed@m4ix.com'
)
or raw_user_meta_data->>'username' in (
  'alice_type',
  'bwilde',
  'caro_m',
  'julius_r',
  'petra_k'
)
or id in (
  select id
  from public.profiles
  where username in ('alice_type', 'bwilde', 'caro_m', 'julius_r', 'petra_k')
);

delete from public.profiles
where username in ('alice_type', 'bwilde', 'caro_m', 'julius_r', 'petra_k');


-- ── MOCK USERS ──────────────────────────────────────────────────────────────
-- Insert into auth.users first (profiles are created by trigger)

insert into auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_user_meta_data, created_at, updated_at)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'alice.seed@m4ix.com',
   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
   now(), '{"username":"alice_type","bio":"Type designer. Obsessed with variable fonts and optical sizing."}', now() - interval '30 days', now()),

  ('aaaaaaaa-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'bob.seed@m4ix.com',
   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
   now(), '{"username":"bwilde","bio":"Creative technologist. Building at the intersection of brand and code."}', now() - interval '25 days', now()),

  ('aaaaaaaa-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'caro.seed@m4ix.com',
   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
   now(), '{"username":"caro_m","bio":"Motion + interaction. Previously Figma, now independent."}', now() - interval '20 days', now()),

  ('aaaaaaaa-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'julius.seed@m4ix.com',
   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
   now(), '{"username":"julius_r","bio":"Frontend engineer who thinks in design systems."}', now() - interval '15 days', now()),

  ('aaaaaaaa-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'petra.seed@m4ix.com',
   '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
   now(), '{"username":"petra_k","bio":"Generative art and creative coding. p5.js, GLSL, anything that runs."}', now() - interval '10 days', now())

on conflict (id) do nothing;

-- Profiles are created by trigger, but insert fallback in case trigger doesn't fire for manual inserts
insert into public.profiles (id, username, bio)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice_type',  'Type designer. Obsessed with variable fonts and optical sizing.'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'bwilde',      'Creative technologist. Building at the intersection of brand and code.'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'caro_m',      'Motion + interaction. Previously Figma, now independent.'),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'julius_r',    'Frontend engineer who thinks in design systems.'),
  ('aaaaaaaa-0000-0000-0000-000000000005', 'petra_k',     'Generative art and creative coding. p5.js, GLSL, anything that runs.')
on conflict (id) do nothing;


-- ── THREADS ─────────────────────────────────────────────────────────────────

insert into public.threads (id, title, body, author_id, category, pinned, views, created_at)
values

  -- DESIGN
  ('00000001-0000-0000-0000-000000000001',
   'Variable fonts in 2025 — are we finally there?',
   'I''ve been using variable fonts heavily for the past year across several brand projects. The tooling has genuinely caught up — Framer handles them well, Webflow less so, and the browser support is basically universal now. What I''m still running into: clients and their developers treating them like a novelty rather than a default. Curious what others are seeing. Are variable fonts your go-to now or still a project-by-project decision?',
   'aaaaaaaa-0000-0000-0000-000000000001', 'design', false, 142,
   now() - interval '12 days'),

  ('00000001-0000-0000-0000-000000000002',
   'How do you handle dark mode in a design system?',
   'Working on a design system for a SaaS product. We''ve been going back and forth on whether to do semantic tokens (background-primary, surface-secondary etc.) or just duplicate everything with a -dark suffix. The semantic approach feels right in principle but is a nightmare to explain to a team that just wants to ship. What approach has actually held up for you in production?',
   'aaaaaaaa-0000-0000-0000-000000000004', 'design', false, 89,
   now() - interval '8 days'),

  ('00000001-0000-0000-0000-000000000003',
   'The Figma plugin ecosystem is becoming a problem',
   'We''ve reached a point where our team has 40+ plugins installed and half of them do slightly different versions of the same thing. Plugin quality is all over the place — some crash Figma, some break on component updates, some just quietly produce wrong output. Starting to think we need an internal policy on which plugins are approved. Has anyone tackled plugin governance at a team level?',
   'aaaaaaaa-0000-0000-0000-000000000002', 'design', false, 211,
   now() - interval '5 days'),

  -- CODE
  ('00000002-0000-0000-0000-000000000001',
   'CSS container queries changed how I think about components',
   'Been migrating a component library from media queries to container queries over the past month. The shift in mental model is significant — you stop thinking about viewport and start thinking about the component''s context. Some gotchas: you can''t query the element itself, only its container, and nesting containers has some non-obvious behaviour. Writeup incoming but wanted to share the headline: I don''t think I''ll go back.',
   'aaaaaaaa-0000-0000-0000-000000000004', 'code', false, 178,
   now() - interval '9 days'),

  ('00000002-0000-0000-0000-000000000002',
   'Is vanilla JS having a moment again?',
   'Three projects in a row I''ve reached for plain JS and a build step has felt unnecessary. Not an anti-React stance — I use it when the complexity justifies it. But for marketing sites, interactive essays, even some dashboards, the overhead of a framework is genuinely more than the problem. Interested in where others draw the line these days.',
   'aaaaaaaa-0000-0000-0000-000000000003', 'code', false, 94,
   now() - interval '6 days'),

  ('00000002-0000-0000-0000-000000000003',
   'GLSL for beginners — resources that actually worked',
   'After a year of bouncing off shader tutorials that assume you already understand the maths, here are the three resources that finally made it click for me. The Book of Shaders is the obvious one but it stalled me at noise functions. What unlocked it was Inigo Quilez''s videos — specifically his SDF series — and then just reading other people''s Shadertoy code with the comments on. The comments are the key. What worked for others?',
   'aaaaaaaa-0000-0000-0000-000000000005', 'code', true, 334,
   now() - interval '14 days'),

  -- PROCESS
  ('00000003-0000-0000-0000-000000000001',
   'How do you brief a developer on a design that relies on animation?',
   'The handoff problem but specifically for motion. I''ve tried: annotated Figma prototypes, written timing specs, After Effects exports, Lottie files, and just sitting next to the developer. The last one works best but doesn''t scale. Wondering if anyone has a documentation approach that actually survives a handoff without losing all the intent.',
   'aaaaaaaa-0000-0000-0000-000000000003', 'process', false, 127,
   now() - interval '7 days'),

  ('00000003-0000-0000-0000-000000000002',
   'Running a creative technology practice inside an agency — what actually works',
   'Two years into building a creative tech offering inside a mid-size agency. The pitch is easy, the delivery is hard. The main friction: account teams treat it like production (fixed scope, fixed price) when it''s closer to R&D. The projects that have worked well have been the ones where the client bought ambiguity. The ones that failed were scoped like a banner campaign. Interested in how others structure this internally.',
   'aaaaaaaa-0000-0000-0000-000000000002', 'process', true, 289,
   now() - interval '11 days'),

  -- SHOWCASE
  ('00000004-0000-0000-0000-000000000001',
   'Generative identity system for a music label — WIP',
   'Been building a generative identity for an independent electronic music label. The mark is procedurally generated from audio analysis of each release — tempo, spectral centroid, and loudness envelope drive the form. Each release gets a unique but family-coherent visual. Written in p5.js, outputs SVG. Still working on the constraint system so it doesn''t occasionally produce something unusable. Screenshots in the thread.',
   'aaaaaaaa-0000-0000-0000-000000000005', 'showcase', false, 412,
   now() - interval '4 days'),

  ('00000004-0000-0000-0000-000000000002',
   'Built a typographic specimen tool — feedback welcome',
   'Side project: a browser tool for testing variable fonts in context. You paste in a font (or load from Google Fonts), set a text sample, and it renders a specimen across the full axis range. Axis controls are linked so you can see interpolation live. Built it because I kept doing this manually in Figma and it was slow. Open source, link in the comments.',
   'aaaaaaaa-0000-0000-0000-000000000001', 'showcase', false, 198,
   now() - interval '3 days'),

  -- GENERAL
  ('00000005-0000-0000-0000-000000000001',
   'What''s your actual daily AI workflow?',
   'Not the marketed use case — the real one. I''m using Claude for first-draft copy and for rubber-ducking architecture decisions. I''m not using it for production code because the review overhead erases the time gain for anything non-trivial. Curious whether others have found a rhythm that actually sticks versus the hype version.',
   'aaaaaaaa-0000-0000-0000-000000000002', 'general', false, 267,
   now() - interval '2 days'),

  ('00000005-0000-0000-0000-000000000002',
   'Recommend me a monitor for design + code work',
   'Current setup: 2021 MBP 14", primarily Figma, VS Code, and browser. I''ve been on the internal display only for two years which is fine but I want a second screen. The obvious answer is a Studio Display but I can''t justify the price. Looking at the LG UltraFine 27" and the Dell U2723D. Anyone running either for serious colour work?',
   'aaaaaaaa-0000-0000-0000-000000000003', 'general', false, 156,
   now() - interval '1 day')

on conflict (id) do nothing;


-- ── REPLIES ──────────────────────────────────────────────────────────────────

insert into public.replies (id, thread_id, author_id, body, created_at)
values

  -- Variable fonts thread
  ('00000011-0000-0000-0000-000000000001',
   '00000001-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002',
   'Go-to for new projects, yes. The pushback I still get is from developers who learned CSS font properties before variable fonts and find the axis syntax unfamiliar. A one-page internal reference doc fixed most of that friction for us.',
   now() - interval '11 days'),

  ('00000011-0000-0000-0000-000000000002',
   '00000001-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000004',
   'The Webflow support is genuinely still rough. Custom properties on the embed work but it''s not integrated into the style panel so non-technical editors break it constantly. Waiting for them to do it properly.',
   now() - interval '10 days'),

  ('00000011-0000-0000-0000-000000000003',
   '00000001-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   'The client framing I''ve found useful: "one font file, infinite weights and widths, faster page load." They stop seeing it as a novelty when they understand it''s also a performance argument.',
   now() - interval '9 days'),

  -- GLSL thread
  ('00000011-0000-0000-0000-000000000004',
   '00000002-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000002',
   'Completely agree on Inigo Quilez. His distance field functions article is the single most useful page I''ve bookmarked in five years of creative coding. The way he derives everything from first principles means you can actually adapt it.',
   now() - interval '13 days'),

  ('00000011-0000-0000-0000-000000000005',
   '00000002-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000003',
   'For people who learn better from video: Kishimisu on YouTube. Very approachable, doesn''t skip the maths but explains it clearly. Got me from zero to writing basic raymarchers in a weekend.',
   now() - interval '12 days'),

  -- Agency process thread
  ('00000011-0000-0000-0000-000000000006',
   '00000003-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000003',
   'The framing that helped us: we pitch it as a discovery engagement first, separate budget, separate SOW. Outcome is a proof of concept and a scoped brief for the build phase. Clients who won''t buy that usually aren''t right for the work anyway.',
   now() - interval '10 days'),

  ('00000011-0000-0000-0000-000000000007',
   '00000003-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000004',
   'We rate-card a "creative development" day rate separately from design and engineering. It sounds like a billing thing but it actually sets expectations — the client knows they''re buying exploration, not delivery.',
   now() - interval '8 days'),

  -- AI workflow thread
  ('00000011-0000-0000-0000-000000000008',
   '00000005-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000005',
   'Mine is embarrassingly low-tech: I use it to write the comment for a function before I write the function. Forces me to articulate what I''m about to do, and the implementation is usually cleaner as a result.',
   now() - interval '1 day'),

  ('00000011-0000-0000-0000-000000000009',
   '00000005-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   'For design work: generating copy variants to test with real text before the copy is written. That alone has saved a lot of layout rework. Everything else I''ve tried has felt like it''s adding a step rather than removing one.',
   now() - interval '20 hours')

on conflict (id) do nothing;


-- ── NEWS ITEMS ───────────────────────────────────────────────────────────────

insert into public.news_items (title, url, source, description, published_at, tags)
values

  ('Variable fonts are now supported across all major design tools',
   'https://example.com/news/variable-fonts-design-tools',
   'Smashing Magazine',
   'A comprehensive look at how Figma, Sketch, and Adobe XD now handle variable font axes natively, and what that means for design system workflows.',
   now() - interval '2 hours',
   array['design', 'tools']),

  ('The quiet rise of CSS @layer in production codebases',
   'https://example.com/news/css-layer-production',
   'CSS-Tricks',
   'Cascade layers have been in the spec for two years. Teams are quietly adopting them to manage specificity at scale — here''s what that looks like in a real codebase.',
   now() - interval '5 hours',
   array['code']),

  ('Anthropic releases Claude for API developers — what changed',
   'https://example.com/news/anthropic-claude-api',
   'The Verge',
   'Anthropic has updated its API offering with new context window sizes and a revised pricing model. Early reaction from developers is cautiously positive.',
   now() - interval '8 hours',
   array['ai', 'tools']),

  ('Figma''s new Dev Mode goes GA — designer and developer reactions',
   'https://example.com/news/figma-dev-mode-ga',
   'It''s Nice That',
   'Dev Mode has exited beta. Designers broadly welcome the separation of concerns; developers are more divided on whether it solves the handoff problem or just formalises it.',
   now() - interval '12 hours',
   array['design', 'tools']),

  ('How Stripe redesigned its documentation',
   'https://example.com/news/stripe-docs-redesign',
   'Sidebar',
   'Stripe''s documentation has long been a benchmark. Their design team walks through the decisions behind the latest version — hierarchy, code samples, and the role of search.',
   now() - interval '1 day',
   array['design', 'code']),

  ('Stable Diffusion 3 — what the open source community is actually saying',
   'https://example.com/news/stable-diffusion-3-community',
   'Hacker News',
   'Practitioners are weighing in on the licence change and the model''s real-world performance. The consensus is more nuanced than the launch coverage suggested.',
   now() - interval '1 day' + interval '3 hours',
   array['ai']),

  ('Motion design for interfaces: the principles that hold',
   'https://example.com/news/motion-design-interfaces',
   'Smashing Magazine',
   'A long read on which motion design principles have survived the transition from After Effects to CSS and JavaScript — and which ones need revisiting.',
   now() - interval '2 days',
   array['design', 'code']),

  ('Open source DTCG token tooling roundup 2025',
   'https://example.com/news/dtcg-token-tooling',
   'Sidebar',
   'The Design Token Community Group spec has been stable for a year. This roundup covers the tooling ecosystem — what''s ready for production and what''s still sharp around the edges.',
   now() - interval '2 days' + interval '6 hours',
   array['design', 'tools']),

  ('WebGPU is shipping — what it means for creative coders',
   'https://example.com/news/webgpu-creative-coding',
   'The Verge',
   'WebGPU is now available in Chrome and Safari. For creative coders who have been limited by WebGL, the new API opens up compute shaders and a significantly less hostile API surface.',
   now() - interval '3 days',
   array['code', 'tools']),

  ('The independent designer''s toolkit in 2025',
   'https://example.com/news/independent-designer-toolkit',
   'It''s Nice That',
   'A survey of 200 independent designers on what they''re actually using. The results are less Figma-dominant than expected, with a notable cluster around more code-adjacent tools.',
   now() - interval '3 days' + interval '4 hours',
   array['design', 'tools']),

  ('p5.js 2.0 — what''s new and why it matters',
   'https://example.com/news/p5js-2-release',
   'Hacker News',
   'The first major version of p5.js in several years ships with a modernised API, better TypeScript support, and a renderer rewrite that unblocks WebGL improvements.',
   now() - interval '4 days',
   array['code', 'tools']),

  ('Generative brand systems: three case studies',
   'https://example.com/news/generative-brand-systems',
   'It''s Nice That',
   'Three studios share how they built identity systems that generate rather than specify. The technical approaches differ; the client conversation challenges are remarkably consistent.',
   now() - interval '4 days' + interval '2 hours',
   array['design', 'ai']),

  ('Why semantic HTML is the most underrated performance optimisation',
   'https://example.com/news/semantic-html-performance',
   'Smashing Magazine',
   'A deep dive into how correct HTML structure reduces layout thrashing, improves accessibility tree construction, and cuts JavaScript payload. None of this is new — it just keeps getting ignored.',
   now() - interval '5 days',
   array['code']),

  ('Adobe Firefly integration in Creative Cloud — six months in',
   'https://example.com/news/adobe-firefly-six-months',
   'The Verge',
   'Creative professionals reflect on how generative fill and generative expand have changed — or not changed — their actual workflows. The picture is more mixed than either the hype or the backlash.',
   now() - interval '5 days' + interval '7 hours',
   array['ai', 'tools']),

  ('Type design in the variable font era — a conversation with three foundries',
   'https://example.com/news/type-design-variable-fonts',
   'Sidebar',
   'Three independent foundries on how variable font production has changed their process, pricing, and relationship with clients. The economics are still being worked out.',
   now() - interval '6 days',
   array['design'])

on conflict (url) do nothing;
