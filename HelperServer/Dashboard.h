#pragma once
#include "Common.h"

std::string helper_dashboard_html() {
    return R"DEXAPP(<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>DEX++ Helper</title>
<style>
:root{color-scheme:dark;--bg:#0b0f14;--sidebar:#10151b;--panel:#151b22;--panel2:#1a222b;--panel3:#202a34;--line:#2a3743;--line-soft:#202a34;--text:#f2f5f7;--muted:#8fa0b1;--accent:#52b69a;--accent2:#68c7a9;--warn:#d7ad56;--bad:#e66a73}
*{box-sizing:border-box;scrollbar-width:thin;scrollbar-color:#53606c transparent}*::-webkit-scrollbar{width:8px;height:8px}*::-webkit-scrollbar-track{background:transparent}*::-webkit-scrollbar-thumb{background:#4a5662;border:2px solid transparent;background-clip:padding-box;border-radius:8px}*::-webkit-scrollbar-thumb:hover{background:#65727e;border:2px solid transparent;background-clip:padding-box}*::-webkit-scrollbar-button{display:none;width:0;height:0}
html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.48 "Segoe UI Variable","Segoe UI",Arial,sans-serif;letter-spacing:0}
header{height:48px;display:flex;align-items:center;gap:9px;padding:0 16px;border-bottom:1px solid var(--line-soft);background:#0d1217;position:sticky;top:0;z-index:2}
h1{display:none}.pill{font:11px Consolas,monospace;color:var(--muted);background:#141b22;border:1px solid var(--line);border-radius:4px;padding:4px 8px}
main{display:grid;grid-template-columns:306px 1fr;height:calc(100vh - 48px);min-height:560px;overflow:hidden}
aside{overflow:auto;border-right:1px solid var(--line-soft);background:var(--sidebar);padding:12px 12px 20px;display:flex;flex-direction:column;gap:2px}
section{padding:14px 16px 16px;display:grid;grid-template-rows:auto auto minmax(0,1fr);gap:10px;min-width:0;min-height:0;overflow:hidden}
.card{background:transparent;border:0;border-bottom:1px solid var(--line-soft);border-radius:0;padding:15px 8px 17px}.card:last-child{border-bottom:0}.title{font-size:12px;font-weight:650;color:#cbd5de;margin-bottom:10px;text-transform:uppercase}
.metrics{display:grid;grid-template-columns:1fr 1fr;gap:7px}.metric{background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:10px 11px}.metric b{display:block;font-size:20px;font-weight:650;font-variant-numeric:tabular-nums}.metric span{color:var(--muted);font-size:11px}
.stateRows{display:flex;flex-direction:column;gap:6px}.stateRow{background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:9px 10px}.stateRow b{display:block;font-size:13px;font-weight:600}.stateRow span{display:block;color:var(--muted);font:11px/1.45 Consolas,monospace;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.bar{height:4px;background:#0b1015;border-radius:4px;overflow:hidden;margin-top:7px}.bar i{display:block;height:100%;width:0;background:var(--accent2)}
button,input,textarea{font:inherit;letter-spacing:0}button{background:var(--panel2);border:1px solid var(--line);color:#dce4ea;border-radius:5px;height:31px;padding:0 11px;cursor:pointer;transition:border-color .16s,background .16s,color .16s,transform .16s}button:hover{border-color:#465767;background:var(--panel3);color:white}button:active{transform:translateY(1px)}button:focus-visible,input:focus-visible,textarea:focus-visible{outline:2px solid rgba(82,182,154,.45);outline-offset:1px}button.primary{background:var(--accent);border-color:var(--accent);color:#07130f;font-weight:650}button.primary:hover{background:var(--accent2);border-color:var(--accent2)}.row{display:flex;gap:7px;align-items:center;flex-wrap:wrap}.row>*{min-width:0}
input,textarea{width:100%;background:#0d1217;border:1px solid var(--line);color:var(--text);border-radius:5px;padding:8px 10px;outline:none}input:focus,textarea:focus{border-color:var(--accent)}textarea{min-height:150px;resize:vertical;font-family:Consolas,monospace}
.toolbar{display:grid;grid-template-columns:1fr auto auto;gap:8px}.tabs{display:flex;gap:2px;border-bottom:1px solid var(--line-soft)}.tab{height:34px;border:0;border-bottom:2px solid transparent;border-radius:0;background:transparent;color:var(--muted)}.tab:hover{background:transparent;color:var(--text);border-color:#43515e}.tab.active{border-color:var(--accent);color:white;background:transparent}
.results{min-height:0;overflow:auto;border:1px solid var(--line-soft);border-radius:6px;background:#0d1217}.hit{padding:11px 13px;border-bottom:1px solid var(--line-soft)}.hit:last-child{border-bottom:0}.hit h3{font-size:14px;margin:0 0 4px}.hit .meta{color:var(--muted);font:11px Consolas,monospace;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.hit pre{margin:8px 0 0;white-space:pre-wrap;color:#cbd5e1;font:12px Consolas,monospace}
.searchWorkspace{display:grid;grid-template-columns:minmax(280px,40%) minmax(320px,1fr);min-height:0;overflow:hidden;border:1px solid var(--line-soft);border-radius:6px;background:#0d1217}.resultList{min-height:0;overflow:auto;border-right:1px solid var(--line-soft)}.resultSummary{position:sticky;top:0;z-index:1;padding:9px 12px;background:#131920;border-bottom:1px solid var(--line-soft);color:var(--muted);font:11px Consolas,monospace}.resultItem{display:block;width:100%;height:auto;padding:11px 12px;text-align:left;border:0;border-bottom:1px solid var(--line-soft);border-radius:0;background:transparent}.resultItem:hover{background:#151d24}.resultItem.active{background:#182822;box-shadow:inset 2px 0 var(--accent)}.resultItem h3{font-size:14px;margin:0 0 4px;color:var(--text)}.resultItem .meta{color:var(--muted);font:11px Consolas,monospace;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.resultInspector{min-width:0;min-height:0;display:grid;grid-template-rows:auto auto minmax(0,1fr);overflow:hidden}.inspectorHead{padding:12px 14px;border-bottom:1px solid var(--line-soft)}.inspectorHead h2{font-size:15px;margin:0 0 4px}.inspectorActions{display:flex;gap:7px;flex-wrap:wrap;padding:9px 12px;border-bottom:1px solid var(--line-soft);background:#11171d}.sourcePreview{margin:0;padding:14px;overflow:auto;white-space:pre;tab-size:4;color:#cbd5e1;font:12px/1.55 Consolas,monospace}.emptyInspector{display:grid;place-items:center;padding:28px;color:var(--muted);text-align:center}.actionStatus{margin-left:auto;align-self:center;color:var(--muted);font:11px Consolas,monospace}
.hero{display:grid;grid-template-columns:1.15fr .85fr;gap:12px}.statusGrid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}.dot{display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--muted);margin-right:6px}.dot.ok{background:var(--accent2);box-shadow:0 0 10px rgba(104,199,169,.4)}.dot.warn{background:var(--warn)}.dot.bad{background:var(--bad)}.codebox{font:11px Consolas,monospace;background:#0d1217;border:1px solid var(--line-soft);border-radius:5px;padding:8px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.steps{display:grid;gap:9px}.step{display:grid;grid-template-columns:24px 1fr;gap:9px;align-items:start}.step b{display:grid;place-items:center;width:22px;height:22px;border-radius:4px;background:var(--panel2);border:1px solid var(--line);font:11px Consolas,monospace}
.muted{color:var(--muted)}.ok{color:var(--accent2)}.warn{color:var(--warn)}.bad{color:var(--bad)}.hidden{display:none!important}
@media(max-width:980px){main{grid-template-columns:1fr;height:auto;min-height:calc(100vh - 48px);overflow:visible}.hero{grid-template-columns:1fr}aside{border-right:0;border-bottom:1px solid var(--line);max-height:46vh}section{height:70vh}.searchWorkspace{grid-template-columns:minmax(240px,38%) 1fr}}
@media(max-width:700px){.searchWorkspace{grid-template-columns:1fr}.resultList{border-right:0}.resultInspector{display:none}}
</style>
</head>
<body>
<header><h1>DEX++ Helper</h1><span class="pill" id="statusPill">checking</span><span class="pill" id="scriptPill">script unknown</span><span class="pill" id="dexPill">Roblox waiting</span></header>
<main>
<aside>
  <div class="card">
    <div class="title"><span class="dot warn" id="scriptDot"></span>Script delivery</div>
    <div class="muted" id="scriptStatus">Checking DEX++_compiled.luau...</div>
    <div class="codebox" id="loadstringBox" style="margin-top:8px">loadstring(game:HttpGet("http://localhost:8080/script"))()</div>
    <div class="row" style="margin-top:8px"><button id="copyLoadstring" class="primary">Copy loadstring</button><button id="openScript">Open script</button></div>
  </div>
  <div class="card">
    <div class="title"><span class="dot warn" id="dexDot"></span>Current Roblox session</div>
    <div class="stateRows">
      <div class="stateRow"><b id="gameName">Waiting for DEX</b><span id="gameMeta">Run the loadstring in Roblox to connect this dashboard.</span></div>
      <div class="stateRow"><b id="indexTarget">No active index</b><span id="indexMeta">Code Search > Index Scripts will show progress here.</span></div>
    </div>
  </div>
  <div class="card">
    <div class="title">Worker roles</div>
    <div id="workerRoles" class="stateRows">
      <div class="stateRow"><b>Detecting workers</b><span>C++, Python, Rust role map will appear here.</span></div>
    </div>
  </div>
  <div class="card">
    <div class="title">Toolchain setup</div>
    <div id="toolchainStatus" class="stateRows">
      <div class="stateRow"><b>Checking build tools</b><span>Python, Cargo, g++, and winget.</span></div>
    </div>
    <button id="openToolchainSetup" style="margin-top:8px;width:100%">Open setup utility</button>
  </div>
  <div class="card">
    <div class="title">Index</div>
    <div class="metrics">
      <div class="metric"><b id="scripts">0</b><span>scripts</span></div>
      <div class="metric"><b id="bytes">0</b><span>bytes</span></div>
    </div>
    <div class="row" style="margin-top:10px"><button id="refresh">Refresh</button><button id="load">Load</button><button id="save">Save</button><button id="clear">Clear</button></div>
  </div>
  <div class="card">
    <div class="title">Live DEX</div>
    <div id="liveDex" class="stateRows">
      <div class="stateRow"><b>Waiting for Roblox</b><span>Enable Use Local Helper and run an index/control tool.</span></div>
    </div>
  </div>
  <div class="card">
    <div class="title">Roblox Smooth Mode</div>
    <div class="muted">Keep heavy search and analysis here. In DEX, leave Helper logging off while playing. Index scripts only when you are not in a demanding fight/session.</div>
  </div>
  <div class="card">
    <div class="title">Local services</div>
    <div class="muted">Stops only DEX++ Helper on port 8080 and Potassium Decompiler on port 56535. Potassium itself stays open.</div>
    <div class="row" style="margin-top:8px">
      <button id="stopLocal">Stop services</button>
      <button id="cleanLocal" class="bad">Clean + stop</button>
    </div>
  </div>
  <div class="card">
    <div class="title">Analyze Source</div>
    <textarea id="sourceBox" placeholder="Paste cached/source text here"></textarea>
    <div class="row" style="margin-top:8px"><button id="analyze" class="primary">Analyze</button><button id="normalize">Normalize</button></div>
  </div>
  <div class="card">
    <div class="title">Remote Contract Analyzer</div>
    <textarea id="remoteBox" placeholder="Paste RemoteSpy copied logs here"></textarea>
    <div class="row" style="margin-top:8px"><button id="remoteAnalyze" class="primary">Analyze Remotes</button></div>
  </div>
</aside>
<section>
  <div class="toolbar">
    <input id="query" placeholder="Search helper index: remote name, require, path, identifier">
    <button id="search" class="primary">Search</button>
    <button id="script">Open /script</button>
  </div>
  <div class="tabs">
    <button class="tab active" data-view="resultsView">Results</button>
    <button class="tab" data-view="analysisView">Analysis</button>
    <button class="tab" data-view="remoteView">Remotes</button>
    <button class="tab" data-view="aiChatView">AI Chat</button>
    <button class="tab" data-view="accountsView">Accounts</button>
    <button class="tab" data-view="mcpView">MCP & IDEs</button>
    <button class="tab" data-view="helpView">First run guide</button>
  </div>
  <div id="resultsView" class="searchWorkspace">
    <div id="resultList" class="resultList">
      <div class="resultSummary">Search waits for an index</div>
      <div class="hit"><div class="meta">Run DEX in Roblox, open Search Center, then use Index Scripts.</div></div>
    </div>
    <div id="resultInspector" class="resultInspector">
      <div class="emptyInspector">Select a script to preview its source and use quick actions.</div>
    </div>
  </div>
  <div id="analysisView" class="results hidden"><div class="hit"><h3>No analysis yet</h3><pre id="analysisOut">Paste source and click Analyze or Normalize.</pre></div></div>
  <div id="remoteView" class="results hidden"><div class="hit"><h3>No remote analysis yet</h3><pre>Paste RemoteSpy logs and click Analyze Remotes.</pre></div></div>
  <div id="aiChatView" class="results hidden" style="height:100%">
    <div style="display:grid;grid-template-rows:1fr auto auto;height:100%;padding:14px;gap:10px;min-height:0">
      <div id="chatHistory" style="border:1px solid var(--line-soft);border-radius:6px;background:#0d1217;padding:14px;display:flex;flex-direction:column;gap:10px;min-height:0;overflow-y:auto">
        <div class="hit">
          <h3>DEX++ AI Assistant</h3>
          <p style="margin:4px 0 0;color:#cbd5e1;line-height:1.5">Welcome! I am your AI assistant. Set your Gemini API Key below to start chatting and analyzing Roblox scripts.</p>
        </div>
      </div>
      <div class="toolbar" style="grid-template-columns:1fr auto;margin-top:4px">
        <input id="chatInput" placeholder="Ask AI about the codebase, active script, or write a custom query...">
        <button id="sendChat" class="primary" style="width:90px">Send</button>
      </div>
      <div class="row" style="background:var(--sidebar);border:1px solid var(--line-soft);padding:8px 12px;border-radius:6px;gap:10px;margin-top:4px;flex-wrap:wrap">
        <span style="font-size:12px;font-weight:600">AI Provider:</span>
        <select id="aiProviderSelect" style="height:28px;background:var(--panel2);color:var(--text);border:1px solid var(--line);border-radius:4px;padding:0 6px;font-size:11px">
          <option value="gemini">Google Gemini (Direct)</option>
          <option value="openai">OpenAI (Direct)</option>
          <option value="github_models">GitHub Models (Codex/GPT)</option>
          <option value="openai_compatible">9Router / OpenRouter / Custom</option>
        </select>
        
        <span id="apiUrlLabel" style="font-size:12px;font-weight:600;display:none">Base URL:</span>
        <input id="apiUrlInput" type="text" placeholder="http://localhost:20128/v1" style="width:160px;height:28px;padding:4px 8px;font-size:11px;display:none">
        
        <span id="aiModelLabel" style="font-size:12px;font-weight:600;display:none">Model:</span>
        <select id="aiModelSelect" style="height:28px;background:var(--panel2);color:var(--text);border:1px solid var(--line);border-radius:4px;padding:0 6px;font-size:11px;display:none"></select>
        <input id="aiModelInput" type="text" placeholder="Enter model..." style="width:140px;height:28px;padding:4px 8px;font-size:11px;display:none">
        
        <span id="apiKeyLabel" style="font-size:12px;font-weight:600">API Key:</span>
        <input id="apiKeyInput" type="password" placeholder="Enter API Key..." style="width:160px;height:28px;padding:4px 8px;font-size:11px">
        
        <button id="saveApiKey" class="primary" style="height:28px;padding:0 10px;font-size:11px">Save Settings</button>
        <span id="apiStatus" style="font-size:11px;color:var(--muted)">Not configured</span>
      </div>
    </div>
  </div>
  <div id="accountsView" class="results hidden" style="height:100%">
    <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(340px, 1fr));height:100%;padding:18px;gap:18px;min-height:0;overflow:auto">
      <div style="background:var(--sidebar);border:1px solid var(--line-soft);border-radius:8px;padding:18px;display:flex;flex-direction:column;gap:14px;height:fit-content">
        <div class="title" style="margin-bottom:0">Roblox Developer Profile</div>
        <div id="robloxProfileCard" style="display:flex;align-items:center;gap:12px;background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:12px">
          <div style="width:48px;height:48px;border-radius:50%;background:var(--panel2);border:1px solid var(--line);overflow:hidden;display:grid;place-items:center">
            <img id="robloxAvatar" src="" style="width:100%;height:100%;display:none">
            <span id="robloxPlaceholder" style="font-size:24px;color:var(--muted)">&#x1F464;</span>
          </div>
          <div>
            <b id="robloxUser" style="display:block;font-size:15px">Not Connected</b>
            <span id="robloxMeta" style="color:var(--muted);font-size:12px">Configure cookie to sync details</span>
          </div>
        </div>
        <div style="display:flex;flex-direction:column;gap:6px" id="robloxInputGroup">
          <label style="font-size:12px;font-weight:600">.ROBLOSECURITY Cookie:</label>
          <input id="robloxCookieInput" type="password" placeholder="Paste .ROBLOSECURITY cookie...">
        </div>
        <div class="row">
          <button id="connectRoblox" class="primary">Link Roblox Account</button>
          <button id="disconnectRoblox" class="bad hidden">Disconnect</button>
          <span id="robloxActionStatus" style="font-size:11px;color:var(--muted)"></span>
        </div>
        <div id="robloxAccountsList" class="stateRows" style="margin-top:10px;border-top:1px solid var(--line-soft);padding-top:10px"></div>
      </div>
      <div style="background:var(--sidebar);border:1px solid var(--line-soft);border-radius:8px;padding:18px;display:flex;flex-direction:column;gap:14px;height:fit-content">
        <div class="title" style="margin-bottom:0">GitHub / Codex Profile</div>
        <div id="githubProfileCard" style="display:flex;align-items:center;gap:12px;background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:12px">
          <div style="width:48px;height:48px;border-radius:50%;background:var(--panel2);border:1px solid var(--line);overflow:hidden;display:grid;place-items:center">
            <img id="githubAvatar" src="" style="width:100%;height:100%;display:none">
            <span id="githubPlaceholder" style="font-size:24px;color:var(--muted)">&#x1F419;</span>
          </div>
          <div>
            <b id="githubUser" style="display:block;font-size:15px">Not Connected</b>
            <span id="githubMeta" style="color:var(--muted);font-size:12px">Configure token/account to sync repos</span>
          </div>
        </div>
        <div style="display:flex;flex-direction:column;gap:10px" id="githubInputGroup">
          <div style="display:flex;flex-direction:column;gap:6px">
            <label style="font-size:12px;font-weight:600">GitHub Personal Access Token (PAT):</label>
            <input id="githubTokenInput" type="password" placeholder="Paste GitHub PAT (repo scope)...">
          </div>
        </div>
        <div class="row" style="gap:10px">
          <button id="connectGithub" class="primary">Link with PAT</button>
          <button id="connectGithubOAuth" style="background:#24292e;color:#fff;height:34px;padding:0 12px;font-size:12px;font-weight:600;border:1px solid var(--line);border-radius:6px;cursor:pointer">Sign In with GitHub</button>
          <button id="disconnectGithub" class="bad hidden">Disconnect</button>
          <span id="githubActionStatus" style="font-size:11px;color:var(--muted)"></span>
        </div>
        <div id="githubAccountsList" class="stateRows" style="margin-top:10px;border-top:1px solid var(--line-soft);padding-top:10px"></div>
      </div>
      <div style="background:var(--sidebar);border:1px solid var(--line-soft);border-radius:8px;padding:18px;display:flex;flex-direction:column;gap:14px;height:fit-content">
        <div class="title" style="margin-bottom:0">Google / Gemini Profile</div>
        <div id="googleProfileCard" style="display:flex;align-items:center;gap:12px;background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:12px">
          <div style="width:48px;height:48px;border-radius:50%;background:var(--panel2);border:1px solid var(--line);overflow:hidden;display:grid;place-items:center">
            <img id="googleAvatar" src="" style="width:100%;height:100%;display:none">
            <span id="googlePlaceholder" style="font-size:24px;color:var(--muted)">&#x1F464;</span>
          </div>
          <div>
            <b id="googleUser" style="display:block;font-size:15px">Not Connected</b>
            <span id="googleMeta" style="color:var(--muted);font-size:12px">Configure API key or login to connect</span>
          </div>
        </div>
        <div style="display:flex;flex-direction:column;gap:10px" id="googleInputGroup">
          <div style="display:flex;flex-direction:column;gap:6px">
            <label style="font-size:12px;font-weight:600">Gemini API Key:</label>
            <input id="googleTokenInput" type="password" placeholder="Paste Gemini API Key...">
          </div>
          <div style="display:flex;flex-direction:column;gap:6px">
            <label style="font-size:12px;font-weight:600">Account Name / Label (Optional):</label>
            <input id="googleLabelInput" type="text" placeholder="e.g. My Primary Gemini Key">
          </div>
        </div>
        <div class="row" style="gap:10px">
          <button id="connectGoogle" class="primary">Link with API Key</button>
          <button id="connectGoogleOAuth" style="background:#4285f4;color:#fff;height:34px;padding:0 12px;font-size:12px;font-weight:600;border:none;border-radius:6px;cursor:pointer">Sign In with Google</button>
          <button id="disconnectGoogle" class="bad hidden">Disconnect</button>
          <span id="googleActionStatus" style="font-size:11px;color:var(--muted)"></span>
        </div>
        <div id="googleAccountsList" class="stateRows" style="margin-top:10px;border-top:1px solid var(--line-soft);padding-top:10px"></div>
      </div>
      <div style="background:var(--sidebar);border:1px solid var(--line-soft);border-radius:8px;padding:18px;display:flex;flex-direction:column;gap:14px;height:fit-content">
        <div class="title" style="margin-bottom:0">OpenAI Profile</div>
        <div id="openaiProfileCard" style="display:flex;align-items:center;gap:12px;background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:12px">
          <div style="width:48px;height:48px;border-radius:50%;background:var(--panel2);border:1px solid var(--line);overflow:hidden;display:grid;place-items:center">
            <span id="openaiPlaceholder" style="font-size:24px;color:var(--muted)">&#x1F9E0;</span>
          </div>
          <div>
            <b id="openaiUser" style="display:block;font-size:15px">Not Connected</b>
            <span id="openaiMeta" style="color:var(--muted);font-size:12px">Configure API key to use official GPT models</span>
          </div>
        </div>
        <div style="display:flex;flex-direction:column;gap:10px" id="openaiInputGroup">
          <div style="display:flex;flex-direction:column;gap:6px">
            <label style="font-size:12px;font-weight:600">OpenAI API Key:</label>
            <input id="openaiTokenInput" type="password" placeholder="Paste OpenAI API Key...">
          </div>
          <div style="display:flex;flex-direction:column;gap:6px">
            <label style="font-size:12px;font-weight:600">Account Name / Label (Optional):</label>
            <input id="openaiLabelInput" type="text" placeholder="e.g. OpenAI Dev Key">
          </div>
        </div>
        <div class="row" style="gap:10px">
          <button id="connectOpenai" class="primary">Link with API Key</button>
          <button id="disconnectOpenai" class="bad hidden">Disconnect</button>
          <span id="openaiActionStatus" style="font-size:11px;color:var(--muted)"></span>
        </div>
        <div id="openaiAccountsList" class="stateRows" style="margin-top:10px;border-top:1px solid var(--line-soft);padding-top:10px"></div>
      </div>
      <div style="background:var(--sidebar);border:1px solid var(--line-soft);border-radius:8px;padding:18px;display:flex;flex-direction:column;gap:14px;height:fit-content">
        <div class="title" style="margin-bottom:0">Developer OAuth Settings</div>
        <div class="meta" style="color:var(--muted);font-size:11px;line-height:1.4">Configure OAuth Client IDs and Secrets to enable direct "Sign In" buttons. Register application redirect to: <code style="background:var(--panel);padding:2px 4px;border-radius:3px">http://localhost:8080/api/auth/[google|github]/callback</code>.</div>
        <div style="display:flex;flex-direction:column;gap:8px">
          <div style="display:flex;flex-direction:column;gap:4px">
            <label style="font-size:10px;font-weight:600">Google Client ID:</label>
            <input id="oauthGoogleClientId" type="text" placeholder="Enter Google Client ID..." style="height:26px;padding:4px 8px;font-size:11px">
          </div>
          <div style="display:flex;flex-direction:column;gap:4px">
            <label style="font-size:10px;font-weight:600">Google Client Secret:</label>
            <input id="oauthGoogleClientSecret" type="password" placeholder="Enter Google Client Secret..." style="height:26px;padding:4px 8px;font-size:11px">
          </div>
          <div style="display:flex;flex-direction:column;gap:4px">
            <label style="font-size:10px;font-weight:600">GitHub Client ID:</label>
            <input id="oauthGithubClientId" type="text" placeholder="Enter GitHub Client ID..." style="height:26px;padding:4px 8px;font-size:11px">
          </div>
          <div style="display:flex;flex-direction:column;gap:4px">
            <label style="font-size:10px;font-weight:600">GitHub Client Secret:</label>
            <input id="oauthGithubClientSecret" type="password" placeholder="Enter GitHub Client Secret..." style="height:26px;padding:4px 8px;font-size:11px">
          </div>
        </div>
        <div class="row">
          <button id="saveOauthConfig" class="primary" style="height:28px;padding:0 10px;font-size:11px">Save Developer Credentials</button>
          <span id="oauthConfigStatus" style="font-size:11px;color:var(--muted)"></span>
        </div>
      </div>
    </div>
  </div>
  <div id="mcpView" class="results hidden" style="height:100%">
    <div style="display:grid;grid-template-columns:repeat(auto-fit, minmax(340px, 1fr));height:100%;padding:18px;gap:18px;min-height:0;overflow:auto">
      <div style="background:var(--sidebar);border:1px solid var(--line-soft);border-radius:8px;padding:18px;display:flex;flex-direction:column;gap:14px;height:fit-content">
        <div class="title" style="margin-bottom:0">Antigravity MCP Bridge</div>
        <div style="display:flex;align-items:center;gap:12px;background:var(--panel);border:1px solid var(--line-soft);border-radius:6px;padding:12px">
          <div style="width:48px;height:48px;border-radius:50%;background:var(--panel2);border:1px solid var(--line);overflow:hidden;display:grid;place-items:center">
            <span id="mcpDot" class="dot bad" style="width:16px;height:16px;margin:0"></span>
          </div>
          <div>
            <b id="mcpStatusText" style="display:block;font-size:15px">Bridge Inactive</b>
            <span id="mcpMeta" style="color:var(--muted);font-size:12px">Launch python bridge to connect agent.</span>
          </div>
        </div>
        <div class="meta" style="color:var(--muted);font-size:11px;line-height:1.4">
          Antigravity runs the bridge locally as a stdio server. Start it via:
          <pre style="background:var(--panel);padding:6px;border-radius:4px;overflow-x:auto;margin:6px 0;font:11px Consolas,monospace">python antigravity_mcp.py</pre>
          Make sure your AI client is configured with this command in its MCP settings.
        </div>
      </div>
      <div style="background:var(--sidebar);border:1px solid var(--line-soft);border-radius:8px;padding:18px;display:flex;flex-direction:column;gap:14px;height:fit-content">
        <div class="title" style="margin-bottom:0">Detected IDE Environments</div>
        <div id="detectedIdesList" class="stateRows" style="margin-top:4px">
          <div style="font-size:11px;color:var(--muted)">Scanning for IDEs...</div>
        </div>
      </div>
      <div style="background:var(--sidebar);border:1px solid var(--line-soft);border-radius:8px;padding:18px;display:flex;flex-direction:column;gap:14px;height:fit-content">
        <div class="title" style="margin-bottom:0">AI Agent System Prompt Instruction</div>
        <div class="meta" style="color:var(--muted);font-size:11px;line-height:1.4">
          To force the AI Agent to remember to call these tools, add this system instruction to the agent prompt or client configurations:
          <textarea readonly id="mcpSystemPromptText" style="margin-top:6px;font:11px Consolas,monospace;height:120px;resize:none">You are pair programming on a Roblox project. A local DEX++ Helper Server is running.
You MUST prioritize calling the local MCP tools:
- dex_helper_status
- dex_worker_status
- dex_toolchain_status
- dex_index_status
- dex_analyze_source
- dex_analyze_remotes
To analyze Roblox scripts and sync with the Roblox Studio workspace.</textarea>
          <button id="copyMcpPrompt" style="margin-top:6px;width:100%" class="primary">Copy prompt</button>
        </div>
      </div>
    </div>
  </div>
  <div id="helpView" class="results hidden">
    <div class="hit"><h3>First run guide</h3>
      <div class="steps">
        <div class="step"><b>1</b><div>Start <code>DEX_Helper.exe</code>. The top-left status should say active and Script delivery should say ready.</div></div>
        <div class="step"><b>2</b><div>Copy the loadstring from the sidebar and run it in Roblox. The Roblox session card should switch from waiting to connected.</div></div>
        <div class="step"><b>3</b><div>Open <code>Search Center</code> in DEX. Keep <code>Low ON</code> for smooth sessions, or use Full only when you can tolerate stutter.</div></div>
        <div class="step"><b>4</b><div>Press <code>Index</code>. This dashboard will show the exact game, progress, cached scripts, failed scripts, and helper index size.</div></div>
        <div class="step"><b>5</b><div>Search here after the index has source. This keeps browsing, ranking, and analysis outside the Roblox UI.</div></div>
      </div>
    </div>
  </div>
</section>
</main>
<script>
const $=id=>document.getElementById(id);
const fmt=n=>Number(n||0).toLocaleString();
function setStatus(text, cls){const p=$('statusPill');p.textContent=text;p.className='pill '+(cls||'')}
async function textFetch(path, opts={}){const r=await fetch(path,opts);const t=await r.text();if(!r.ok)throw new Error(t||r.statusText);return t}
async function refreshStatus(){try{await textFetch('/status');setStatus('active','ok');const raw=await textFetch('/index-status');const j=JSON.parse(raw);$('scripts').textContent=fmt(j.scripts);$('bytes').textContent=fmt(j.bytes)}catch(e){setStatus('offline','bad')}}
async function refreshScriptStatus(){try{const raw=await textFetch('/script-status');const j=JSON.parse(raw);const ok=!!j.ok;$('scriptDot').className='dot '+(ok?'ok':'bad');$('scriptPill').textContent=ok?'script ready':'script missing';$('scriptPill').className='pill '+(ok?'ok':'bad');$('scriptStatus').textContent=ok?`/script is ready (${fmt(j.bytes)} bytes from ${j.file}).`:'DEX++_compiled.luau was not found. Run python .\\build.py first.'}catch(e){$('scriptDot').className='dot bad';$('scriptPill').textContent='script error';$('scriptPill').className='pill bad';$('scriptStatus').textContent=e.message}}
async function refreshWorkers(){try{const raw=await textFetch('/worker-status');const j=JSON.parse(raw);const roles=j.roles||[];$('workerRoles').innerHTML=roles.map(r=>`<div class="stateRow"><b>${esc(r.language)} <span class="${r.ready?'ok':'warn'}" style="display:inline">${r.ready?'ready':'source only'}</span></b><span>${esc(r.role||'')}</span></div>`).join('')||'<div class="stateRow"><b>No workers reported</b><span>Helper did not return role data.</span></div>'}catch(e){$('workerRoles').innerHTML='<div class="stateRow"><b class="bad">Worker status failed</b><span>'+esc(e.message)+'</span></div>'}}
async function refreshToolchain(){try{const raw=await textFetch('/toolchain-status');const j=JSON.parse(raw);const tools=j.tools||{};const labels={python:'Python',cargo:'Cargo / Rust',gpp:'g++',winget:'winget',rustWorker:'Rust worker'};$('toolchainStatus').innerHTML=Object.entries(tools).map(([id,t])=>`<div class="stateRow"><b>${esc(labels[id]||id)} <span class="${t.available?'ok':'warn'}" style="display:inline">${t.available?'available':'missing'}</span></b><span>${esc(t.purpose||'')}</span></div>`).join('');$('openToolchainSetup').disabled=!j.setupAvailable;$('openToolchainSetup').textContent=j.setupAvailable?'Install / update tools':'Setup utility not built'}catch(e){$('toolchainStatus').innerHTML='<div class="stateRow"><b class="bad">Toolchain check failed</b><span>'+esc(e.message)+'</span></div>'}}
function pct(v){const n=Math.max(0,Math.min(1,Number(v||0)));return Math.round(n*100)}
function ago(ts){const n=Number(ts||0);if(!n)return 'never';const d=Math.max(0,Date.now()/1000-n);if(d<3)return 'now';if(d<60)return `${Math.floor(d)}s ago`;if(d<3600)return `${Math.floor(d/60)}m ago`;return `${Math.floor(d/3600)}h ago`}
function toolLine(name,t){const progress=t.Progress!==undefined?pct(t.Progress):null;const cls=t.Load==='high'?'bad':(t.Load==='medium'||t.Load==='variable'?'warn':'ok');let meta=`${t.State||'unknown'} | load ${t.Load||'n/a'} | updated ${ago(t.UpdatedWallAt||0)}`;if(t.Total!==undefined)meta+=` | ${progress}% | ${fmt(t.Cached)} cached | ${fmt(t.Decompiled)} new | ${fmt(t.Skipped)} skipped | ${fmt(t.Failed)} failed`;else if(name==='Remote Spy')meta+=` | ${fmt(t.Remotes)} remotes | ${fmt(t.Logs)} logs | ${fmt(t.Dropped)} dropped`;else if(name==='Property Tracker')meta+=` | ${fmt(t.Tracked)} objects | ${fmt(t.Properties)} props | ${fmt(t.Logs)} logs`;else if(name==='Thread Manager')meta+=` | ${fmt(t.Scripts)} scripts | ${fmt(t.Threads)} threads`;return `<div class="stateRow"><b>${esc(name)} <span class="${cls}" style="display:inline">${esc(t.State||'')}</span></b><span>${esc(meta)}</span>${progress!==null?`<div class="bar"><i style="width:${progress}%"></i></div>`:''}</div>`}
function updateSession(j){const game=j.game||{};const session=j.session||{};const connected=session.state==='connected'||Object.keys(j.tools||{}).length>0;$('dexDot').className='dot '+(connected?'ok':'warn');$('dexPill').textContent=connected?'Roblox connected':'Roblox waiting';$('dexPill').className='pill '+(connected?'ok':'warn');$('gameName').textContent=game.Name||'Waiting for DEX';$('gameMeta').textContent=game.PlaceId?`Place ${game.PlaceId} | Game ${game.GameId||'?'} | Job ${game.JobId||'?'} | ${session.executor||'executor unknown'}`:'Run the loadstring in Roblox to connect this dashboard.';const cs=(j.tools||{})['Code Search'];if(cs&&cs.State){const progress=cs.Progress!==undefined?` ${pct(cs.Progress)}%`:'';$('indexTarget').textContent=`Code Search: ${cs.State}${progress}`;$('indexMeta').textContent=`${fmt(cs.Cached)} cached | ${fmt(cs.Decompiled)} new | ${fmt(cs.Skipped)} skipped | ${fmt(cs.Failed)} failed | helper ${fmt(cs.HelperIndexed)}`}else{$('indexTarget').textContent='No active index';$('indexMeta').textContent='Code Search > Index Scripts will show progress here.'}}
async function refreshToolState(){try{const raw=await textFetch('/tool-state');const j=JSON.parse(raw);updateSession(j);const tools=j.tools||{};const names=Object.keys(tools).sort((a,b)=>Number(tools[b].UpdatedAt||0)-Number(tools[a].UpdatedAt||0));$('liveDex').innerHTML=names.length?names.slice(0,6).map(n=>toolLine(n,tools[n]||{})).join(''):'<div class="stateRow"><b>No live tool state</b><span>DEX has not reported yet.</span></div>'}catch(e){$('liveDex').innerHTML='<div class="stateRow"><b class="bad">Live state unavailable</b><span>'+esc(e.message)+'</span></div>'}}
function show(view){
  document.querySelectorAll('.tab').forEach(b=>b.classList.toggle('active',b.dataset.view===view));
  ['resultsView','analysisView','remoteView','helpView','aiChatView','accountsView','mcpView'].forEach(id=>$(id).classList.toggle('hidden',id!==view));
  if(view==='mcpView')refreshIdes();
}

async function refreshIdes() {
  try {
    const raw = await textFetch('/api/detect-ides');
    const j = JSON.parse(raw);
    
    const active = !!j.mcpActive;
    $('mcpDot').className = 'dot ' + (active ? 'ok' : 'bad');
    $('mcpStatusText').textContent = active ? 'Bridge Active (Connected)' : 'Bridge Inactive';
    $('mcpMeta').textContent = active ? 'Antigravity AI Agent is connected via MCP.' : 'Launch python bridge to connect agent.';
    
    const ides = j.ides || [];
    if (ides.length === 0) {
      $('detectedIdesList').innerHTML = `<div style="font-size:11px;color:var(--muted)">No running IDE processes detected.</div>`;
    } else {
      $('detectedIdesList').innerHTML = ides.map(ide => `
        <div style="display:flex;align-items:center;justify-content:space-between;background:var(--panel);border:1px solid var(--line-soft);border-radius:4px;padding:6px 8px">
          <div style="display:flex;align-items:center;gap:8px">
            <span class="dot ok" style="margin:0"></span>
            <span style="font-size:12px;font-weight:bold">${esc(ide)}</span>
          </div>
          <span style="font-size:10px;color:var(--accent);font-weight:600">Running</span>
        </div>
      `).join('');
    }
  } catch (e) {
    console.error('Failed to detect IDEs:', e);
    $('detectedIdesList').innerHTML = `<div style="font-size:11px;color:var(--bad)">Scan failed: ${esc(e.message)}</div>`;
  }
}

setTimeout(() => {
  const btn = $('copyMcpPrompt');
  if (btn) {
    btn.onclick = () => {
      $('mcpSystemPromptText').select();
      document.execCommand('copy');
      btn.textContent = 'Copied!';
      setTimeout(() => btn.textContent = 'Copy prompt', 2000);
    };
  }
}, 500);

setInterval(() => {
  const mcp = $('mcpView');
  if (mcp && !mcp.classList.contains('hidden')) {
    refreshIdes();
  }
}, 3000);
let searchResults=[];
let selectedResultKey='';
function resultItemHtml(item){const active=item.key===selectedResultKey?' active':'';return `<button class="resultItem${active}" data-result-key="${esc(item.key||'')}"><h3>${esc(item.name||item.key||'script')} <span class="muted">[${esc(item.className||'')}]</span></h3><div class="meta">${esc(item.path||'')}</div><div class="meta">${esc(item.matchType||'hit')} | score ${esc(item.score||0)} | confidence ${Math.round(Number(item.confidence||0)*100)}%</div></button>`}
function renderResultList(total){$('resultList').innerHTML=`<div class="resultSummary">${fmt(total)} result${Number(total)===1?'':'s'} | ${fmt(searchResults.length)} shown</div>`+(searchResults.map(resultItemHtml).join('')||'<div class="hit"><h3>No results</h3><div class="meta">Try a path, remote name, require target, or identifier.</div></div>');document.querySelectorAll('[data-result-key]').forEach(button=>button.onclick=()=>selectResult(button.dataset.resultKey))}
async function copyText(text,button,label){try{await navigator.clipboard.writeText(text);button.textContent='Copied';setTimeout(()=>button.textContent=label,900)}catch(e){button.textContent='Copy failed';setTimeout(()=>button.textContent=label,900)}}
async function selectResult(key){selectedResultKey=key;renderResultList(searchResults.length);const item=searchResults.find(entry=>entry.key===key);if(!item)return;$('resultInspector').innerHTML=`<div class="inspectorHead"><h2>${esc(item.name||item.key)}</h2><div class="meta">${esc(item.path||'')}</div></div><div class="inspectorActions"><button disabled>Loading source...</button></div><div class="emptyInspector">Select a script to preview its source and use quick actions.</div>`;try{const raw=await textFetch('/index-entry',{method:'POST',headers:{'Content-Type':'text/plain'},body:key});const entry=JSON.parse(raw);if(!entry.ok)throw new Error(entry.error||'Script unavailable');$('resultInspector').innerHTML=`<div class="inspectorHead"><h2>${esc(entry.name||entry.key)} <span class="muted">[${esc(entry.className||'')}]</span></h2><div class="meta">${esc(entry.path||'')}</div></div><div class="inspectorActions"><button id="copyResultPath">Copy path</button><button id="copyResultSource" class="primary">Copy source</button><button id="analyzeResult">Analyze</button><button id="askAiResult" style="border-color:var(--accent);color:var(--accent)">Ask AI</button><button id="aiExplainResult">Explain</button><button id="aiAuditResult">Audit Security</button><span id="resultActionStatus" class="actionStatus">${fmt((entry.source||'').length)} chars</span></div><pre class="sourcePreview">${esc(entry.source||'-- Empty source')}</pre>`;$('copyResultPath').onclick=event=>copyText(entry.path||'',event.currentTarget,'Copy path');$('copyResultSource').onclick=event=>copyText(entry.source||'',event.currentTarget,'Copy source');$('analyzeResult').onclick=()=>{show('analysisView');$('sourceBox').value=entry.source||'';$('analyze').click()};$('askAiResult').onclick=()=>{show('aiChatView');$('chatInput').value=`What does this script do? Path: ${entry.path}`;activeScriptContext=entry};$('aiExplainResult').onclick=()=>{show('aiChatView');activeScriptContext=entry;sendAiPrompt(`Explain the logic, architectural design, and flow of this script:\nPath: ${entry.path}\nName: ${entry.name}\nSource:\n\`\`\`luau\n${entry.source}\n\`\`\``)};$('aiAuditResult').onclick=()=>{show('aiChatView');activeScriptContext=entry;sendAiPrompt(`Perform a rigorous security audit of the following script. Scan for backdoors, potential remote event vulnerabilities, security exploits, or unsafe coding practices:\nPath: ${entry.path}\nName: ${entry.name}\nSource:\n\`\`\`luau\n${entry.source}\n\`\`\``)};}catch(e){$('resultInspector').innerHTML=`<div class="emptyInspector"><div><b class="bad">Could not load script</b><br>${esc(e.message)}</div></div>`}}
function remoteHtml(item){const methods=Object.entries(item.methods||{}).map(([k,v])=>`${k}:${v}`).join(' ');const flags=(item.flags||[]).join(', ')||'none';const samples=(item.samples||[]).map(s=>`- ${s}`).join('\n');return `<div class="hit"><h3>${esc(item.path)} <span class="${Number(item.risk||0)>0?'warn':'ok'}">risk ${esc(item.risk||0)}</span></h3><div class="meta">calls ${esc(item.calls||0)} | out ${esc(item.outgoing||0)} | in ${esc(item.incoming||0)} | ${esc(methods)}</div><div class="meta">flags: ${esc(flags)}</div><pre>${esc(samples||'no args sample')}</pre></div>`}
function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}

function formatMarkdownToHtml(md) {
  if (!md) return '';
  let html = esc(md);
  
  // Fenced Code Blocks (e.g. ```luau ... ```)
  html = html.replace(/```(?:[a-zA-Z0-9_\-\+\#]+)?\n([\s\S]*?)\n```/g, (match, code) => {
    return `<pre style="background:var(--panel2);border:1px solid var(--line);border-radius:6px;padding:10px;overflow-x:auto;margin:8px 0;font-family:Consolas,monospace;font-size:12px;color:#dce4ea"><code style="white-space:pre">${code}</code></pre>`;
  });
  
  // Inline code (e.g. `code`)
  html = html.replace(/`([^`]+)`/g, '<code style="background:var(--panel2);padding:2px 5px;border-radius:4px;font-family:Consolas,monospace;font-size:11px;color:var(--accent2)">$1</code>');
  
  // Bold (e.g. **text**)
  html = html.replace(/\*\*([^*]+)\*\*/g, '<strong style="color:white">$1</strong>');
  
  // Bullet lists (lines starting with - or * )
  let lines = html.split('\n');
  let inList = false;
  for (let i = 0; i < lines.length; i++) {
    let line = lines[i].trim();
    if (line.startsWith('- ') || line.startsWith('* ')) {
      let content = line.substring(2);
      if (!inList) {
        lines[i] = `<ul style="margin:6px 0;padding-left:20px;list-style-type:disc"><li style="margin:4px 0">${content}</li>`;
        inList = true;
      } else {
        lines[i] = `<li style="margin:4px 0">${content}</li>`;
      }
    } else {
      if (inList) {
        lines[i - 1] += '</ul>';
        inList = false;
      }
    }
  }
  if (inList) {
    lines[lines.length - 1] += '</ul>';
  }
  html = lines.join('\n');
  
  // Line breaks outside <pre>
  let parts = html.split(/(<pre[\s\S]*?<\/pre>)/g);
  for (let i = 0; i < parts.length; i++) {
    if (!parts[i].startsWith('<pre')) {
      parts[i] = parts[i].replace(/\n/g, '<br>');
    }
  }
  html = parts.join('');
  
  return `<div style="margin:6px 0 0;font-size:12.5px;line-height:1.5;color:var(--text-soft)">${html}</div>`;
}

function appendChatMessage(sender, text, formatMarkdown) {
  const container = $('chatHistory');
  if (!container) return;
  
  const msgDiv = document.createElement('div');
  msgDiv.className = 'hit';
  
  let titleColor = 'var(--text)';
  if (sender === 'You') {
    titleColor = 'var(--accent)';
  } else if (sender === 'System') {
    titleColor = '#ef4444';
  } else {
    titleColor = '#52b69a';
  }
  
  let contentHtml = '';
  if (formatMarkdown) {
    contentHtml = formatMarkdownToHtml(text);
  } else {
    contentHtml = `<pre style="margin:4px 0 0;white-space:pre-wrap;font-family:inherit;color:var(--text-soft)">${esc(text)}</pre>`;
  }
  
  msgDiv.innerHTML = `<h3 style="color:${titleColor};margin:0;font-size:13px">${esc(sender)}</h3>${contentHtml}`;
  container.appendChild(msgDiv);
  container.scrollTop = container.scrollHeight;
}

// AI Chat & Accounts Integrations
let aiProvider = localStorage.getItem('dex_ai_provider') || 'gemini';
let aiApiUrl = localStorage.getItem('dex_ai_api_url') || 'http://localhost:20128/v1';
let aiModel = localStorage.getItem('dex_ai_model') || 'gemini-1.5-flash';
let activeScriptContext = null;
let aiChatHistory = [];

async function getAuthTokens() {
  try {
    const raw = await textFetch('/api/auth/tokens');
    return JSON.parse(raw);
  } catch(e) {
    return { googleToken: '', githubToken: '', openaiToken: '', googleMethod: 'apikey', githubMethod: 'apikey', openaiMethod: 'apikey' };
  }
}

async function sendAiPrompt(promptText) {
  appendChatMessage('You', promptText, false);
  await sendAiPromptInternal(promptText, new Set());
}

async function sendAiPromptInternal(promptText, triedIndices) {
  const indicator = document.createElement('div');
  const providerLabel = aiProvider === 'gemini' ? 'DEX++ AI Assistant (Gemini)' : (aiProvider === 'openai' ? 'DEX++ AI Assistant (OpenAI)' : (aiProvider === 'github_models' ? 'DEX++ AI Assistant (GitHub Models)' : `DEX++ AI Assistant (${aiModel})`));
  indicator.className = 'hit';
  indicator.id = 'aiTypingIndicator';
  indicator.innerHTML = `<h3>${providerLabel}</h3><pre style="margin:4px 0 0;color:var(--muted)">Thinking...</pre>`;
  $('chatHistory').appendChild(indicator);
  $('chatHistory').scrollTop = $('chatHistory').scrollHeight;
  try {
    let systemInstructions = "You are the DEX++ AI Co-pilot, an expert Roblox reverse engineer and cybersecurity analyst. Analyze decompiled Luau/Roblox scripts, look for backdoors, exploits, or explain script functionalities. Answer clearly and format code snippets in markdown code blocks.";
    
    const tokens = await getAuthTokens();
    
    const accountProviderMap = {
      gemini: 'google',
      openai: 'openai',
      github_models: 'github'
    };
    const listName = accountProviderMap[aiProvider];
    
    let activeIdx = -1;
    if (listName && globalAccounts[listName]) {
      activeIdx = globalAccounts[listName].findIndex(a => a.isActive);
      if (activeIdx === -1 && globalAccounts[listName].length > 0) activeIdx = 0;
      if (activeIdx !== -1) triedIndices.add(activeIdx);
    }
    
    let response;
    if (aiProvider === 'gemini') {
      const activeKey = tokens.googleToken;
      if (!activeKey) {
        throw new Error('No Google credentials active. Go to the Accounts tab to configure your Gemini API Key or sign in with Google.');
      }
      
      const contentsPayload = [];
      for (const turns of aiChatHistory) {
        contentsPayload.push(turns);
      }
      contentsPayload.push({
        role: 'user',
        parts: [{ text: promptText }]
      });
      const requestBody = {
        contents: contentsPayload,
        systemInstruction: {
          parts: [{ text: systemInstructions }]
        },
        generationConfig: {
          temperature: 0.2
        }
      };
      
      let url = `https://generativelanguage.googleapis.com/v1beta/models/${aiModel || 'gemini-3.5-flash'}:generateContent`;
      const headers = { 'Content-Type': 'application/json' };
      if (tokens.googleMethod === 'oauth') {
        headers['Authorization'] = `Bearer ${activeKey}`;
      } else {
        url += `?key=${activeKey}`;
      }
      
      response = await fetch(url, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(requestBody)
      });
    } else if (aiProvider === 'openai') {
      const activeKey = tokens.openaiToken;
      if (!activeKey) {
        throw new Error('No OpenAI credentials active. Go to the Accounts tab to configure your OpenAI API Key.');
      }
      
      const messages = [{ role: 'system', content: systemInstructions }];
      for (const turns of aiChatHistory) {
        const isModel = turns.role === 'model';
        messages.push({
          role: isModel ? 'assistant' : turns.role,
          content: turns.parts && turns.parts[0] ? turns.parts[0].text : (turns.content || '')
        });
      }
      messages.push({ role: 'user', content: promptText });
      
      const requestBody = {
        model: aiModel || 'gpt-4o',
        messages: messages,
        temperature: 0.2
      };
      
      const url = `https://api.openai.com/v1/chat/completions`;
      response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${activeKey}`
        },
        body: JSON.stringify(requestBody)
      });
    } else if (aiProvider === 'github_models') {
      const activeKey = tokens.githubToken;
      if (!activeKey) {
        throw new Error('No GitHub credentials active. Go to the Accounts tab to configure your GitHub PAT or sign in with GitHub.');
      }
      
      const messages = [{ role: 'system', content: systemInstructions }];
      for (const turns of aiChatHistory) {
        const isModel = turns.role === 'model';
        messages.push({
          role: isModel ? 'assistant' : turns.role,
          content: turns.parts && turns.parts[0] ? turns.parts[0].text : (turns.content || '')
        });
      }
      messages.push({ role: 'user', content: promptText });
      
      const requestBody = {
        model: aiModel || 'gpt-4o',
        messages: messages,
        temperature: 0.2
      };
      
      const url = `https://models.github.ai/inference/chat/completions`;
      response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${activeKey}`
        },
        body: JSON.stringify(requestBody)
      });
    } else {
      const customKey = localStorage.getItem('dex_ai_api_key') || '';
      const messages = [{ role: 'system', content: systemInstructions }];
      for (const turns of aiChatHistory) {
        const isModel = turns.role === 'model';
        messages.push({
          role: isModel ? 'assistant' : turns.role,
          content: turns.parts && turns.parts[0] ? turns.parts[0].text : (turns.content || '')
        });
      }
      messages.push({ role: 'user', content: promptText });
      
      const requestBody = {
        model: aiModel,
        messages: messages,
        temperature: 0.2
      };
      
      let baseUrl = aiApiUrl.trim();
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.slice(0, -1);
      const url = `${baseUrl}/chat/completions`;
      
      const headers = { 'Content-Type': 'application/json' };
      if (customKey) {
        headers['Authorization'] = `Bearer ${customKey}`;
      }
      
      response = await fetch(url, {
        method: 'POST',
        headers: headers,
        body: JSON.stringify(requestBody)
      });
    }
    
    if (response.status === 429 && listName && globalAccounts[listName]) {
      const list = globalAccounts[listName];
      let nextIdx = -1;
      for (let i = 0; i < list.length; i++) {
        if (!triedIndices.has(i)) {
          nextIdx = i;
          break;
        }
      }
      
      if (nextIdx !== -1) {
        const nextAccount = list[nextIdx];
        const accountName = nextAccount.displayName || nextAccount.username || nextAccount.login || nextAccount.name || `Account #${nextIdx + 1}`;
        
        const ind = $('aiTypingIndicator');
        if (ind) ind.remove();
        
        appendChatMessage('System', `Quota limit reached on current account. Auto-switching to "${accountName}" and retrying request...`, false);
        
        list.forEach((a, idx) => { a.isActive = (idx === nextIdx); });
        await saveAccountsList();
        
        try {
          await textFetch('/api/auth/active-token', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              provider: listName,
              token: nextAccount.token,
              type: nextAccount.type || 'apikey'
            })
          });
        } catch (e) {
          console.error('Failed to sync active token:', e);
        }
        
        loadProfiles();
        
        return sendAiPromptInternal(promptText, triedIndices);
      } else {
        appendChatMessage('System', 'All available accounts for this provider have reached their quota limits.', false);
      }
    }
    
    const data = await response.json();
    const ind = $('aiTypingIndicator');
    if (ind) ind.remove();
    
    if (response.ok) {
      let replyText = '';
      if (aiProvider === 'gemini') {
        if (data.candidates && data.candidates[0] && data.candidates[0].content && data.candidates[0].content.parts[0]) {
          replyText = data.candidates[0].content.parts[0].text;
        } else {
          throw new Error('Invalid Gemini API response structure');
        }
      } else {
        if (data.choices && data.choices[0] && data.choices[0].message) {
          replyText = data.choices[0].message.content;
        } else {
          throw new Error('Invalid OpenAI API response structure');
        }
      }
      
      appendChatMessage(providerLabel, replyText, true);
      
      if (aiProvider === 'gemini') {
        aiChatHistory.push({
          role: 'user',
          parts: [{ text: promptText }]
        });
        aiChatHistory.push({
          role: 'model',
          parts: [{ text: replyText }]
        });
      } else {
        aiChatHistory.push({
          role: 'user',
          content: promptText
        });
        aiChatHistory.push({
          role: 'model',
          content: replyText
        });
      }
      
      if (aiChatHistory.length > 20) {
        aiChatHistory.shift();
        aiChatHistory.shift();
      }
    } else {
      const errMsg = data.error ? (data.error.message || JSON.stringify(data.error)) : 'Unknown API response error';
      appendChatMessage('System', `Error from AI API: ${errMsg}`, false);
    }
  } catch (e) {
    const ind = $('aiTypingIndicator');
    if (ind) ind.remove();
    appendChatMessage('System', `Connection error: ${e.message}`, false);
  }
}

const providerModels = {
  gemini: [
    { value: 'gemini-3.5-flash', label: 'Gemini 3.5 Flash (Recommended)' },
    { value: 'gemini-3.5-pro', label: 'Gemini 3.5 Pro' },
    { value: 'gemini-2.5-flash', label: 'Gemini 2.5 Flash' },
    { value: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash' },
    { value: 'gemini-1.5-flash', label: 'Gemini 1.5 Flash' },
    { value: 'gemini-1.5-pro', label: 'Gemini 1.5 Pro' }
  ],
  openai: [
    { value: 'gpt-4o', label: 'GPT-4o (Recommended)' },
    { value: 'gpt-4o-mini', label: 'GPT-4o Mini (Fast)' },
    { value: 'o3-mini', label: 'o3-mini (Reasoning Fast)' },
    { value: 'o1', label: 'o1 (Reasoning)' }
  ],
  github_models: [
    { value: 'gpt-4o', label: 'GPT-4o (Default)' },
    { value: 'gpt-4o-mini', label: 'GPT-4o Mini (Fast)' },
    { value: 'meta-llama-3.3-70b-instruct', label: 'Llama 3.3 70B' },
    { value: 'meta-llama-3.1-405b-instruct', label: 'Llama 3.1 405B' }
  ],
  openai_compatible: [
    { value: 'google/gemini-3.5-flash', label: 'Gemini 3.5 Flash' },
    { value: 'google/gemini-2.5-flash', label: 'Gemini 2.5 Flash' },
    { value: 'google/gemini-2.0-flash', label: 'Gemini 2.0 Flash' },
    { value: 'google/gemini-1.5-flash', label: 'Gemini 1.5 Flash' },
    { value: 'openai/gpt-4o', label: 'GPT-4o' },
    { value: 'openai/gpt-4o-mini', label: 'GPT-4o Mini' },
    { value: 'anthropic/claude-3-5-sonnet', label: 'Claude 3.5 Sonnet' },
    { value: 'anthropic/claude-3-5-haiku', label: 'Claude 3.5 Haiku' }
  ]
};

async function loadLatestModels(provider, tokens) {
  try {
    let fetched = [];
    if (provider === 'gemini') {
      const activeKey = tokens.googleToken;
      if (activeKey) {
        let url = 'https://generativelanguage.googleapis.com/v1beta/models';
        const headers = {};
        if (tokens.googleMethod === 'oauth') {
          headers['Authorization'] = `Bearer ${activeKey}`;
        } else {
          url += `?key=${activeKey}`;
        }
        const r = await fetch(url, { headers });
        if (r.ok) {
          const data = await r.json();
          if (data.models) {
            fetched = data.models
              .filter(m => m.supportedGenerationMethods && m.supportedGenerationMethods.includes('generateContent'))
              .map(m => {
                const val = m.name.replace('models/', '');
                return { value: val, label: m.displayName || val };
              });
          }
        }
      }
    } else if (provider === 'openai') {
      const activeKey = tokens.openaiToken;
      if (activeKey) {
        const r = await fetch('https://api.openai.com/v1/models', {
          headers: { 'Authorization': `Bearer ${activeKey}` }
        });
        if (r.ok) {
          const data = await r.json();
          if (data.data) {
            fetched = data.data
              .filter(m => m.id.startsWith('gpt-') || m.id.startsWith('o1') || m.id.startsWith('o3'))
              .map(m => ({ value: m.id, label: m.id }));
          }
        }
      }
    } else if (provider === 'github_models') {
      const activeKey = tokens.githubToken;
      if (activeKey) {
        const r = await fetch('https://models.github.ai/catalog/models', {
          headers: {
            'Authorization': `Bearer ${activeKey}`,
            'X-GitHub-Api-Version': '2022-11-28'
          }
        });
        if (r.ok) {
          const data = await r.json();
          const list = Array.isArray(data) ? data : (data.models || data.data || []);
          fetched = list.map(m => {
            const val = m.name || m.id || '';
            const friendly = m.friendlyName || m.displayName || val;
            return { value: val, label: friendly };
          }).filter(m => m.value);
        }
      }
    } else if (provider === 'openai_compatible') {
      const customKey = localStorage.getItem('dex_ai_api_key') || '';
      let baseUrl = $('apiUrlInput').value.trim() || aiApiUrl.trim();
      if (baseUrl.endsWith('/')) baseUrl = baseUrl.slice(0, -1);
      if (baseUrl) {
        const headers = {};
        if (customKey) headers['Authorization'] = `Bearer ${customKey}`;
        const r = await fetch(`${baseUrl}/models`, { headers });
        if (r.ok) {
          const data = await r.json();
          const list = data.data || data.models || [];
          fetched = list.map(m => ({ value: m.id || m.name, label: m.id || m.name })).filter(m => m.value);
        }
      }
    }
    
    if (fetched.length > 0) {
      const staticModels = providerModels[provider] || [];
      const seen = new Set(staticModels.map(m => m.value));
      const merged = [...staticModels];
      for (const m of fetched) {
        if (!seen.has(m.value)) {
          seen.add(m.value);
          merged.push(m);
        }
      }
      return merged;
    }
  } catch (e) {
    console.error('Failed to fetch latest models:', e);
  }
  return providerModels[provider] || [];
}

function renderModelOptions(currentModels) {
  $('aiModelSelect').innerHTML = currentModels.map(m => `<option value="${m.value}">${m.label}</option>`).join('') + '<option value="custom">Custom model...</option>';
}

async function updateAiSettingsVisibility() {
  const prov = $('aiProviderSelect').value;
  
  // 1. Populate immediately with static models
  let models = providerModels[prov] || [];
  renderModelOptions(models);
  
  // 2. Select default or stored model
  const defaultModel = prov === 'github_models' || prov === 'openai' ? 'gpt-4o' : (prov === 'gemini' ? 'gemini-3.5-flash' : 'google/gemini-3.5-flash');
  let storedModel = localStorage.getItem('dex_ai_model') || defaultModel;
  
  function applyModelSelection(currentModels) {
    const hasMatchingModel = currentModels.some(m => m.value === storedModel);
    if (hasMatchingModel) {
      $('aiModelSelect').value = storedModel;
      $('aiModelInput').style.display = 'none';
    } else {
      $('aiModelSelect').value = 'custom';
      $('aiModelInput').value = storedModel;
      $('aiModelInput').style.display = 'inline';
    }
  }
  
  applyModelSelection(models);
  
  // Show/hide other inputs based on provider
  if (prov === 'openai_compatible') {
    $('apiUrlLabel').style.display = 'inline';
    $('apiUrlInput').style.display = 'inline';
    $('aiModelLabel').style.display = 'inline';
    $('aiModelSelect').style.display = 'inline';
    $('apiKeyLabel').style.display = 'inline';
    $('apiKeyInput').style.display = 'inline';
  } else if (prov === 'github_models' || prov === 'openai' || prov === 'gemini') {
    $('apiUrlLabel').style.display = 'none';
    $('apiUrlInput').style.display = 'none';
    $('aiModelLabel').style.display = 'inline';
    $('aiModelSelect').style.display = 'inline';
    $('apiKeyLabel').style.display = 'none';
    $('apiKeyInput').style.display = 'none';
  } else {
    $('apiUrlLabel').style.display = 'none';
    $('apiUrlInput').style.display = 'none';
    $('aiModelLabel').style.display = 'none';
    $('aiModelSelect').style.display = 'none';
    $('aiModelInput').style.display = 'none';
    $('apiKeyLabel').style.display = 'none';
    $('apiKeyInput').style.display = 'none';
  }

  // 3. Asynchronously fetch the latest models and update if successful
  const tokens = await getAuthTokens();
  const latestModels = await loadLatestModels(prov, tokens);
  if (latestModels.length > models.length) {
    renderModelOptions(latestModels);
    applyModelSelection(latestModels);
  }
}

$('aiModelSelect').onchange = () => {
  if ($('aiModelSelect').value === 'custom') {
    $('aiModelInput').style.display = 'inline';
    $('aiModelInput').value = '';
    $('aiModelInput').focus();
  } else {
    $('aiModelInput').style.display = 'none';
  }
};

$('aiProviderSelect').value = aiProvider;
$('apiUrlInput').value = aiApiUrl;
$('aiModelInput').value = aiModel;
$('apiKeyInput').value = localStorage.getItem('dex_ai_api_key') || '';
$('aiProviderSelect').onchange = updateAiSettingsVisibility;
updateAiSettingsVisibility();

// Load AI connection status initially
async function updateAiConnectionStatus() {
  const tokens = await getAuthTokens();
  if (aiProvider === 'gemini') {
    if (tokens.googleToken) {
      $('apiStatus').innerHTML = `Google Account active (${tokens.googleMethod === 'oauth' ? 'OAuth' : 'API Key'}) | <a href="https://aistudio.google.com/" target="_blank" style="color:var(--accent);text-decoration:none">View AI Studio Quota</a>`;
      $('apiStatus').style.color = 'var(--accent2)';
    } else {
      $('apiStatus').textContent = 'Google Account not connected (see Accounts tab)';
      $('apiStatus').style.color = 'var(--muted)';
    }
  } else if (aiProvider === 'openai') {
    if (tokens.openaiToken) {
      $('apiStatus').innerHTML = `OpenAI Account active (API Key) | <a href="https://platform.openai.com/settings/organization/billing/overview" target="_blank" style="color:var(--accent);text-decoration:none">View Usage Dashboard</a>`;
      $('apiStatus').style.color = 'var(--accent2)';
    } else {
      $('apiStatus').textContent = 'OpenAI Account not connected (see Accounts tab)';
      $('apiStatus').style.color = 'var(--muted)';
    }
  } else if (aiProvider === 'github_models') {
    if (tokens.githubToken) {
      $('apiStatus').innerHTML = `GitHub Account active (${tokens.githubMethod === 'oauth' ? 'OAuth' : 'PAT'}) | <a href="https://github.com/settings/billing" target="_blank" style="color:var(--accent);text-decoration:none">View GitHub Billing</a>`;
      $('apiStatus').style.color = 'var(--accent2)';
    } else {
      $('apiStatus').textContent = 'GitHub Account not connected (see Accounts tab)';
      $('apiStatus').style.color = 'var(--muted)';
    }
  } else {
    const customKey = localStorage.getItem('dex_ai_api_key');
    if (customKey) {
      $('apiStatus').textContent = 'Custom Gateway configured';
      $('apiStatus').style.color = 'var(--accent2)';
      
      if (aiApiUrl.includes('openrouter.ai')) {
        try {
          const r = await fetch('https://openrouter.ai/api/v1/key', {
            headers: { 'Authorization': `Bearer ${customKey}` }
          });
          if (r.ok) {
            const data = await r.json();
            if (data.data) {
              const bal = data.data.limit - data.data.usage;
              const formatted = data.data.is_free_tier ? 'Free tier' : `$${bal.toFixed(4)}`;
              $('apiStatus').innerHTML = `OpenRouter active (Balance: <b>${formatted}</b>)`;
            }
          }
        } catch (e) {
          console.error('Failed to query OpenRouter quota:', e);
        }
      }
    } else {
      $('apiStatus').textContent = 'Custom Gateway has no API Key';
      $('apiStatus').style.color = 'var(--muted)';
    }
  }
}
updateAiConnectionStatus();

$('saveApiKey').onclick = () => {
  const prov = $('aiProviderSelect').value;
  const url = $('apiUrlInput').value.trim();
  const selectModel = $('aiModelSelect').value;
  const model = selectModel === 'custom' ? $('aiModelInput').value.trim() : selectModel;
  const key = $('apiKeyInput').value.trim();
  
  localStorage.setItem('dex_ai_provider', prov);
  localStorage.setItem('dex_ai_api_url', url || 'http://localhost:20128/v1');
  localStorage.setItem('dex_ai_model', model || (prov === 'github_models' || prov === 'openai' ? 'gpt-4o' : 'google/gemini-1.5-flash'));
  if (key) {
    localStorage.setItem('dex_ai_api_key', key);
  } else {
    localStorage.removeItem('dex_ai_api_key');
  }
  
  aiProvider = prov;
  aiApiUrl = url || 'http://localhost:20128/v1';
  aiModel = model || (prov === 'github_models' || prov === 'openai' ? 'gpt-4o' : 'google/gemini-1.5-flash');
  updateAiConnectionStatus();
};

$('sendChat').onclick = () => {
  const val = $('chatInput').value.trim();
  if (!val) return;
  $('chatInput').value = '';
  sendAiPrompt(val);
};

$('chatInput').addEventListener('keydown', e => {
  if (e.key === 'Enter') $('sendChat').click();
});

$('refresh').onclick=refreshStatus;
$('copyLoadstring').onclick=async()=>{const text=$('loadstringBox').textContent;try{await navigator.clipboard.writeText(text);$('copyLoadstring').textContent='Copied';setTimeout(()=>$('copyLoadstring').textContent='Copy loadstring',900)}catch(e){$('copyLoadstring').textContent='Copy failed';setTimeout(()=>$('copyLoadstring').textContent='Copy loadstring',900)}};
$('openScript').onclick=()=>window.open('/script','_blank');
$('openToolchainSetup').onclick=async()=>{try{const raw=await textFetch('/open-toolchain-setup',{method:'POST'});const j=JSON.parse(raw);if(!j.ok)throw new Error(j.error||'Setup launch failed');$('openToolchainSetup').textContent='Setup opened';setTimeout(refreshToolchain,1200)}catch(e){$('openToolchainSetup').textContent='Open failed';setTimeout(()=>$('openToolchainSetup').textContent='Install / update tools',1200)}};
$('stopLocal').onclick=async()=>{if(!confirm('Stop DEX++ Helper and Potassium Decompiler?'))return;try{await textFetch('/stop-local-services',{method:'POST'});$('stopLocal').textContent='Stopping...';setStatus('stopping','warn')}catch(e){$('stopLocal').textContent='Stop failed'}};
$('cleanLocal').onclick=async()=>{if(!confirm('Delete helper index and logs, then stop local services? DEX source cache inside the executor workspace is not deleted.'))return;try{await textFetch('/clean-local',{method:'POST'});$('cleanLocal').textContent='Cleaning...';setStatus('cleaning','warn')}catch(e){$('cleanLocal').textContent='Clean failed'}};
$('load').onclick=async()=>{await textFetch('/index-load',{method:'POST'});refreshStatus()};
$('save').onclick=async()=>{await textFetch('/index-save',{method:'POST'});refreshStatus()};
$('clear').onclick=async()=>{if(confirm('Clear helper index?')){await textFetch('/index-clear',{method:'POST'});refreshStatus();searchResults=[];selectedResultKey='';renderResultList(0);$('resultInspector').innerHTML='<div class="emptyInspector">Index cleared.</div>'}};
$('search').onclick=async()=>{const q=$('query').value.trim();if(!q)return;show('resultsView');searchResults=[];selectedResultKey='';$('resultList').innerHTML='<div class="resultSummary">Searching...</div>';$('resultInspector').innerHTML='<div class="emptyInspector">Results will open here without moving the guide or page layout.</div>';try{const raw=await textFetch('/search-source',{method:'POST',headers:{'Content-Type':'text/plain'},body:'120\n'+q});const j=JSON.parse(raw);searchResults=j.results||[];renderResultList(j.total||searchResults.length);if(searchResults.length)selectResult(searchResults[0].key);refreshStatus()}catch(e){$('resultList').innerHTML='<div class="hit"><h3 class="bad">Search failed</h3><pre>'+esc(e.message)+'</pre></div>'}};
$('query').addEventListener('keydown',e=>{if(e.key==='Enter')$('search').click()});
$('analyze').onclick=async()=>{show('analysisView');try{$('analysisOut').textContent=await textFetch('/analyze-source-auto',{method:'POST',headers:{'Content-Type':'text/plain'},body:$('sourceBox').value})}catch(e){$('analysisOut').textContent=e.message}};
$('normalize').onclick=async()=>{show('analysisView');try{$('analysisOut').textContent=await textFetch('/normalize-source',{method:'POST',headers:{'Content-Type':'text/plain'},body:$('sourceBox').value})}catch(e){$('analysisOut').textContent=e.message}};
$('remoteAnalyze').onclick=async()=>{show('remoteView');$('remoteView').innerHTML='<div class="hit"><h3>Analyzing remotes...</h3></div>';try{const raw=await textFetch('/analyze-remotes',{method:'POST',headers:{'Content-Type':'text/plain'},body:$('remoteBox').value});const j=JSON.parse(raw);const head=`<div class="hit"><h3>Remote Contract Summary</h3><div class="meta">lines ${esc(j.lines||0)} | parsed ${esc(j.parsed||0)} | remotes ${esc(j.remotes||0)}</div></div>`;$('remoteView').innerHTML=head+((j.results||[]).map(remoteHtml).join('')||'<div class="hit"><h3>No RemoteSpy lines parsed</h3></div>')}catch(e){$('remoteView').innerHTML='<div class="hit"><h3 class="bad">Remote analysis failed</h3><pre>'+esc(e.message)+'</pre></div>'}};
$('script').onclick=()=>window.open('/script','_blank');

// Accounts view logic
let globalAccounts = { roblox: [], github: [], google: [], openai: [] };

async function loadProfiles() {
  try {
    const raw = await textFetch('/api/accounts');
    if (raw.trim()) {
      globalAccounts = JSON.parse(raw);
    }
  } catch (e) {
    console.error('Failed to load accounts list:', e);
  }
  
  const tokens = await getAuthTokens();
  await Promise.all([
    loadRobloxProfile(tokens),
    loadGithubProfile(tokens),
    loadGoogleProfile(tokens),
    loadOpenaiProfile(tokens)
  ]);
  
  renderAccountsLists();
  await updateAiConnectionStatus();
}

function renderAccountsLists() {
  const providers = ['roblox', 'github', 'google', 'openai'];
  providers.forEach(prov => {
    const container = $(prov + 'AccountsList');
    if (!container) return;
    
    const list = globalAccounts[prov] || [];
    if (list.length === 0) {
      container.innerHTML = `<div style="font-size:11px;color:var(--muted)">No saved accounts in this list.</div>`;
      return;
    }
    
    let html = `<div style="font-size:11px;font-weight:600;color:var(--muted);margin-bottom:6px">Saved Profiles:</div>`;
    list.forEach((acc, index) => {
      const activeText = acc.isActive ? `<span class="pill ok" style="padding:2px 5px;font-size:9px">Active</span>` : '';
      const useBtn = !acc.isActive ? `<button style="height:22px;font-size:10px;padding:0 8px;background:var(--accent);color:#000;font-weight:bold" onclick="setActiveAccount('${prov}', ${index})">Use</button>` : '';
      const removeBtn = `<button style="height:22px;font-size:10px;padding:0 8px;margin-left:5px" class="bad" onclick="removeAccount('${prov}', ${index})">Remove</button>`;
      
      let avatar = '\u{1F464}';
      if (prov === 'github') avatar = '\u{1F419}';
      if (prov === 'openai') avatar = '\u{1F9E0}';
      
      const avatarImg = acc.avatarUrl ? `<img src="${acc.avatarUrl}" style="width:24px;height:24px;border-radius:50%">` : `<span style="font-size:16px">${avatar}</span>`;
      
      function maskToken(t) {
        if (!t) return '';
        if (t.length <= 12) return t;
        return t.substring(0, 8) + '...' + t.substring(t.length - 4);
      }
      
      let name = acc.displayName || acc.username || acc.login || acc.name || 'Account';
      
      let line1 = name;
      let line2 = '';
      const masked = maskToken(acc.token);
      
      if (prov === 'google') {
        if (acc.type === 'oauth') {
          line1 = acc.name || acc.email || 'Google OAuth Account';
          line2 = `OAuth: ${masked} (${acc.email || 'No Email'})`;
        } else {
          line1 = (acc.name && acc.name !== 'Gemini API Key') ? acc.name : 'Gemini Key';
          line2 = `Key: ${masked}`;
          if (acc.email && acc.email !== 'API Key Verification Success') {
            line2 += ` (${acc.email})`;
          }
        }
      } else if (prov === 'openai') {
        line1 = (acc.name && acc.name.indexOf('OpenAI Key (') === -1) ? acc.name : 'OpenAI Account';
        line2 = `Key: ${masked}`;
      } else if (prov === 'github') {
        line1 = acc.login || 'GitHub User';
        if (acc.type === 'oauth') {
          line2 = `OAuth: ${masked}`;
        } else {
          line2 = `PAT: ${masked}`;
        }
      } else if (prov === 'roblox') {
        line1 = acc.displayName ? `${acc.displayName} (@${acc.username})` : (acc.username || 'Roblox User');
        line2 = `ID: ${acc.userId} | Cookie: ${masked}`;
      }
      
      html += `
        <div style="display:flex;align-items:center;justify-content:space-between;background:var(--panel);border:1px solid var(--line-soft);border-radius:4px;padding:6px 8px;margin-bottom:5px">
          <div style="display:flex;align-items:center;gap:8px">
            <div style="width:24px;height:24px;border-radius:50%;background:var(--panel2);display:grid;place-items:center;overflow:hidden">
              ${avatarImg}
            </div>
            <div>
              <span style="font-size:12px;font-weight:bold">${esc(line1)}</span>
              <span style="display:block;font-size:10px;color:var(--muted)">${esc(line2)}</span>
            </div>
          </div>
          <div style="display:flex;align-items:center;gap:4px">
            ${activeText}
            ${useBtn}
            ${removeBtn}
          </div>
        </div>
      `;
    });
    container.innerHTML = html;
  });
}

function upsertAccount(provider, account) {
  if (!globalAccounts[provider]) globalAccounts[provider] = [];
  const list = globalAccounts[provider];
  
  let keyMatch = false;
  for (let i = 0; i < list.length; i++) {
    const item = list[i];
    const isRobloxMatch = provider === 'roblox' && item.userId === account.userId;
    const isGithubMatch = provider === 'github' && (
      (account.type === 'oauth' && item.type === 'oauth' && item.login === account.login) ||
      (account.type !== 'oauth' && item.type !== 'oauth' && item.token === account.token)
    );
    const isGoogleMatch = provider === 'google' && (
      (account.type === 'oauth' && item.type === 'oauth' && item.email === account.email) ||
      (account.type !== 'oauth' && item.type !== 'oauth' && item.token === account.token)
    );
    const isOpenaiMatch = provider === 'openai' && item.token === account.token;
    
    if (isRobloxMatch || isGithubMatch || isGoogleMatch || isOpenaiMatch) {
      list[i] = { ...item, ...account };
      keyMatch = true;
      break;
    }
  }
  
  if (!keyMatch) {
    list.push(account);
  }
  
  if (account.isActive) {
    list.forEach(a => {
      const isCurrentRoblox = provider === 'roblox' && a.userId === account.userId;
      const isCurrentGithub = provider === 'github' && (
        (account.type === 'oauth' && a.type === 'oauth' && a.login === account.login) ||
        (account.type !== 'oauth' && a.type !== 'oauth' && a.token === account.token)
      );
      const isCurrentGoogle = provider === 'google' && (
        (account.type === 'oauth' && a.type === 'oauth' && a.email === account.email) ||
        (account.type !== 'oauth' && a.type !== 'oauth' && a.token === account.token)
      );
      const isCurrentOpenai = provider === 'openai' && a.token === account.token;
      
      if (!isCurrentRoblox && !isCurrentGithub && !isCurrentGoogle && !isCurrentOpenai) {
        a.isActive = false;
      }
    });
  }
  
  saveAccountsList();
}

async function saveAccountsList() {
  try {
    await textFetch('/api/accounts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(globalAccounts)
    });
  } catch (e) {
    console.error('Failed to save accounts list:', e);
  }
}

async function setActiveAccount(provider, index) {
  const list = globalAccounts[provider];
  if (!list || !list[index]) return;
  
  list.forEach((a, idx) => {
    a.isActive = (idx === index);
  });
  
  const active = list[index];
  await saveAccountsList();
  
  try {
    await textFetch('/api/auth/active-token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider: provider,
        token: active.token,
        type: active.type || 'apikey'
      })
    });
  } catch (e) {
    console.error('Failed to sync active token:', e);
  }
  
  await loadProfiles();
}

