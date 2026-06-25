import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"
import DOMPurify from "dompurify"

// Smart assistant pop-up. Holds the full dialogue client-side and re-sends it to the
// backend (/assistant/chat) on every turn so conversation context is preserved. The
// backend runs the LLM <-> MCP tool-calling loop and returns the final answer plus the
// trace of tools that were used.
//
// Connects to data-controller="assistant"
export default class extends Controller {
  static targets = ["panel", "log", "input", "status", "send"]
  static values = {
    url: String,
    error: String,
    toolsLabel: String,
  }

  connect() {
    this.messages = []   // {role: "user"|"assistant", content} — sent to the backend each turn
    this.opened = false
    this.busy = false
    marked.setOptions({ breaks: true, gfm: true })
  }

  toggle() {
    this.opened = !this.opened
    this.element.classList.toggle("assistant--open", this.opened)
    if (this.opened) {
      this.inputTarget.focus()
      this.scrollToBottom()
    } else {
      this.element.classList.remove("assistant--modal") // start from the corner next time
    }
  }

  // Expand the chat into a large centered modal (or shrink it back). Reuses the same
  // panel/log/controller, so the conversation is preserved.
  toggleModal() {
    if (!this.opened) this.toggle()
    this.element.classList.toggle("assistant--modal")
    this.inputTarget.focus()
    this.scrollToBottom()
  }

  // Backdrop click: shrink the modal back to the corner panel (keeps the chat open).
  collapseModal() {
    this.element.classList.remove("assistant--modal")
  }

  // Enter sends; Shift+Enter inserts a newline.
  keydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit(event)
    }
  }

  async submit(event) {
    if (event) event.preventDefault()
    if (this.busy) return

    const text = this.inputTarget.value.trim()
    if (!text) return

    this.inputTarget.value = ""
    this.autoGrow()
    this.pushMessage("user", text)
    this.setBusy(true)

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "X-Requested-With": "XMLHttpRequest",
        },
        body: JSON.stringify({ messages: this.messages }),
      })

      const data = await response.json().catch(() => ({}))

      if (!response.ok) {
        this.showError(data.error || this.errorValue)
        return
      }

      this.renderToolTrace(data.tool_calls)

      const reply = (data.reply || "").trim()
      if (reply) {
        this.pushMessage("assistant", reply)
      } else {
        this.showError(this.errorValue)
      }
    } catch (_e) {
      this.showError(this.errorValue)
    } finally {
      this.setBusy(false)
    }
  }

  // --- rendering helpers ---

  pushMessage(role, content) {
    this.messages.push({ role, content })
    const bubble = document.createElement("div")
    bubble.className = `assistant-msg assistant-msg--${role}`
    if (role === "assistant") {
      bubble.innerHTML = DOMPurify.sanitize(marked.parse(content))
    } else {
      bubble.textContent = content
    }
    this.logTarget.appendChild(bubble)
    this.scrollToBottom()
  }

  renderToolTrace(calls) {
    if (!Array.isArray(calls) || calls.length === 0) return
    const names = [...new Set(calls.map((c) => c && c.name).filter(Boolean))]
    if (names.length === 0) return

    const trace = document.createElement("div")
    trace.className = "assistant-tooltrace"
    trace.textContent = `${this.toolsLabelValue} ${names.join(", ")}`
    this.logTarget.appendChild(trace)
    this.scrollToBottom()
  }

  showError(message) {
    const el = document.createElement("div")
    el.className = "assistant-msg assistant-msg--error"
    el.textContent = message
    this.logTarget.appendChild(el)
    this.scrollToBottom()
  }

  setBusy(state) {
    this.busy = state
    this.statusTarget.classList.toggle("d-none", !state)
    if (this.hasSendTarget) this.sendTarget.disabled = state
    if (state) this.scrollToBottom()
  }

  autoGrow() {
    const el = this.inputTarget
    el.style.height = "auto"
    el.style.height = `${Math.min(el.scrollHeight, 120)}px`
  }

  scrollToBottom() {
    this.logTarget.scrollTop = this.logTarget.scrollHeight
  }

  get csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}
