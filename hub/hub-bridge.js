// ULSハブのブリッジ。ハブ外（ブラウザ単体）では localStorage で代替する。
window.ToolStorage = (() => { const hub = window.ULSHub; const p = 'tool:';
  if (hub) return { ready: hub.ready, getItem: k => hub.storage.getItem(k), setItem: (k, v) => hub.storage.setItem(k, v), removeItem: k => hub.storage.removeItem(k) };
  return { ready: Promise.resolve(), getItem: async k => localStorage.getItem(p + k), setItem: async (k, v) => localStorage.setItem(p + k, v), removeItem: async k => localStorage.removeItem(p + k) }; })();
window.openExternal = url => { if (window.ULSHub && ULSHub.openExternal) ULSHub.openExternal(url); else window.open(url, '_blank', 'noopener'); };