async function removeAccount(provider, index) {
  const list = globalAccounts[provider];
  if (!list || !list[index]) return;
  
  const wasActive = list[index].isActive;
  list.splice(index, 1);
  
  if (wasActive) {
    if (list.length > 0) {
      list[0].isActive = true;
      const active = list[0];
      await saveAccountsList();
      try {
        await textFetch('/api/auth/active-token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            provider: provider,
            token: active.token,
            type: active.type || 'apikey'
          })
        });
      } catch (e) {
        console.error('Failed to sync active token:', e);
      }
    } else {
      await saveAccountsList();
      try {
        await textFetch('/api/auth/active-token', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            provider: provider,
            token: '',
            type: ''
          })
        });
      } catch (e) {
        console.error('Failed to clear active token:', e);
      }
    }
  } else {
    await saveAccountsList();
  }
  
  await loadProfiles();
}

window.setActiveAccount = setActiveAccount;
window.removeAccount = removeAccount;

async function loadRobloxProfile(tokens) {
  $('robloxActionStatus').textContent = 'Loading profile...';
  try {
    const raw = await textFetch('/api/roblox/profile');
    const res = JSON.parse(raw);
    if (res.ok) {
      $('robloxUser').textContent = res.displayName + ' (@' + res.name + ')';
      $('robloxMeta').textContent = 'User ID: ' + res.userId;
      if (res.avatarUrl) {
        $('robloxAvatar').src = res.avatarUrl;
        $('robloxAvatar').style.display = 'block';
        $('robloxPlaceholder').style.display = 'none';
      } else {
        $('robloxAvatar').style.display = 'none';
        $('robloxPlaceholder').style.display = 'block';
      }
      $('robloxCookieInput').value = '';
      $('robloxCookieInput').disabled = false;
      $('robloxCookieInput').placeholder = 'Paste another .ROBLOSECURITY cookie...';
      $('connectRoblox').classList.remove('hidden');
      $('disconnectRoblox').classList.remove('hidden');
      $('robloxActionStatus').textContent = '';
      
      if (tokens.robloxCookie) {
        upsertAccount('roblox', {
          userId: res.userId.toString(),
          username: res.name,
          displayName: res.displayName,
          avatarUrl: res.avatarUrl,
          token: tokens.robloxCookie,
          isActive: true
        });
      }
    } else {
      $('robloxUser').textContent = 'Not Connected';
      $('robloxMeta').textContent = 'Configure cookie to sync details';
      $('robloxAvatar').style.display = 'none';
      $('robloxPlaceholder').style.display = 'block';
      $('robloxCookieInput').disabled = false;
      $('robloxCookieInput').placeholder = 'Paste .ROBLOSECURITY cookie...';
      $('connectRoblox').classList.remove('hidden');
      $('disconnectRoblox').classList.add('hidden');
      $('robloxActionStatus').textContent = '';
    }
  } catch (e) {
    $('robloxActionStatus').textContent = 'Failed to load profile: ' + e.message;
  }
}

