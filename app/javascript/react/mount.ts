import { createRoot, type Root } from "react-dom/client"
import { createElement } from "react"
import { CombatPanel } from "./CombatPanel"
import type { CombatStateData } from "../domain/combatState"

// 初期データは data 属性で受け取る。script タグへJSONを埋める方式と違い、
// Railsが属性値を自動でエスケープするため html_safe を使わずに済む
function readCombatState(element: HTMLElement): CombatStateData | null {
  const raw = element.dataset.combatState
  if (raw === undefined || raw === "") return null

  try {
    return JSON.parse(raw) as CombatStateData
  } catch (error) {
    console.error("戦闘状態の初期データを解析できませんでした", error)
    return null
  }
}

const roots = new Map<Element, Root>()

// `data-react-root` を持つ要素すべてにマウントし、新しくマウントした数を返す。
// 既にマウント済みの要素は飛ばすため、同じページで複数回呼ばれても二重描画にならない。
export function mountAll(): number {
  releaseDetachedRoots()

  let mounted = 0

  document.querySelectorAll<HTMLElement>("[data-react-root]").forEach((element) => {
    if (roots.has(element)) return

    const data = readCombatState(element)
    const root = createRoot(element)
    roots.set(element, root)
    // 初期データが無ければマウントだけして何も描画しない
    root.render(data === null ? null : createElement(CombatPanel, { data }))
    mounted += 1
  })

  return mounted
}

// DOMから外れた要素のRootを解放する。
// unmountAll は turbo:before-cache に紐づいているが、このイベントは
// ページがキャッシュ可能なときにしか発火しない。turbo-cache-control: no-cache の
// ページや、Turbo Streamがマウント先を含む領域を差し替えた場合には呼ばれないため、
// ここで取りこぼしを回収しないとRootと要素が解放されずに残り続ける。
function releaseDetachedRoots(): void {
  roots.forEach((root, element) => {
    if (element.isConnected) return

    root.unmount()
    roots.delete(element)
  })
}

// Turbo Drive はページを離れる前にDOMのスナップショットを取ってキャッシュする。
// Reactが描画した内容を含んだまま保存されると、戻ってきた時に
// 「キャッシュされたDOM」と「再マウントしたReact」が二重に存在してしまうため、
// キャッシュされる前に必ず巻き戻す。
export function unmountAll(): void {
  roots.forEach((root) => root.unmount())
  roots.clear()
}

export function startReact(): void {
  document.addEventListener("turbo:load", () => mountAll())
  document.addEventListener("turbo:before-cache", unmountAll)
}
