import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="weapon-formula"
export default class extends Controller {
  static targets = [
    "select",
    "hitForm", "hitWeaponId",
    "attackForm", "attackWeaponId"
  ]

  change() {
    const weaponId = this.selectTarget.value
    this.hitWeaponIdTarget.value = weaponId
    this.attackWeaponIdTarget.value = weaponId
    this.hitFormTarget.requestSubmit()
    this.attackFormTarget.requestSubmit()
  }
}
