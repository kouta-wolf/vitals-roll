import { afterEach, describe, expect, it } from "vitest"
import { act } from "react"
import { mountAll, unmountAll } from "./mount"

afterEach(() => {
  unmountAll()
  document.body.innerHTML = ""
})

describe("mountAll", () => {
  it("マウント対象が無ければ何もしない", async () => {
    await act(async () => {
      expect(mountAll()).toBe(0)
    })
  })

  it("data-react-root を持つ要素にマウントする", async () => {
    document.body.innerHTML = '<div data-react-root></div>'

    await act(async () => {
      expect(mountAll()).toBe(1)
    })
  })

  // Turbo Drive は遷移のたびに turbo:load を発火するため、
  // 同じ要素へ二重にマウントしないことを保証する
  it("同じ要素に二重マウントしない", async () => {
    document.body.innerHTML = '<div data-react-root></div>'

    await act(async () => {
      mountAll()
    })
    await act(async () => {
      expect(mountAll()).toBe(0)
    })
  })

  // Turbo Stream がマウント先を含む領域を差し替えるとDOMから外れるが、
  // その経路では turbo:before-cache が発火しないため Root が取り残される
  it("DOMから外れた要素のRootを解放し、戻ってきたら再マウントする", async () => {
    const element = document.createElement("div")
    element.setAttribute("data-react-root", "")
    document.body.appendChild(element)

    await act(async () => {
      expect(mountAll()).toBe(1)
    })

    element.remove()
    await act(async () => {
      expect(mountAll()).toBe(0)
    })

    document.body.appendChild(element)
    await act(async () => {
      expect(mountAll()).toBe(1)
    })
  })

  it("unmountAll の後は再びマウントできる", async () => {
    document.body.innerHTML = '<div data-react-root></div>'

    await act(async () => {
      mountAll()
    })
    await act(async () => {
      unmountAll()
    })
    await act(async () => {
      expect(mountAll()).toBe(1)
    })
  })
})