async function loadGithubProfile(tokens) {
  $('githubActionStatus').textContent = 'Loading profile...';
  try {
    const raw = await textFetch('/api/github/profile');
    const res = JSON.parse(raw);
    if (res.ok) {
      $('githubUser').textContent = res.login;
      $('githubMeta').textContent = 'GitHub Connected';
      if (res.avatarUrl) {
        $('githubAvatar').src = res.avatarUrl;
        $('githubAvatar').style.display = 'block';
        $('githubPlaceholder').style.display = 'none';
      } else {
        $('githubAvatar').style.display = 'none';
        $('githubPlaceholder').style.display = 'block';
      }
      $('githubTokenInput').value = '';
      $('githubTokenInput').disabled = false;
      $('githubTokenInput').placeholder = 'Paste another GitHub PAT...';
      $('connectGithub').classList.remove('hidden');
      $('connectGithubOAuth').classList.remove('hidden');
      $('disconnectGithub').classList.remove('hidden');
      $('githubActionStatus').textContent = '';
      
      if (tokens.githubToken) {
        upsertAccount('github', {
          login: res.login,
          avatarUrl: res.avatarUrl,
          token: tokens.githubToken,
          type: tokens.githubMethod,
          isActive: true
        });
      }
    } else {
      $('githubUser').textContent = 'Not Connected';
      $('githubMeta').textContent = 'Configure token/account to sync repos';
      $('githubAvatar').style.display = 'none';
      $('githubPlaceholder').style.display = 'block';
      $('githubTokenInput').disabled = false;
      $('githubTokenInput').placeholder = 'Paste GitHub PAT (repo scope)...';
      $('connectGithub').classList.remove('hidden');
      $('connectGithubOAuth').classList.remove('hidden');
      $('disconnectGithub').classList.add('hidden');
      $('githubActionStatus').textContent = '';
    }
  } catch (e) {
    $('githubActionStatus').textContent = 'Failed to load profile: ' + e.message;
  }
}

