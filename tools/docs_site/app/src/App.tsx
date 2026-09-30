import { useEffect, useMemo, useState } from 'react'
import ReactMarkdown from 'react-markdown'
import modulesData from './data/modules.json'
import { parseHash, toHash } from './types'
import type { ApiModule, Guide, NativeEntry, Route } from './types'

const modules = modulesData as ApiModule[]

interface Stats { modules: number; functions: number; guides: number; natives: number }
interface GuideIndex { id: string; title: string }

const modByTable: Record<string, ApiModule> = {}
for (const m of modules) for (const t of m.tables) modByTable[t] ??= m

async function getJSON<T>(url: string): Promise<T> {
  const r = await fetch(url)
  if (!r.ok) throw new Error(url)
  return r.json() as Promise<T>
}

function useRoute(): [Route, (r: Route) => void] {
  const [route, setRoute] = useState<Route>(parseHash)
  useEffect(() => {
    const onChange = () => {
      setRoute(parseHash())
      window.scrollTo(0, 0)
    }
    window.addEventListener('hashchange', onChange)
    return () => window.removeEventListener('hashchange', onChange)
  }, [])
  return [route, (r) => { window.location.hash = toHash(r) }]
}

function firstLine(s: string): string {
  const line = s.split('\n').find((l) => l.trim().length > 0) ?? ''
  return line.length > 120 ? line.slice(0, 120) + '…' : line
}

function Sidebar({ route, go, query, setQuery, guides, nativesCount }: {
  route: Route
  go: (r: Route) => void
  query: string
  setQuery: (q: string) => void
  guides: GuideIndex[]
  nativesCount: number
}) {
  const q = query.trim().toLowerCase()
  const modList = useMemo(() => {
    if (!q) return modules
    return modules.filter(
      (m) =>
        m.tables.some((t) => t.toLowerCase().includes(q)) ||
        m.file.toLowerCase().includes(q) ||
        m.functions.some((f) => `${f.mod}.${f.name}`.toLowerCase().includes(q)),
    )
  }, [q])
  const guideList = useMemo(() => {
    if (!q) return guides
    return guides.filter(
      (g) => g.title.toLowerCase().includes(q) || g.id.toLowerCase().includes(q),
    )
  }, [q, guides])

  return (
    <aside className="sidebar">
      <div className="brand" onClick={() => { setQuery(''); go({ view: 'home' }) }}>
        <h1>⚔ Cossacks 3 Modloader</h1>
        <p>Lua API · {modules.length} модулей · {nativesCount} нативов</p>
      </div>
      <div className="search">
        <input
          placeholder="Поиск: camera, minimap, spawn…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>
      <nav className="nav">
        <div className="nav-section">Разделы</div>
        <a className={`nav-link${route.view === 'natives' ? ' active' : ''}`}
           onClick={() => go({ view: 'natives' })}>
          🗂 Каталог нативов <span className="nav-count">{nativesCount}</span>
        </a>
        <div className="nav-section">Lua-модули <span className="nav-count">{modList.length}</span></div>
        {modList.map((m) => {
          const name = m.tables[0] ?? m.file
          const active = route.view === 'module' && route.name === name
          return (
            <a key={m.file} className={`nav-link${active ? ' active' : ''}`}
               onClick={() => go({ view: 'module', name })} title={m.file}>
              {name}<span className="file">{m.file.replace('.lua', '')}</span>
            </a>
          )
        })}
        <div className="nav-section">Гайды <span className="nav-count">{guideList.length}</span></div>
        {guideList.map((g) => (
          <a key={g.id}
             className={`nav-link${route.view === 'guide' && route.id === g.id ? ' active' : ''}`}
             onClick={() => go({ view: 'guide', id: g.id })}>
            {g.id}
          </a>
        ))}
      </nav>
    </aside>
  )
}

