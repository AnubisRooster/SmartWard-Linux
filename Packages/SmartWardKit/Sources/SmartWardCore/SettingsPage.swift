import Foundation

/// The single-page Settings UI served by `smartward settings`. No external
/// files or scripts: the page's content-security policy allows only itself.
enum SettingsPage {
    static let html = #"""
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>SmartWard settings</title>
    <style>
      :root {
        color-scheme: light dark;
        --bg: #f6f6f4; --card: #ffffff; --text: #1d1d1b; --muted: #6a6a64; --line: #deded8;
        --accent: #1f6feb; --accent-text: #ffffff; --ok: #1a7f37; --bad: #cf222e; --warn: #9a6700;
      }
      @media (prefers-color-scheme: dark) {
        :root {
          --bg: #141413; --card: #1e1e1c; --text: #ececE8; --muted: #9b9b94; --line: #33332f;
          --accent: #4c8dff; --accent-text: #0b0b0a; --ok: #3fb950; --bad: #ff7b72; --warn: #d29922;
        }
      }
      * { box-sizing: border-box; }
      body { margin: 0; background: var(--bg); color: var(--text);
        font: 15px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
      main { max-width: 760px; margin: 0 auto; padding: 24px 16px 96px; }
      h1 { font-size: 22px; margin: 0 0 4px; }
      h2 { font-size: 16px; margin: 0 0 12px; }
      p.lead { margin: 0 0 20px; color: var(--muted); }
      section { background: var(--card); border: 1px solid var(--line); border-radius: 12px;
        padding: 16px; margin-bottom: 16px; }
      label { display: block; font-size: 13px; color: var(--muted); margin: 12px 0 4px; }
      label:first-of-type { margin-top: 0; }
      button + label { margin-top: 16px; }
      select, input[type=text] { width: 100%; padding: 8px 10px; border-radius: 8px; border: 1px solid var(--line);
        background: var(--bg); color: var(--text); font: inherit; }
      input[type=range] { width: 100%; accent-color: var(--accent); }
      .row { display: flex; gap: 8px; align-items: center; }
      .row > * { flex: 1; }
      .row > button { flex: none; }
      button { font: inherit; padding: 8px 14px; border-radius: 8px; border: 1px solid var(--line);
        background: var(--card); color: var(--text); cursor: pointer; }
      button.primary { background: var(--accent); color: var(--accent-text); border-color: var(--accent); }
      button:disabled { opacity: .5; cursor: default; }
      button.danger { color: var(--bad); }
      .hint { font-size: 13px; color: var(--muted); margin-top: 6px; }
      .status { display: inline-flex; align-items: center; gap: 6px; margin-right: 16px; font-size: 13px; }
      .dot { width: 9px; height: 9px; border-radius: 50%; background: var(--muted); display: inline-block; }
      .dot.ok { background: var(--ok); } .dot.bad { background: var(--bad); }
      .profile { border: 1px solid var(--line); border-radius: 10px; padding: 12px; margin-bottom: 10px; }
      .profile .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 12px; }
      .profile .grid .full { grid-column: 1 / -1; }
      .speed { display: flex; align-items: center; gap: 10px; }
      .speed output { min-width: 3.2em; text-align: right; font-variant-numeric: tabular-nums; }
      footer { position: fixed; left: 0; right: 0; bottom: 0; background: var(--card); border-top: 1px solid var(--line); }
      footer .inner { max-width: 760px; margin: 0 auto; padding: 12px 16px; display: flex; gap: 12px; align-items: center; }
      #message { flex: 1; font-size: 14px; white-space: pre-line; }
      #message.ok { color: var(--ok); } #message.bad { color: var(--bad); }
      .warn { color: var(--warn); }
      @media (max-width: 520px) { .profile .grid { grid-template-columns: 1fr; } }
    </style>
    </head>
    <body>
    <main>
      <h1>SmartWard settings</h1>
      <p class="lead">Everything here runs on this machine. Changes apply to <code>smartward read</code> and the other commands once you save.</p>

