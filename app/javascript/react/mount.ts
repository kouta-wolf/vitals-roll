import { createRoot, type Root } from "react-dom/client"
import { createElement } from "react"
import { CombatPanel } from "./CombatPanel"

const roots = new Map<Element, Root>()

// `data-react-root` を持つ要素すべてにマウントし、新しくマウントした数を返す。
// 既にマウント済みの要素は飛ばすため、同じページで複数回呼ばれても二重描画にならない。
export function mountAll(): number {
  let mounted = 0

  document.querySelectorAll<HTMLElement>("[data-react-root]").forEach((element) => {
    if (roots.has(element)) return

    const root = createRoot(element)
    roots.set(element, root)
    root.render(createElement(CombatPanel))
    mounted += 1
  })

  return mounted
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
