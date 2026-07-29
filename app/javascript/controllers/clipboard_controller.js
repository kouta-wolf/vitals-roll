import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="clipboard"
export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    const text = this.sourceTarget.textContent.trim()

    navigator.clipboard.writeText(text).then(() => {
      this.showFeedback()
    }).catch((error) => {
      console.error("クリップボードへのコピーに失敗しました", error)
    })
  }

  showFeedback() {
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "コピーしました！"
    setTimeout(() => {
      this.buttonTarget.textContent = original
    }, 1500)
  }
}