      <section aria-labelledby="h-servers">
        <h2 id="h-servers">Local servers</h2>
        <div id="status"></div>
        <label for="speechURL">Speech server</label>
        <input type="text" id="speechURL" autocomplete="off" spellcheck="false">
        <label for="ollamaURL">Ollama</label>
        <input type="text" id="ollamaURL" autocomplete="off" spellcheck="false">
        <div class="hint">Both must be on this machine (127.0.0.1 or localhost).</div>
      </section>

      <section aria-labelledby="h-voice">
        <h2 id="h-voice">Reading voice</h2>
        <label for="voice">Voice</label>
        <div class="row"><select id="voice"></select><button id="listen-voice" type="button">Listen</button></div>
        <label for="speed">Speed</label>
        <div class="speed"><input type="range" id="speed" min="0.5" max="2" step="0.05"><output id="speed-out"></output></div>
        <div class="hint" id="voice-hint"></div>
      </section>

      <section aria-labelledby="h-profiles">
        <h2 id="h-profiles">Reading profiles</h2>
        <p class="hint" style="margin-top:0">A profile bundles a voice, a speed and how much to read. Pick one with <code>smartward read --profile NAME</code>, or make one the default.</p>
        <div id="profiles"></div>
        <button id="add-profile" type="button">Add a profile</button>
        <label for="activeProfile">Default profile</label>
        <select id="activeProfile"></select>
      </section>

      <section aria-labelledby="h-models">
        <h2 id="h-models">Models</h2>
        <label for="chatModel">Chat model (summaries, graph, answers)</label>
        <select id="chatModel"></select>
        <label for="embeddingModel">Embedding model (search)</label>
        <select id="embeddingModel"></select>
        <div class="hint" id="model-hint"></div>
      </section>
    </main>
    <footer><div class="inner">
      <div id="message" role="status" aria-live="polite"></div>
      <button id="revert" type="button">Revert</button>
      <button id="save" type="button" class="primary" disabled>Save</button>
    </div></footer>

    <script>
    "use strict";
    const token = new URLSearchParams(location.search).get("t") || "";
    const $ = (id) => document.getElementById(id);
    const GROUPS = {
      af: "American English · female", am: "American English · male", bf: "British English · female", bm: "British English · male",
      ef: "Spanish · female", em: "Spanish · male", ff: "French · female", hf: "Hindi · female", hm: "Hindi · male",
      if: "Italian · female", im: "Italian · male", jf: "Japanese · female", jm: "Japanese · male",
      pf: "Portuguese · female", pm: "Portuguese · male", zf: "Mandarin · female", zm: "Mandarin · male"
    };
    let saved = null, settings = null, voices = [], status = null, player = null;

    async function api(path, options = {}) {
      const headers = { "X-SmartWard-Token": token };
      if (options.body) headers["Content-Type"] = "application/json";
      const response = await fetch(path, { ...options, headers });
      if (!response.ok) {
        let text = response.statusText;
        try { text = (await response.json()).error || text; } catch (_) {}
        throw new Error(text);
      }
      return response;
    }

    function say(text, kind) { const m = $("message"); m.textContent = text || ""; m.className = kind || ""; }
    function el(tag, props = {}, children = []) {
      const node = Object.assign(document.createElement(tag), props);
      for (const child of children) node.append(child);
      return node;
    }
    function voiceLabel(name) {
      const rest = name.slice(3), group = GROUPS[name.slice(0, 2)];
      return rest.charAt(0).toUpperCase() + rest.slice(1) + (group ? " — " + group.replace(" · ", ", ") : "");
    }
    function fillVoices(select, current) {
      select.replaceChildren();
      const names = voices.length ? voices : [current];
      const known = names.includes(current) ? names : [current, ...names];
      const groups = new Map();
      for (const name of known) {
        const title = GROUPS[name.slice(0, 2)] || "Other";
        if (!groups.has(title)) groups.set(title, el("optgroup", { label: title }));
        groups.get(title).append(el("option", { value: name, textContent: voiceLabel(name) }));
      }
      const order = Object.values(GROUPS);
      [...groups.entries()].sort((a, b) => (order.indexOf(a[0]) + 1 || 99) - (order.indexOf(b[0]) + 1 || 99))
        .forEach(([, group]) => select.append(group));
      select.value = current;
    }
    function fillModels(select, current) {
      select.replaceChildren();
      const installed = status ? status.installedModels : [];
      const names = installed.includes(current) ? installed : [current, ...installed];
      for (const name of names) {
        const missing = status && status.ollamaReachable && !installed.includes(name);
        select.append(el("option", { value: name, textContent: name + (missing ? " (not installed)" : "") }));
      }
      select.value = current;
    }
    function isDirty() { return JSON.stringify(settings) !== JSON.stringify(saved); }
    function touch() { $("save").disabled = !isDirty(); if (isDirty()) say(""); }