async function loadGoogleProfile(tokens) {
  $('googleActionStatus').textContent = 'Loading profile...';
  try {
    const raw = await textFetch('/api/google/profile');
    const res = JSON.parse(raw);
    if (res.ok) {
      $('googleUser').textContent = res.name || res.email || 'Gemini Active';
      $('googleMeta').textContent = res.email || 'Google Connected';
      if (res.avatarUrl) {
        $('googleAvatar').src = res.avatarUrl;
        $('googleAvatar').style.display = 'block';
        $('googlePlaceholder').style.display = 'none';
      } else {
        $('googleAvatar').style.display = 'none';
        $('googlePlaceholder').style.display = 'block';
      }
      $('googleTokenInput').value = '';
      $('googleTokenInput').disabled = false;
      $('googleTokenInput').placeholder = 'Paste another Gemini API Key...';
      $('connectGoogle').classList.remove('hidden');
      $('connectGoogleOAuth').classList.remove('hidden');
      $('disconnectGoogle').classList.remove('hidden');
      $('googleActionStatus').textContent = '';
      
      if (tokens.googleToken) {
        const activeOAuth = globalAccounts.google.find(a => a.type === 'oauth' && a.isActive);
        const labelInput = $('googleLabelInput');
        const customLabel = labelInput ? labelInput.value.trim() : '';
        if (labelInput) labelInput.value = '';
        
        let nameToSave = customLabel || (tokens.googleMethod === 'apikey' && activeOAuth ? activeOAuth.name : (res.name || res.email || 'Gemini Active'));
        let emailToSave = (tokens.googleMethod === 'apikey' && activeOAuth) ? activeOAuth.email : (res.email || '');
        let avatarToSave = (tokens.googleMethod === 'apikey' && activeOAuth) ? activeOAuth.avatarUrl : (res.avatarUrl || '');
        
        upsertAccount('google', {
          name: nameToSave,
          email: emailToSave,
          avatarUrl: avatarToSave,
          token: tokens.googleToken,
          type: tokens.googleMethod,
          isActive: true
        });
      }
    } else {
      $('googleUser').textContent = 'Not Connected';
      $('googleMeta').textContent = 'Configure API key or login to connect';
      $('googleAvatar').style.display = 'none';
      $('googlePlaceholder').style.display = 'block';
      $('googleTokenInput').disabled = false;
      $('googleTokenInput').placeholder = 'Paste Gemini API Key...';
      $('connectGoogle').classList.remove('hidden');
      $('connectGoogleOAuth').classList.remove('hidden');
      $('disconnectGoogle').classList.add('hidden');
      $('googleActionStatus').textContent = '';
    }
  } catch (e) {
    $('googleActionStatus').textContent = 'Failed to load profile: ' + e.message;
  }
}

