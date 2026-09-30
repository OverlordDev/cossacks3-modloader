export interface ApiFunction {
  mod: string
  name: string
  args: string
  doc: string
}

export interface ApiModule {
  file: string
  header: string
  tables: string[]
  functions: ApiFunction[]
}

export interface Guide {
  id: string
  title: string
  md: string
}

export interface NativeEntry {
  n: string
  a: string
  d: string
  s: 'client' | 'server'
  r: 'read' | 'visual' | 'world' | 'forbidden'
  c: string
  w: string
}

export type Route =
  | { view: 'home' }
  | { view: 'module'; name: string }
  | { view: 'guide'; id: string }
  | { view: 'natives' }

export function parseHash(): Route {
  const h = window.location.hash.replace(/^#\/?/, '')
  const [head, ...rest] = h.split('/')
  if (head === 'module' && rest[0]) return { view: 'module', name: decodeURIComponent(rest[0]) }
  if (head === 'guide' && rest[0]) return { view: 'guide', id: decodeURIComponent(rest[0]) }
  if (head === 'natives') return { view: 'natives' }
  return { view: 'home' }
}

export function toHash(r: Route): string {
  if (r.view === 'module') return `#/module/${encodeURIComponent(r.name)}`
  if (r.view === 'guide') return `#/guide/${encodeURIComponent(r.id)}`
  if (r.view === 'natives') return '#/natives'
  return '#/'
}
