import { Elm } from './src/Main.elm';
import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';

mermaid.initialize({ startOnLoad: false });

class MermaidElement extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  connectedCallback() {
    this.renderDiagram();
    this.observer = new MutationObserver(() => this.renderDiagram());
    this.observer.observe(this, { characterData: true, childList: true, subtree: true });
  }

  disconnectedCallback() {
    if (this.observer) this.observer.disconnect();
  }

  async renderDiagram() {
    const text = this.textContent.trim();
    if (!text) return;

    try {
      const id = 'mermaid-' + Math.random().toString(36).substring(2, 9);
      const { svg } = await mermaid.render(id, text);
      this.shadowRoot.innerHTML = svg;
      this.dispatchEvent(new CustomEvent('render'));
    } catch (err) {
      this.dispatchEvent(new CustomEvent('error', { detail: { error: err } }));
    }
  }
}

customElements.define('mermaid-element', MermaidElement);

const savedKey = localStorage.getItem('geminiApiKey') || "";

const app = Elm.Main.init({
  node: document.getElementById('app'),
  flags: savedKey
});

if (app.ports && app.ports.saveApiKey) {
  app.ports.saveApiKey.subscribe(function(key) {
    localStorage.setItem('geminiApiKey', key);
  });
}