    async function listen(button, voice, speed) {
      button.disabled = true; const label = button.textContent; button.textContent = "Loading…"; say("");
      try {
        const blob = await (await api("/api/sample", { method: "POST", body: JSON.stringify({ voice, speed }) })).blob();
        if (player) player.pause();
        player = new Audio(URL.createObjectURL(blob));
        await player.play();
      } catch (error) { say("Couldn't play a sample: " + error.message, "bad"); }
      finally { button.disabled = false; button.textContent = label; }
    }

    function renderStatus() {
      const box = $("status"); box.replaceChildren();
      const item = (ok, text) => el("span", { className: "status" }, [el("span", { className: "dot " + (ok ? "ok" : "bad") }), text]);
      box.append(item(status && status.speechReachable, status && status.speechReachable ? "Speech server running" : "Speech server not reachable"),
                 item(status && status.ollamaReachable, status && status.ollamaReachable ? "Ollama running" : "Ollama not reachable"));
      $("voice-hint").textContent = voices.length ? "" : "Start the speech server to list its voices (see tools/kokoro-server/README.md).";
      const missing = status && status.ollamaReachable && [settings.chatModel, settings.embeddingModel].filter((m) => !status.installedModels.includes(m));
      const hint = $("model-hint"); hint.textContent = ""; hint.className = "hint";
      if (missing && missing.length) { hint.className = "hint warn"; hint.textContent = "Not installed: " + missing.join(", ") + ". Run: ollama pull " + missing[0]; }
    }

    function renderProfiles() {
      const box = $("profiles"); box.replaceChildren();
      for (const name of Object.keys(settings.profiles)) {
        const profile = settings.profiles[name];
        const nameInput = el("input", { type: "text", value: name, maxLength: 40 });
        const voice = el("select"); fillVoices(voice, profile.voice);
        const out = el("output", { textContent: profile.speed.toFixed(2) + "×" });
        const speed = el("input", { type: "range", min: 0.5, max: 2, step: 0.05, value: profile.speed });
        const scope = el("select", {}, [el("option", { value: "whole", textContent: "The whole article" }), el("option", { value: "summary", textContent: "Title and summary only" })]);
        scope.value = profile.scope;
        const listenButton = el("button", { type: "button", textContent: "Listen" });
        const remove = el("button", { type: "button", textContent: "Delete", className: "danger" });
        nameInput.addEventListener("change", () => {
          const next = nameInput.value.trim();
          if (!next || (next !== name && next in settings.profiles)) { nameInput.value = name; return; }
          const entries = Object.entries(settings.profiles).map(([k, v]) => [k === name ? next : k, v]);
          settings.profiles = Object.fromEntries(entries);
          if (settings.activeProfile === name) settings.activeProfile = next;
          renderProfiles(); renderActive(); touch();
        });
        voice.addEventListener("change", () => { profile.voice = voice.value; touch(); });
        speed.addEventListener("input", () => { profile.speed = parseFloat(speed.value); out.textContent = profile.speed.toFixed(2) + "×"; touch(); });
        scope.addEventListener("change", () => { profile.scope = scope.value; touch(); });
        listenButton.addEventListener("click", () => listen(listenButton, profile.voice, profile.speed));
        remove.addEventListener("click", () => {
          delete settings.profiles[name];
          if (settings.activeProfile === name) settings.activeProfile = null;
          renderProfiles(); renderActive(); touch();
        });
        box.append(el("div", { className: "profile" }, [el("div", { className: "grid" }, [
          el("div", {}, [el("label", { textContent: "Name" }), nameInput]),
          el("div", {}, [el("label", { textContent: "Reads" }), scope]),
          el("div", {}, [el("label", { textContent: "Voice" }), voice]),
          el("div", {}, [el("label", { textContent: "Speed" }), el("div", { className: "speed" }, [speed, out])]),
          el("div", { className: "row full" }, [el("span"), listenButton, remove])
        ])]));
      }
      $("add-profile").disabled = Object.keys(settings.profiles).length >= 24;
    }
    function renderActive() {
      const select = $("activeProfile"); select.replaceChildren(el("option", { value: "", textContent: "None — use the voice above" }));
      for (const name of Object.keys(settings.profiles)) select.append(el("option", { value: name, textContent: name }));
      select.value = settings.activeProfile || "";
    }