function Home({ go, guides, stats }: {
  go: (r: Route) => void
  guides: GuideIndex[]
  stats: Stats | null
}) {
  return (
    <div>
      <h1>Документация модлоадера</h1>
      <p className="subtitle">
        Lua 5.4 · события игры · CEF-интерфейсы · замена файлов · сеть. Если функции нет здесь — её нет.
      </p>
      <div className="stat-row">
        <div className="stat"><b>{stats?.modules ?? modules.length}</b>модулей</div>
        <div className="stat"><b>{stats?.functions ?? '…'}</b>функций</div>
        <div className="stat"><b>{stats?.natives ?? '…'}</b>нативов</div>
        <div className="stat"><b>{guides.length || stats?.guides || '…'}</b>гайдов</div>
      </div>
      <h2>Популярное</h2>
      <div className="cards">
        {['camera', 'minimap', 'orders', 'weapon', 'abilities', 'world', 'scenario', 'steam'].map((t) => {
          const m = modByTable[t]
          if (!m) return null
          return (
            <a key={t} className="card" onClick={() => go({ view: 'module', name: t })}>
              <h3>{t}</h3>
              <p>{firstLine(m.header)}</p>
            </a>
          )
        })}
      </div>
      <h2>Гайды</h2>
      <div className="cards">
        {guides.map((g) => (
          <a key={g.id} className="card" onClick={() => go({ view: 'guide', id: g.id })}>
            <h3>{g.id}</h3>
            <p>{firstLine(g.title)}</p>
          </a>
        ))}
      </div>
    </div>
  )
}

function ModulePage({ name }: { name: string }) {
  const m = modByTable[name]
  if (!m) return <div><h1>Нет такого модуля: {name}</h1></div>
  return (
    <div>
      <h1>{m.tables.join(' · ')}</h1>
      <p className="subtitle">{m.file} · функций: {m.functions.length}</p>
      {m.header && (
        <div className="md"><ReactMarkdown>{m.header}</ReactMarkdown></div>
      )}
      <h2>Функции</h2>
      {m.functions.map((f) => (
        <div className="fn" key={`${f.mod}.${f.name}`} id={`${f.mod}.${f.name}`}>
          <div className="fn-sig">
            <a className="fn-anchor" href={`#/module/${name}`}>#</a>
            <span className="fn-mod">{f.mod}.</span>
            <span className="fn-name">{f.name}</span>
            <span className="fn-args">({f.args})</span>
          </div>
          {f.doc && <div className="fn-doc">{f.doc}</div>}
        </div>
      ))}
      {m.functions.length === 0 && <p>Функции определяются динамически — смотрите шапку выше.</p>}
    </div>
  )
}

function GuidePage({ id }: { id: string }) {
  const [guide, setGuide] = useState<Guide | null>(null)
  useEffect(() => {
    let live = true
    getJSON<Guide[]>('data/guides.json').then((all) => {
      if (live) setGuide(all.find((x) => x.id === id) ?? null)
    }).catch(() => { if (live) setGuide(null) })
    return () => { live = false }
  }, [id])
  if (guide === null) return <div><p className="subtitle">Загрузка…</p></div>
  if (!guide) return <div><h1>Нет такого гайда: {id}</h1></div>
  return (
    <div>
      <h1>{guide.title}</h1>
      <p className="subtitle">{guide.id}.md</p>
      <div className="md"><ReactMarkdown>{guide.md}</ReactMarkdown></div>
    </div>
  )
}

const PAGE = 100

