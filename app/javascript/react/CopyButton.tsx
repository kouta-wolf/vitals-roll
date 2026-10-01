import { useEffect, useRef, useState } from "react"

const FEEDBACK_MS = 1500

// 判定式をクリップボードへコピーする。Stimulus の clipboard_controller.js を置き換える
export function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false)
  const timer = useRef<number | null>(null)

  useEffect(() => {
    return () => {
      if (timer.current !== null) window.clearTimeout(timer.current)
    }
  }, [])

  const copy = async (): Promise<void> => {
    try {
      await navigator.clipboard.writeText(text)
      setCopied(true)
      if (timer.current !== null) window.clearTimeout(timer.current)
      timer.current = window.setTimeout(() => setCopied(false), FEEDBACK_MS)
    } catch (error) {
      console.error("クリップボードへのコピーに失敗しました", error)
    }
  }

  return (
    <button
      type="button"
      onClick={() => void copy()}
      className="px-2 py-0.5 text-xs rounded border border-gray-300 bg-white hover:bg-gray-50"
    >
      {copied ? "コピーしました！" : "コピー"}
    </button>
  )
}
