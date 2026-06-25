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
    this.appendUserMessage(text)
    this.setBusy(true)

    // Per-turn streaming state.
    const turn = { bubble: null, acc: "", toolEl: null, toolNames: [], finished: false, pending: false }

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "text/event-stream",
          "X-CSRF-Token": this.csrfToken,
          "X-Requested-With": "XMLHttpRequest",
        },
        body: JSON.stringify({ messages: this.messages }),
      })

      if (!response.ok || !response.body) {
        this.showError(this.errorValue)
        return
      }

      const reader = response.body.getReader()
      const decoder = new TextDecoder()
      let buf = ""
      for (;;) {
        const { value, done } = await reader.read()
        if (done) break
        buf += decoder.decode(value, { stream: true })
        let sep
        while ((sep = buf.indexOf("\n\n")) >= 0) {
          this.handleSse(buf.slice(0, sep), turn)
          buf = buf.slice(sep + 2)
        }
      }

      // Stream ended without a `done` event (e.g. dropped connection): keep partial text.
      if (!turn.finished && turn.acc.trim()) {
        this.messages.push({ role: "assistant", content: turn.acc.trim() })
        turn.finished = true
      }
      if (!turn.finished && !turn.bubble) this.showError(this.errorValue)
    } catch (_e) {
      if (!turn.finished) this.showError(this.errorValue)
    } finally {
      this.setBusy(false)
    }
  }

  // --- streaming + rendering helpers ---

  handleSse(rawEvent, turn) {
    let event = "message"
    let dataStr = ""
    for (const line of rawEvent.split("\n")) {
      if (line.startsWith("event:")) event = line.slice(6).trim()
      else if (line.startsWith("data:")) dataStr += line.slice(5).trim()
    }
    if (!dataStr) return

    let data
    try { data = JSON.parse(dataStr) } catch (_e) { return }

    switch (event) {
      case "tool":
        // Whatever streamed during this round was a preamble to a tool call, not the
        // answer — drop the partial bubble so only the final (no-tool) round remains.
        if (turn.bubble) { turn.bubble.remove(); turn.bubble = null }
        turn.acc = ""
        this.setBusy(true) // back to "thinking" between rounds
        this.addToolName(turn, data.name)
        break
      case "token":
        if (!turn.bubble) {
          this.setBusy(false) // first answer token: drop the "thinking" indicator
          turn.bubble = this.createBubble("assistant")
        }
        turn.acc += data.text || ""
        this.scheduleRender(turn)
        break
      case "done": {
        turn.finished = true
        const reply = ((data.reply || turn.acc) || "").trim()
        if (reply) {
          this.messages.push({ role: "assistant", content: reply })
          if (!turn.bubble) turn.bubble = this.createBubble("assistant")
          turn.bubble.innerHTML = DOMPurify.sanitize(marked.parse(reply))
        } else if (!turn.bubble) {
          this.showError(this.errorValue)
        }
        this.scrollToBottom()
        break
      }
      case "error":
        turn.finished = true
        this.showError(data.message || this.errorValue)
        break
    }
  }

  // Re-render the streaming bubble at most once per animation frame (markdown is re-parsed
  // from the full accumulated text each time).
  scheduleRender(turn) {
    if (turn.pending) return
    turn.pending = true
    requestAnimationFrame(() => {
      turn.pending = false
      if (turn.bubble) {
        turn.bubble.innerHTML = DOMPurify.sanitize(marked.parse(turn.acc))
        this.scrollToBottom()
      }
    })
  }

  addToolName(turn, name) {
    if (!name || turn.toolNames.includes(name)) return
    turn.toolNames.push(name)
    if (!turn.toolEl) {
      turn.toolEl = document.createElement("div")
      turn.toolEl.className = "assistant-tooltrace"
      this.logTarget.appendChild(turn.toolEl)
    }
    turn.toolEl.textContent = `${this.toolsLabelValue} ${turn.toolNames.join(", ")}`
    this.scrollToBottom()
  }

  appendUserMessage(text) {
    this.messages.push({ role: "user", content: text })
    this.createBubble("user").textContent = text
    this.scrollToBottom()
  }

  createBubble(role) {
    const bubble = document.createElement("div")
    bubble.className = `assistant-msg assistant-msg--${role}`
    this.logTarget.appendChild(bubble)
    return bubble
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