    function render() {
      $("speechURL").value = settings.speechURL; $("ollamaURL").value = settings.ollamaURL;
      fillVoices($("voice"), settings.voice);
      $("speed").value = settings.speed; $("speed-out").textContent = settings.speed.toFixed(2) + "×";
      fillModels($("chatModel"), settings.chatModel); fillModels($("embeddingModel"), settings.embeddingModel);
      renderStatus(); renderProfiles(); renderActive(); touch();
    }

    async function load() {
      say("Loading…");
      try {
        const [s, v, st] = await Promise.allSettled([api("/api/settings"), api("/api/voices"), api("/api/status")]);
        if (s.status !== "fulfilled") throw s.reason;
        saved = await s.value.json(); settings = JSON.parse(JSON.stringify(saved));
        voices = v.status === "fulfilled" ? (await v.value.json()).voices : [];
        status = st.status === "fulfilled" ? await st.value.json() : null;
        render(); say("");
      } catch (error) { say("Couldn't load settings: " + error.message + " Open the address smartward settings printed.", "bad"); }
    }

    $("speechURL").addEventListener("input", (e) => { settings.speechURL = e.target.value.trim(); touch(); });
    $("ollamaURL").addEventListener("input", (e) => { settings.ollamaURL = e.target.value.trim(); touch(); });
    $("voice").addEventListener("change", (e) => { settings.voice = e.target.value; touch(); });
    $("speed").addEventListener("input", (e) => { settings.speed = parseFloat(e.target.value); $("speed-out").textContent = settings.speed.toFixed(2) + "×"; touch(); });
    $("chatModel").addEventListener("change", (e) => { settings.chatModel = e.target.value; renderStatus(); touch(); });
    $("embeddingModel").addEventListener("change", (e) => { settings.embeddingModel = e.target.value; renderStatus(); touch(); });
    $("activeProfile").addEventListener("change", (e) => { settings.activeProfile = e.target.value || null; touch(); });
    $("listen-voice").addEventListener("click", () => listen($("listen-voice"), settings.voice, settings.speed));
    $("add-profile").addEventListener("click", () => {
      let n = 1; while (("Profile " + n) in settings.profiles) n++;
      settings.profiles["Profile " + n] = { voice: settings.voice, speed: settings.speed, scope: "whole" };
      renderProfiles(); renderActive(); touch();
    });
    $("revert").addEventListener("click", () => { settings = JSON.parse(JSON.stringify(saved)); render(); say(""); });
    $("save").addEventListener("click", async () => {
      $("save").disabled = true; say("Saving…");
      try {
        saved = await (await api("/api/settings", { method: "PUT", body: JSON.stringify(settings) })).json();
        settings = JSON.parse(JSON.stringify(saved)); render(); say("Saved.", "ok");
        api("/api/status").then((r) => r.json()).then((s) => { status = s; render(); say("Saved.", "ok"); }).catch(() => {});
      } catch (error) { say(error.message, "bad"); $("save").disabled = false; }
    });
    window.addEventListener("beforeunload", (e) => { if (isDirty()) { e.preventDefault(); e.returnValue = ""; } });
    load();
    </script>
    </body>
    </html>
    """#
}