function NativesPage() {
  const [data, setData] = useState<NativeEntry[] | null>(null)
  const [q, setQ] = useState('')
  const [side, setSide] = useState<'all' | 'client' | 'server'>('all')
  const [risk, setRisk] = useState('all')
  const [cat, setCat] = useState('all')
  const [page, setPage] = useState(0)

  useEffect(() => {
    let live = true
    getJSON<NativeEntry[]>('data/natives.json').then((d) => { if (live) setData(d) }).catch(() => {})
    return () => { live = false }
  }, [])

  const cats = useMemo(() => (data ? [...new Set(data.map((n) => n.c))].sort() : []), [data])
  const filtered = useMemo(() => {
    if (!data) return []
    const needle = q.trim().toLowerCase()
    return data.filter(
      (n) =>
        (side === 'all' || n.s === side) &&
        (risk === 'all' || n.r === risk) &&
        (cat === 'all' || n.c === cat) &&
        (!needle || n.n.toLowerCase().includes(needle) || n.d.toLowerCase().includes(needle)),
    )
  }, [data, q, side, risk, cat])

  useEffect(() => setPage(0), [q, side, risk, cat])
  const pages = Math.max(1, Math.ceil(filtered.length / PAGE))
  const rows = filtered.slice(page * PAGE, page * PAGE + PAGE)

  return (
    <div>
      <h1>Каталог нативов</h1>
      <p className="subtitle">
        Все {data?.length ?? '…'} функций движка. Сторона и риск — зеркало <code>IsClientNative</code>.
      </p>
      {!data && <p className="subtitle">Загрузка каталога…</p>}
      <div className="filters">
        <input placeholder="Фильтр по имени…" value={q} onChange={(e) => setQ(e.target.value)} />
        <select value={side} onChange={(e) => setSide(e.target.value as never)}>
          <option value="all">сторона: все</option>
          <option value="client">client</option>
          <option value="server">server-only</option>
        </select>
        <select value={risk} onChange={(e) => setRisk(e.target.value)}>
          <option value="all">риск: все</option>
          <option value="read">read</option>
          <option value="visual">visual</option>
          <option value="world">world</option>
          <option value="forbidden">forbidden</option>
        </select>
        <select value={cat} onChange={(e) => setCat(e.target.value)}>
          <option value="all">категория: все</option>
          {cats.map((c) => <option key={c} value={c}>{c}</option>)}
        </select>
      </div>
      <div className="pager">
        <button disabled={page === 0} onClick={() => setPage(page - 1)}>←</button>
        <span>стр. {page + 1} / {pages} · найдено {filtered.length}</span>
        <button disabled={page + 1 >= pages} onClick={() => setPage(page + 1)}>→</button>
      </div>
      <table className="ntable">
        <thead><tr><th>Имя</th><th>Сторона / риск</th><th>Сигнатура</th></tr></thead>
        <tbody>
          {rows.map((n) => (
            <tr key={n.n}>
              <td>
                <code>{n.n}</code>
                <div className="decl">{n.a}{n.w ? ` · → ${n.w}` : ''}</div>
              </td>
              <td style={{ whiteSpace: 'nowrap' }}>
                <span className={`badge ${n.s}`}>{n.s}</span>
                <span className={`badge ${n.r}`}>{n.r}</span>
                <div className="decl">{n.c}</div>
              </td>
              <td className="decl">{n.d}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default function App() {
  const [route, go] = useRoute()
  const [query, setQuery] = useState('')
  const [guides, setGuides] = useState<GuideIndex[]>([])
  const [stats, setStats] = useState<Stats | null>(null)

  useEffect(() => {
    getJSON<GuideIndex[]>('data/guides_index.json').then(setGuides).catch(() => {})
    getJSON<Stats>('data/stats.json').then(setStats).catch(() => {})
  }, [])

  return (
    <div className="layout">
      <Sidebar route={route} go={go} query={query} setQuery={setQuery}
               guides={guides} nativesCount={stats?.natives ?? 0} />
      <main className="content">
        {route.view === 'home' && <Home go={go} guides={guides} stats={stats} />}
        {route.view === 'module' && <ModulePage name={route.name} />}
        {route.view === 'guide' && <GuidePage id={route.id} />}
        {route.view === 'natives' && <NativesPage />}
      </main>
    </div>
  )
}
