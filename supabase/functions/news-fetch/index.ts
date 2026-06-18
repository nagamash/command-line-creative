import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

const KEYWORDS = ['design','creative','generative','ai','ux','interface','typography','tool','open source','frontend','css','animation','brand','visual','code','figma','motion','color'];

const DESIGN_WORDS  = ['design','typography','brand','visual','ui','ux','interface','layout','color','figma','motion'];
const CODE_WORDS    = ['code','javascript','css','frontend','developer','github','open source','api'];
const AI_WORDS      = ['ai','artificial intelligence','generative','llm','machine learning','stable diffusion','midjourney','claude','gpt'];
const TOOLS_WORDS   = ['tool','plugin','app','software','release','launch'];

function autoTags(text: string): string[] {
  const t = text.toLowerCase();
  const tags: string[] = [];
  if (DESIGN_WORDS.some(w => t.includes(w))) tags.push('design');
  if (CODE_WORDS.some(w => t.includes(w)))   tags.push('code');
  if (AI_WORDS.some(w => t.includes(w)))     tags.push('ai');
  if (TOOLS_WORDS.some(w => t.includes(w)))  tags.push('tools');
  return tags;
}

function relevant(title: string, desc: string): boolean {
  const t = (title + ' ' + desc).toLowerCase();
  return KEYWORDS.some(k => t.includes(k));
}

interface NewsItem {
  title: string;
  url: string;
  source: string;
  description: string | null;
  image_url: string | null;
  published_at: string;
  tags: string[];
}

async function fetchHN(query: string): Promise<NewsItem[]> {
  const url = `https://hn.algolia.com/api/v1/search_by_date?query=${encodeURIComponent(query)}&tags=story&hitsPerPage=10&numericFilters=points>10`;
  const res = await fetch(url);
  const data = await res.json();
  return (data.hits || []).filter((h: any) => h.url && relevant(h.title, '')).map((h: any) => ({
    title: h.title,
    url: h.url,
    source: 'Hacker News',
    description: null,
    image_url: null,
    published_at: h.created_at,
    tags: autoTags(h.title),
  }));
}

async function fetchRSS(feedUrl: string, sourceName: string): Promise<NewsItem[]> {
  const res = await fetch(feedUrl, { headers: { 'User-Agent': 'CLC-NewsFetcher/1.0' } });
  const xml = await res.text();
  const doc = new DOMParser().parseFromString(xml, 'text/xml');
  const items = [...doc.querySelectorAll('item'), ...doc.querySelectorAll('entry')];
  const results: NewsItem[] = [];
  for (const item of items.slice(0, 20)) {
    const title = item.querySelector('title')?.textContent?.trim() || '';
    const link  = item.querySelector('link')?.getAttribute('href') || item.querySelector('link')?.textContent?.trim() || '';
    const desc  = item.querySelector('description, summary, content')?.textContent?.trim() || '';
    const pubRaw = item.querySelector('pubDate, published, updated')?.textContent?.trim() || '';
    const pub   = pubRaw ? new Date(pubRaw).toISOString() : new Date().toISOString();
    const imgEl = item.querySelector('enclosure[type^="image"], media\\:thumbnail, media\\:content');
    const image_url = imgEl?.getAttribute('url') || null;
    if (!title || !link) continue;
    if (!relevant(title, desc)) continue;
    results.push({
      title,
      url: link,
      source: sourceName,
      description: desc.replace(/<[^>]*>/g, '').slice(0, 300) || null,
      image_url,
      published_at: pub,
      tags: autoTags(title + ' ' + desc),
    });
  }
  return results;
}

Deno.serve(async () => {
  const all: NewsItem[] = [];

  const [hn1, hn2, hn3, hn4, verge, smashing, int_nice, sidebar] = await Promise.allSettled([
    fetchHN('creative technology'),
    fetchHN('generative AI art'),
    fetchHN('design tool'),
    fetchHN('frontend development'),
    fetchRSS('https://www.theverge.com/rss/index.xml', 'The Verge'),
    fetchRSS('https://www.smashingmagazine.com/feed/', 'Smashing Magazine'),
    fetchRSS('https://www.itsnicethat.com/rss', "It's Nice That"),
    fetchRSS('https://sidebar.io/feed.xml', 'Sidebar'),
  ]);

  for (const r of [hn1, hn2, hn3, hn4, verge, smashing, int_nice, sidebar]) {
    if (r.status === 'fulfilled') all.push(...r.value);
  }

  const seen = new Set<string>();
  const unique = all.filter(item => {
    if (seen.has(item.url)) return false;
    seen.add(item.url);
    return true;
  });

  if (unique.length) {
    await sb.from('news_items').upsert(unique, { onConflict: 'url', ignoreDuplicates: true });
  }

  await sb.rpc('trim_news_items');

  return new Response(JSON.stringify({ inserted: unique.length }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