async function loadOpenaiProfile(tokens) {
  $('openaiActionStatus').textContent = 'Loading profile...';
  try {
    const raw = await textFetch('/api/openai/profile');
    const res = JSON.parse(raw);
    if (res.ok) {
      $('openaiUser').textContent = 'OpenAI Active';
      $('openaiMeta').textContent = 'API Key connected';
      $('openaiTokenInput').value = '';
      $('openaiTokenInput').disabled = false;
      $('openaiTokenInput').placeholder = 'Paste another OpenAI API Key...';
      $('connectOpenai').classList.remove('hidden');
      $('disconnectOpenai').classList.remove('hidden');
      $('openaiActionStatus').textContent = '';
      
      if (tokens.openaiToken) {
        const labelInput = $('openaiLabelInput');
        const customLabel = labelInput ? labelInput.value.trim() : '';
        if (labelInput) labelInput.value = '';
        
        upsertAccount('openai', {
          name: customLabel || 'OpenAI Account',
          token: tokens.openaiToken,
          type: 'apikey',
          isActive: true
        });
      }
    } else {
      $('openaiUser').textContent = 'Not Connected';
      $('openaiMeta').textContent = 'Configure API key to use official GPT models';
      $('openaiTokenInput').disabled = false;
      $('openaiTokenInput').placeholder = 'Paste OpenAI API Key...';
      $('connectOpenai').classList.remove('hidden');
      $('disconnectOpenai').classList.add('hidden');
      $('openaiActionStatus').textContent = '';
    }
  } catch (e) {
    $('openaiActionStatus').textContent = 'Failed to load profile: ' + e.message;
  }
}

