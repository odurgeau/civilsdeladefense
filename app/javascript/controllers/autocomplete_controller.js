import { Controller } from "@hotwired/stimulus"
import SlimSelect from "slim-select"

export default class extends Controller {
  static targets = []

  initialize() {
    console.log("auto-complete")
    
    // let tomSelect = new TomSelect(this.element, config)
    new SlimSelect({
      select: this.element
    })
  }
}
