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