async function loadOauthConfig() {
  try {
    const raw = await textFetch('/api/auth/oauth-config');
    const res = JSON.parse(raw);
    $('oauthGoogleClientId').value = res.googleClientId || '';
    $('oauthGoogleClientSecret').value = res.googleClientSecret || '';
    $('oauthGithubClientId').value = res.githubClientId || '';
    $('oauthGithubClientSecret').value = res.githubClientSecret || '';
  } catch (e) {
    $('oauthConfigStatus').textContent = 'Failed to load settings';
  }
}

$('saveOauthConfig').onclick = async () => {
  $('oauthConfigStatus').textContent = 'Saving...';
  const payload = {
    googleClientId: $('oauthGoogleClientId').value.trim(),
    googleClientSecret: $('oauthGoogleClientSecret').value.trim(),
    githubClientId: $('oauthGithubClientId').value.trim(),
    githubClientSecret: $('oauthGithubClientSecret').value.trim()
  };
  try {
    const raw = await textFetch('/api/auth/oauth-config', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const res = JSON.parse(raw);
    if (res.ok) {
      $('oauthConfigStatus').textContent = 'Saved successfully';
      setTimeout(()=>$('oauthConfigStatus').textContent='', 2000);
    } else {
      $('oauthConfigStatus').textContent = 'Save failed';
    }
  } catch (e) {
    $('oauthConfigStatus').textContent = 'Error: ' + e.message;
  }
};

$('connectRoblox').onclick = async () => {
  const cookie = $('robloxCookieInput').value.trim();
  if (!cookie) {
    $('robloxActionStatus').textContent = 'Please enter a cookie';
    return;
  }
  $('robloxActionStatus').textContent = 'Linking...';
  try {
    const raw = await textFetch('/api/roblox/login', {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain' },
      body: cookie
    });
    const res = JSON.parse(raw);
    if (res.ok) {
      await loadProfiles();
    } else {
      $('robloxActionStatus').textContent = 'Error: ' + (res.error || 'Failed to link');
    }
  } catch (e) {
    $('robloxActionStatus').textContent = 'Request failed: ' + e.message;
  }
};

$('disconnectRoblox').onclick = async () => {
  $('robloxActionStatus').textContent = 'Disconnecting...';
  try {
    const raw = await textFetch('/api/roblox/logout', { method: 'POST' });
    const res = JSON.parse(raw);
    if (res.ok) {
      const activeIdx = globalAccounts.roblox.findIndex(a => a.isActive);
      if (activeIdx !== -1) {
        globalAccounts.roblox[activeIdx].isActive = false;
      }
      await saveAccountsList();
      await loadProfiles();
    } else {
      $('robloxActionStatus').textContent = 'Error disconnecting';
    }
  } catch (e) {
    $('robloxActionStatus').textContent = 'Request failed: ' + e.message;
  }
};

$('connectGithub').onclick = async () => {
  const token = $('githubTokenInput').value.trim();
  if (!token) {
    $('githubActionStatus').textContent = 'Please enter a token';
    return;
  }
  $('githubActionStatus').textContent = 'Linking...';
  try {
    const raw = await textFetch('/api/github/login', {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain' },
      body: token
    });
    const res = JSON.parse(raw);
    if (res.ok) {
      await loadProfiles();
    } else {
      $('githubActionStatus').textContent = 'Error: ' + (res.error || 'Failed to link');
    }
  } catch (e) {
    $('githubActionStatus').textContent = 'Request failed: ' + e.message;
  }
};

$('connectGithubOAuth').onclick = () => {
  window.open('/api/auth/github/login', 'DEX_OAuth', 'width=600,height=700');
};

$('disconnectGithub').onclick = async () => {
  $('githubActionStatus').textContent = 'Disconnecting...';
  try {
    const raw = await textFetch('/api/github/logout', { method: 'POST' });
    const res = JSON.parse(raw);
    if (res.ok) {
      const activeIdx = globalAccounts.github.findIndex(a => a.isActive);
      if (activeIdx !== -1) {
        globalAccounts.github[activeIdx].isActive = false;
      }
      await saveAccountsList();
      await loadProfiles();
    } else {
      $('githubActionStatus').textContent = 'Error disconnecting';
    }
  } catch (e) {
    $('githubActionStatus').textContent = 'Request failed: ' + e.message;
  }
};

$('connectGoogle').onclick = async () => {
  const token = $('googleTokenInput').value.trim();
  if (!token) {
    $('googleActionStatus').textContent = 'Please enter an API Key';
    return;
  }
  $('googleActionStatus').textContent = 'Linking...';
  try {
    const raw = await textFetch('/api/google/login', {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain' },
      body: token
    });
    const res = JSON.parse(raw);
    if (res.ok) {
      await loadProfiles();
    } else {
      $('googleActionStatus').textContent = 'Error: ' + (res.error || 'Failed to link');
    }
  } catch (e) {
    $('googleActionStatus').textContent = 'Request failed: ' + e.message;
  }
};

$('connectGoogleOAuth').onclick = () => {
  window.open('/api/auth/google/login', 'DEX_OAuth', 'width=600,height=700');
};

$('disconnectGoogle').onclick = async () => {
  $('googleActionStatus').textContent = 'Disconnecting...';
  try {
    const raw = await textFetch('/api/google/logout', { method: 'POST' });
    const res = JSON.parse(raw);
    if (res.ok) {
      const activeIdx = globalAccounts.google.findIndex(a => a.isActive);
      if (activeIdx !== -1) {
        globalAccounts.google[activeIdx].isActive = false;
      }
      await saveAccountsList();
      await loadProfiles();
    } else {
      $('googleActionStatus').textContent = 'Error disconnecting';
    }
  } catch (e) {
    $('googleActionStatus').textContent = 'Request failed: ' + e.message;
  }
};

$('connectOpenai').onclick = async () => {
  const token = $('openaiTokenInput').value.trim();
  if (!token) {
    $('openaiActionStatus').textContent = 'Please enter an API Key';
    return;
  }
  $('openaiActionStatus').textContent = 'Linking...';
  try {
    const raw = await textFetch('/api/openai/login', {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain' },
      body: token
    });
    const res = JSON.parse(raw);
    if (res.ok) {
      await loadProfiles();
    } else {
      $('openaiActionStatus').textContent = 'Error: ' + (res.error || 'Failed to link');
    }
  } catch (e) {
    $('openaiActionStatus').textContent = 'Request failed: ' + e.message;
  }
};

$('disconnectOpenai').onclick = async () => {
  $('openaiActionStatus').textContent = 'Disconnecting...';
  try {
    const raw = await textFetch('/api/openai/logout', { method: 'POST' });
    const res = JSON.parse(raw);
    if (res.ok) {
      const activeIdx = globalAccounts.openai.findIndex(a => a.isActive);
      if (activeIdx !== -1) {
        globalAccounts.openai[activeIdx].isActive = false;
      }
      await saveAccountsList();
      await loadProfiles();
    } else {
      $('openaiActionStatus').textContent = 'Error disconnecting';
    }
  } catch (e) {
    $('openaiActionStatus').textContent = 'Request failed: ' + e.message;
  }
};

// Auto-refresh profiles on window focus (after closing OAuth popups)
window.onfocus = () => {
  loadProfiles();
};

document.querySelectorAll('.tab').forEach(b=>b.onclick=()=>show(b.dataset.view));
refreshStatus();
refreshScriptStatus();
refreshWorkers();
refreshToolchain();
refreshToolState();
loadProfiles();
loadOauthConfig();
setInterval(refreshScriptStatus,5000);
setInterval(refreshWorkers,5000);
setInterval(refreshToolchain,10000);
setInterval(refreshToolState,1000);
</script>
</body>
</html>)DEXAPP";
}
