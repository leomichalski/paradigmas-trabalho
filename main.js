import { Elm } from './src/Main.elm';
import MermaidElement from 'mermaid-element';
import mermaid from 'mermaid';

MermaidElement.defaultMermaid = mermaid;
customElements.define('mermaid-element', MermaidElement);

Elm.Main.init({
  node: document.getElementById('app')
});
