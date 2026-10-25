/**
 * Bee Desktop - Application Renderer Script
 */

// State
const state = {
  activeView: 'conversations',
  currentTab: 'synthesized',
  selectedItem: null,
  config: {},
  localData: {
    conversations: [],
    daily: [],
    journals: [],
    todos: [],
    facts: []
  },
  currentItemDetail: null
};

// DOM Elements
const el = {
  // Navigation
  navItems: document.querySelectorAll('.nav-item'),
  badgeConversations: document.getElementById('badgeConversations'),
  badgeDaily: document.getElementById('badgeDaily'),
  badgeJournals: document.getElementById('badgeJournals'),
  badgeTodos: document.getElementById('badgeTodos'),
  badgeFacts: document.getElementById('badgeFacts'),
  badgeInsights: document.getElementById('badgeInsights'),
  sidebarStoragePath: document.getElementById('sidebarStoragePath'),
  btnOpenFolderSidebar: document.getElementById('btnOpenFolderSidebar'),
  btnAccountBadge: document.getElementById('btnAccountBadge'),
  connStatusDot: document.getElementById('connStatusDot'),
  connStatusText: document.getElementById('connStatusText'),
  btnQuickSync: document.getElementById('btnQuickSync'),

  // Panes
  listPane: document.getElementById('listPane'),
  detailPane: document.getElementById('detailPane'),
  settingsPane: document.getElementById('settingsPane'),
  searchViewPane: document.getElementById('searchViewPane'),
  filesViewPane: document.getElementById('filesViewPane'),

  // List Pane
  listTitle: document.getElementById('listTitle'),
  listCount: document.getElementById('listCount'),
  searchInput: document.getElementById('searchInput'),
  itemsList: document.getElementById('itemsList'),

  // Detail Pane
  detailPlaceholder: document.getElementById('detailPlaceholder'),
  detailContent: document.getElementById('detailContent'),
  detailTypeBadge: document.getElementById('detailTypeBadge'),
  detailTimestamp: document.getElementById('detailTimestamp'),
  detailDuration: document.getElementById('detailDuration'),
  detailTitle: document.getElementById('detailTitle'),
  detailId: document.getElementById('detailId'),
  cardExecutiveSummary: document.getElementById('cardExecutiveSummary'),
  detailExecutiveSummary: document.getElementById('detailExecutiveSummary'),
  cardHighlights: document.getElementById('cardHighlights'),
  detailHighlightsList: document.getElementById('detailHighlightsList'),
  cardTasks: document.getElementById('cardTasks'),
  detailTasksList: document.getElementById('detailTasksList'),
  cardTranscript: document.getElementById('cardTranscript'),
  detailTranscriptTimeline: document.getElementById('detailTranscriptTimeline'),
  detailUtteranceCount: document.getElementById('detailUtteranceCount'),
  btnOpenMd: document.getElementById('btnOpenMd'),
  btnOpenJson: document.getElementById('btnOpenJson'),
  btnRevealFile: document.getElementById('btnRevealFile'),
  btnCopyTranscript: document.getElementById('btnCopyTranscript'),

  // View Tabs
  viewTabs: document.querySelectorAll('.view-tab'),
  panelSynthesized: document.getElementById('panelSynthesized'),
  panelMarkdown: document.getElementById('panelMarkdown'),
  panelRawJson: document.getElementById('panelRawJson'),
  markdownViewCode: document.getElementById('markdownViewCode'),
  jsonViewCode: document.getElementById('jsonViewCode'),

  // Settings
  radioConnModes: document.querySelectorAll('input[name="connMode"]'),
  groupEndpoint: document.getElementById('groupEndpoint'),
  groupToken: document.getElementById('groupToken'),
  inputEndpoint: document.getElementById('inputEndpoint'),
  inputToken: document.getElementById('inputToken'),
  btnToggleTokenVisibility: document.getElementById('btnToggleTokenVisibility'),
  btnTestConnection: document.getElementById('btnTestConnection'),
  btnSaveConfig: document.getElementById('btnSaveConfig'),
  connResultAlert: document.getElementById('connResultAlert'),
  inputStorageDir: document.getElementById('inputStorageDir'),
  btnBrowseFolder: document.getElementById('btnBrowseFolder'),
  btnOpenStorageFinder: document.getElementById('btnOpenStorageFinder'),
  btnExportZip: document.getElementById('btnExportZip'),
  btnLoadDemo: document.getElementById('btnLoadDemo'),

  // Global Search
  bigSearchInput: document.getElementById('bigSearchInput'),
  searchResultsList: document.getElementById('searchResultsList'),

  // Files & Export Page
  statConvCount: document.getElementById('statConvCount'),
  statDailyCount: document.getElementById('statDailyCount'),
  statJournalCount: document.getElementById('statJournalCount'),
  statTodoCount: document.getElementById('statTodoCount'),
  btnOpenFolderFilesPage: document.getElementById('btnOpenFolderFilesPage'),
  btnExportZipFilesPage: document.getElementById('btnExportZipFilesPage'),

  // Modal
  syncModal: document.getElementById('syncModal'),
  syncProgressFill: document.getElementById('syncProgressFill'),
  syncProgressMessage: document.getElementById('syncProgressMessage'),
  syncProgressPercent: document.getElementById('syncProgressPercent'),
  syncLogs: document.getElementById('syncLogs'),
  btnCancelSync: document.getElementById('btnCancelSync')
};

// Utilities
function formatDate(ts) {
  if (!ts) return 'Unknown Date';
  try {
    let num = typeof ts === 'number' ? ts : (typeof ts === 'string' && /^\d+$/.test(ts) ? Number(ts) : null);
    const d = num !== null ? new Date(num) : new Date(String(ts));
    if (isNaN(d.getTime())) return String(ts);
    return d.toLocaleString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch (e) {
    return String(ts);
  }
}

function formatDuration(ms) {
  if (!ms || typeof ms !== 'number') return '';
  const totalSeconds = Math.floor(ms / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  if (minutes === 0) return `${seconds}s`;
  return `${minutes}m ${seconds}s`;
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

// Initialization
async function init() {
  setupEventListeners();
  await loadAppConfig();
  await refreshLocalData();

  // Check connection status in background
  checkStatusIndicator();
}

async function loadAppConfig() {
  state.config = await window.beeAPI.getConfig();
  el.inputEndpoint.value = state.config.endpoint || 'https://api.developer.bee.amazon.dev';
  el.inputToken.value = state.config.token || '';
  el.inputStorageDir.value = state.config.storageDir || '';
  el.sidebarStoragePath.textContent = state.config.storageDir || '~/Documents/Bee Exports';
  el.sidebarStoragePath.title = state.config.storageDir || '';

  // Set active radio based on endpoint
  if (state.config.endpoint.includes('127.0.0.1') || state.config.endpoint.includes('localhost')) {
    const proxyRadio = document.querySelector('input[name="connMode"][value="proxy"]');
    if (proxyRadio) proxyRadio.checked = true;
    el.groupEndpoint.style.display = 'none';
  } else if (state.config.endpoint === 'https://api.developer.bee.amazon.dev') {
    const pubRadio = document.querySelector('input[name="connMode"][value="public"]');
    if (pubRadio) pubRadio.checked = true;
    el.groupEndpoint.style.display = 'none';
  } else {
    const custRadio = document.querySelector('input[name="connMode"][value="custom"]');
    if (custRadio) custRadio.checked = true;
    el.groupEndpoint.style.display = 'flex';
  }
}

async function checkStatusIndicator() {
  if (state.config.endpoint.includes('127.0.0.1') || state.config.endpoint.includes('8787')) {
    const proxyCheck = await window.beeAPI.checkLocalProxy();
    if (proxyCheck.success) {
      el.connStatusDot.className = 'status-indicator status-proxy';
      el.connStatusText.textContent = 'Proxy (127.0.0.1:8787)';
      return;
    }
  }

  if (state.config.token) {
    const check = await window.beeAPI.testConnection();
    if (check.success) {
      el.connStatusDot.className = 'status-indicator status-online';
      el.connStatusText.textContent = check.data.name || check.data.email || 'Connected';
      return;
    }
  }

  el.connStatusDot.className = 'status-indicator status-offline';
  el.connStatusText.textContent = 'Offline / Setup';
}

async function refreshLocalData() {
  state.localData = await window.beeAPI.getLocalData();

  // Update badge counts
  const convCount = (state.localData.conversations || []).length;
  const dailyCount = (state.localData.daily || []).length;
  const journalCount = (state.localData.journals || []).length;
  const todoCount = (state.localData.todos || []).length;
  const factCount = (state.localData.facts || []).length;
  const insightCount = (state.localData.insights || []).length;

  el.badgeConversations.textContent = convCount;
  el.badgeDaily.textContent = dailyCount;
  el.badgeJournals.textContent = journalCount;
  el.badgeTodos.textContent = todoCount;
  el.badgeFacts.textContent = factCount;
  if (el.badgeInsights) el.badgeInsights.textContent = insightCount;

  el.statConvCount.textContent = convCount;
  el.statDailyCount.textContent = dailyCount;
  el.statJournalCount.textContent = journalCount;
  el.statTodoCount.textContent = todoCount;

  renderActiveView();
}

function switchView(viewName) {
  state.activeView = viewName;

  el.navItems.forEach(item => {
    if (item.dataset.view === viewName) {
      item.classList.add('active');
    } else {
      item.classList.remove('active');
    }
  });

  // Hide full page panes by default
  el.settingsPane.style.display = 'none';
  el.searchViewPane.style.display = 'none';
  el.filesViewPane.style.display = 'none';

  if (viewName === 'settings') {
    el.listPane.style.display = 'none';
    el.detailPane.style.display = 'none';
    el.settingsPane.style.display = 'flex';
    return;
  }

  if (viewName === 'search') {
    el.listPane.style.display = 'none';
    el.detailPane.style.display = 'none';
    el.searchViewPane.style.display = 'flex';
    el.bigSearchInput.focus();
    return;
  }

  if (viewName === 'files') {
    el.listPane.style.display = 'none';
    el.detailPane.style.display = 'none';
    el.filesViewPane.style.display = 'flex';
    return;
  }

  // Regular 2-pane view
  el.listPane.style.display = 'flex';
  el.detailPane.style.display = 'flex';
  el.searchInput.value = '';
  renderActiveView();
}

function renderActiveView() {
  const query = el.searchInput.value.toLowerCase().trim();

  if (state.activeView === 'conversations') {
    renderConversationsList(query);
  } else if (state.activeView === 'daily') {
    renderDailyList(query);
  } else if (state.activeView === 'journals') {
    renderJournalsList(query);
  } else if (state.activeView === 'todos') {
    renderTodosList(query);
  } else if (state.activeView === 'facts') {
    renderFactsList(query);
  } else if (state.activeView === 'insights') {
    renderInsightsList(query);
  }
}

function renderInsightsList(query = '') {
  el.listTitle.textContent = 'AI Insights & Patterns';
  const items = (state.localData.insights || []).filter(ins => {
    if (!query) return true;
    return (ins.title || '').toLowerCase().includes(query) ||
           (ins.description || '').toLowerCase().includes(query);
  });

  el.listCount.textContent = `${items.length} items`;
  el.itemsList.innerHTML = '';

  if (items.length === 0) {
    renderEmptyState('No insights found.', 'Sync your Bee account to fetch extracted behavioral patterns.');
    return;
  }

  items.forEach(ins => {
    const card = document.createElement('div');
    card.className = 'item-card';
    card.innerHTML = `
      <div class="card-top">
        <span class="item-title">🧠 ${escapeHtml(ins.title || 'Insight')}</span>
      </div>
      <div class="item-snippet">${escapeHtml(ins.description || '')}</div>
      <div class="card-badges">
        <span class="badge-tag">${escapeHtml(ins.category || 'Behavioral Pattern')}</span>
      </div>
    `;
    el.itemsList.appendChild(card);
  });

  showInsightsDetail();
}

function showInsightsDetail() {
  el.detailPlaceholder.style.display = 'none';
  el.detailContent.style.display = 'flex';

  el.detailTypeBadge.textContent = 'AI INSIGHTS';
  el.detailTimestamp.textContent = new Date().toLocaleDateString();
  el.detailDuration.textContent = '';
  el.detailTitle.textContent = 'Behavioral Insights & Life Patterns';
  el.detailId.textContent = 'insights.json';

  el.cardExecutiveSummary.style.display = 'none';
  el.cardHighlights.style.display = 'flex';
  el.cardTasks.style.display = 'none';
  el.cardTranscript.style.display = 'none';

  const insights = state.localData.insights || [];
  el.detailHighlightsList.innerHTML = insights.map(ins => {
    return `<li><strong>${escapeHtml(ins.title || '')}</strong><br><span style="font-size: 12px; color: var(--text-muted);">${escapeHtml(ins.description || '')}</span></li>`;
  }).join('');

  el.markdownViewCode.textContent = JSON.stringify(insights, null, 2);
  el.jsonViewCode.textContent = JSON.stringify(insights, null, 2);
}

function renderConversationsList(query = '') {
  el.listTitle.textContent = 'Conversations';
  const items = (state.localData.conversations || []).filter(c => {
    if (!query) return true;
    return (c.title || '').toLowerCase().includes(query) ||
           (c.summarySnippet || '').toLowerCase().includes(query);
  });

  el.listCount.textContent = `${items.length} items`;
  el.itemsList.innerHTML = '';

  if (items.length === 0) {
    renderEmptyState('No conversations found.', 'Sync your Bee device or load sample data.');
    return;
  }

  items.forEach(c => {
    const card = document.createElement('div');
    card.className = `item-card ${state.selectedItem?.id === c.id ? 'active' : ''}`;
    card.onclick = () => selectItem('conversations', c.id);

    const dateStr = formatDate(c.created_at);
    const duration = formatDuration(c.duration_ms);

    card.innerHTML = `
      <div class="card-top">
        <span class="item-title">${escapeHtml(c.title)}</span>
        <span class="item-date">${escapeHtml(dateStr)}</span>
      </div>
      <div class="item-snippet">${escapeHtml(c.summarySnippet || 'No summary text available.')}</div>
      <div class="card-badges">
        ${duration ? `<span class="badge-tag">⏱️ ${duration}</span>` : ''}
        ${c.utteranceCount ? `<span class="badge-tag">💬 ${c.utteranceCount} turns</span>` : ''}
      </div>
    `;
    el.itemsList.appendChild(card);
  });
}

function renderDailyList(query = '') {
  el.listTitle.textContent = 'Daily Summaries';
  const items = (state.localData.daily || []).filter(d => {
    if (!query) return true;
    return (d.title || '').toLowerCase().includes(query) ||
           (d.date || '').toLowerCase().includes(query) ||
           (d.summarySnippet || '').toLowerCase().includes(query);
  });

  el.listCount.textContent = `${items.length} items`;
  el.itemsList.innerHTML = '';

  if (items.length === 0) {
    renderEmptyState('No daily summaries found.', 'Run a sync to pull your daily executive summaries.');
    return;
  }

  items.forEach(d => {
    const card = document.createElement('div');
    card.className = `item-card ${state.selectedItem?.id === d.id ? 'active' : ''}`;
    card.onclick = () => selectItem('daily', d.id);

    card.innerHTML = `
      <div class="card-top">
        <span class="item-title">🌅 ${escapeHtml(d.title)}</span>
        <span class="item-date">${escapeHtml(d.date || '')}</span>
      </div>
      <div class="item-snippet">${escapeHtml(d.summarySnippet || 'Executive briefing for the day.')}</div>
      <div class="card-badges">
        <span class="badge-tag">Daily Recap</span>
      </div>
    `;
    el.itemsList.appendChild(card);
  });
}

function renderJournalsList(query = '') {
  el.listTitle.textContent = 'Journals';
  const items = (state.localData.journals || []).filter(j => {
    if (!query) return true;
    return (j.title || '').toLowerCase().includes(query) ||
           (j.summarySnippet || '').toLowerCase().includes(query);
  });

  el.listCount.textContent = `${items.length} items`;
  el.itemsList.innerHTML = '';

  if (items.length === 0) {
    renderEmptyState('No journals found.', 'Bee creates reflective journal entries automatically.');
    return;
  }

  items.forEach(j => {
    const card = document.createElement('div');
    card.className = `item-card ${state.selectedItem?.id === j.id ? 'active' : ''}`;
    card.onclick = () => selectItem('journals', j.id);

    card.innerHTML = `
      <div class="card-top">
        <span class="item-title">📖 ${escapeHtml(j.title)}</span>
        <span class="item-date">${escapeHtml(formatDate(j.date))}</span>
      </div>
      <div class="item-snippet">${escapeHtml(j.summarySnippet || 'Personal reflections and journal insights.')}</div>
    `;
    el.itemsList.appendChild(card);
  });
}

function renderTodosList(query = '') {
  el.listTitle.textContent = 'Action Items & Todos';
  const items = (state.localData.todos || []).filter(t => {
    if (!query) return true;
    return (t.text || '').toLowerCase().includes(query);
  });

  el.listCount.textContent = `${items.length} items`;
  el.itemsList.innerHTML = '';

  if (items.length === 0) {
    renderEmptyState('No action items recorded.', 'Tasks mentioned in your conversations will appear here.');
    return;
  }

  items.forEach(t => {
    const card = document.createElement('div');
    card.className = 'item-card';

    const done = t.completed;
    const alarm = t.alarm_at ? `⏰ ${formatDate(t.alarm_at)}` : '';

    card.innerHTML = `
      <div class="card-top">
        <span class="item-title" style="${done ? 'text-decoration: line-through; opacity: 0.6;' : ''}">
          ${done ? '✅' : '⏳'} ${escapeHtml(t.text || 'Untitled Task')}
        </span>
      </div>
      <div class="card-badges">
        <span class="badge-tag">${done ? 'Completed' : 'Pending'}</span>
        ${alarm ? `<span class="badge-tag">${alarm}</span>` : ''}
      </div>
    `;
    el.itemsList.appendChild(card);
  });

  // Automatically render todos markdown view in detail pane
  showTodoDetail();
}

function renderFactsList(query = '') {
  el.listTitle.textContent = 'Memory Bank & Facts';
  const items = (state.localData.facts || []).filter(f => {
    if (!query) return true;
    return (f.text || '').toLowerCase().includes(query);
  });

  el.listCount.textContent = `${items.length} items`;
  el.itemsList.innerHTML = '';

  if (items.length === 0) {
    renderEmptyState('No facts recorded yet.', 'Bee records key facts about your life, habits, and preferences.');
    return;
  }

  items.forEach(f => {
    const card = document.createElement('div');
    card.className = 'item-card';
    card.innerHTML = `
      <div class="card-top">
        <span class="item-title">💡 ${escapeHtml(f.text || 'Fact')}</span>
      </div>
      <div class="card-badges">
        <span class="badge-tag">${f.confirmed ? 'Confirmed' : 'Unconfirmed'}</span>
        ${f.created_at ? `<span class="badge-tag">${formatDate(f.created_at)}</span>` : ''}
      </div>
    `;
    el.itemsList.appendChild(card);
  });

  showFactsDetail();
}

function renderEmptyState(heading, subtext) {
  el.itemsList.innerHTML = `
    <div class="empty-state">
      <div class="empty-icon">🐝</div>
      <h3>${escapeHtml(heading)}</h3>
      <p>${escapeHtml(subtext)}</p>
      <div class="empty-actions">
        <button class="btn btn-primary btn-sm" onclick="startSyncProcess()">Sync Bee Data</button>
        <button class="btn btn-secondary btn-sm" onclick="loadDemoData()">Load Sample Data</button>
      </div>
    </div>
  `;
}

// Select Item and View Details
async function selectItem(type, id) {
  state.selectedItem = { type, id };
  
  // Highlight card
  const cards = el.itemsList.querySelectorAll('.item-card');
  cards.forEach(c => c.classList.remove('active'));

  el.detailPlaceholder.style.display = 'none';
  el.detailContent.style.display = 'flex';

  const fileData = await window.beeAPI.getItemFile({ type, id });
  state.currentItemDetail = fileData;

  const raw = fileData.jsonData || {};
  const data = raw.conversation || raw.daily_summary || raw.journal || raw;
  const title = data.title || data.short_summary || data.name || (type === 'daily' ? `Daily Summary ${data.date || id}` : `Item ${id}`);
  const dateStr = formatDate(data.start_time || data.created_at || data.timestamp || data.date || data.date_time);
  const durMs = data.duration_ms || (data.end_time && data.start_time ? (data.end_time - data.start_time) : null);
  const duration = durMs ? formatDuration(durMs) : '';

  el.detailTypeBadge.textContent = type.toUpperCase();
  el.detailTimestamp.textContent = dateStr;
  el.detailDuration.textContent = duration ? `• ${duration}` : '';
  el.detailTitle.textContent = title;
  el.detailId.textContent = id;

  // Executive Summary Card
  const summary = data.summary || data.short_summary || data.executive_summary || data.overview || (data.conversation_summary ? data.conversation_summary.text : '');
  if (summary) {
    el.cardExecutiveSummary.style.display = 'flex';
    el.detailExecutiveSummary.textContent = summary;
  } else {
    el.cardExecutiveSummary.style.display = 'none';
  }

  // Highlights Card
  const highlights = data.key_points || data.takeaways || data.highlights || data.insights || [];
  if (Array.isArray(highlights) && highlights.length > 0) {
    el.cardHighlights.style.display = 'flex';
    el.detailHighlightsList.innerHTML = highlights.map(h => {
      const text = typeof h === 'string' ? h : (h.text || JSON.stringify(h));
      return `<li>${escapeHtml(text)}</li>`;
    }).join('');
  } else {
    el.cardHighlights.style.display = 'none';
  }

  // Tasks Card
  const tasks = data.action_items || data.todos || [];
  if (Array.isArray(tasks) && tasks.length > 0) {
    el.cardTasks.style.display = 'flex';
    el.detailTasksList.innerHTML = tasks.map(t => {
      const text = typeof t === 'string' ? t : (t.text || t.title);
      const done = t.completed;
      return `
        <li class="task-item ${done ? 'completed' : ''}">
          <input type="checkbox" class="task-checkbox" ${done ? 'checked' : ''} disabled>
          <span>${escapeHtml(text)}</span>
        </li>
      `;
    }).join('');
  } else {
    el.cardTasks.style.display = 'none';
  }

  // Transcript Utterances
  let utterances = data.utterances || data.messages || data.transcript || [];
  if ((!utterances || utterances.length === 0) && Array.isArray(data.transcriptions)) {
    utterances = data.transcriptions.flatMap(t => t.utterances || []);
  }

  if (Array.isArray(utterances) && utterances.length > 0) {
    el.cardTranscript.style.display = 'flex';
    el.detailUtteranceCount.textContent = `${utterances.length} turns`;
    el.detailTranscriptTimeline.innerHTML = utterances.map(u => {
      const speaker = u.speaker || u.role || 'Speaker';
      const isBee = speaker.toLowerCase().includes('bee');
      const time = u.spoken_at ? formatDate(u.spoken_at) : (u.timestamp ? formatDate(u.timestamp) : (u.start !== undefined ? `${u.start}s` : ''));
      const text = u.text || u.content || u.utterance || '';

      return `
        <div class="utterance-row ${isBee ? 'is-bee' : ''}">
          <div class="utterance-avatar ${isBee ? 'bee' : ''}">
            ${isBee ? '🐝' : '👤'}
          </div>
          <div class="utterance-body">
            <div class="utterance-meta">
              <span class="utterance-speaker">${escapeHtml(speaker)}</span>
              ${time ? `<span class="utterance-time">${escapeHtml(time)}</span>` : ''}
            </div>
            <div class="utterance-bubble">${escapeHtml(text)}</div>
          </div>
        </div>
      `;
    }).join('');
  } else if (data.text || data.content) {
    // For Journals or simple texts
    el.cardTranscript.style.display = 'flex';
    el.detailUtteranceCount.textContent = 'Content';
    el.detailTranscriptTimeline.innerHTML = `
      <div class="utterance-bubble" style="white-space: pre-wrap;">${escapeHtml(data.text || data.content)}</div>
    `;
  } else {
    el.cardTranscript.style.display = 'none';
  }

  // Raw Markdown & JSON views
  el.markdownViewCode.textContent = fileData.markdownData || 'No markdown generated.';
  el.jsonViewCode.textContent = JSON.stringify(data, null, 2);
}

function showTodoDetail() {
  el.detailPlaceholder.style.display = 'none';
  el.detailContent.style.display = 'flex';

  el.detailTypeBadge.textContent = 'ALL TASKS';
  el.detailTimestamp.textContent = new Date().toLocaleDateString();
  el.detailDuration.textContent = '';
  el.detailTitle.textContent = 'All Bee Action Items & Todos';
  el.detailId.textContent = 'todos.json';

  el.cardExecutiveSummary.style.display = 'none';
  el.cardHighlights.style.display = 'none';
  el.cardTasks.style.display = 'flex';
  el.cardTranscript.style.display = 'none';

  const todos = state.localData.todos || [];
  el.detailTasksList.innerHTML = todos.map(t => {
    const done = t.completed;
    const alarm = t.alarm_at ? ` (Alarm: ${formatDate(t.alarm_at)})` : '';
    return `
      <li class="task-item ${done ? 'completed' : ''}">
        <input type="checkbox" class="task-checkbox" ${done ? 'checked' : ''} disabled>
        <span><strong>${escapeHtml(t.text)}</strong>${escapeHtml(alarm)}</span>
      </li>
    `;
  }).join('');

  el.markdownViewCode.textContent = JSON.stringify(todos, null, 2);
  el.jsonViewCode.textContent = JSON.stringify(todos, null, 2);
}

function showFactsDetail() {
  el.detailPlaceholder.style.display = 'none';
  el.detailContent.style.display = 'flex';

  el.detailTypeBadge.textContent = 'MEMORY BANK';
  el.detailTimestamp.textContent = new Date().toLocaleDateString();
  el.detailDuration.textContent = '';
  el.detailTitle.textContent = 'Learned Facts & Preferences';
  el.detailId.textContent = 'facts.json';

  el.cardExecutiveSummary.style.display = 'none';
  el.cardHighlights.style.display = 'flex';
  el.cardTasks.style.display = 'none';
  el.cardTranscript.style.display = 'none';

  const facts = state.localData.facts || [];
  el.detailHighlightsList.innerHTML = facts.map(f => {
    const status = f.confirmed ? '✅ Confirmed' : '❔ Pending confirmation';
    return `<li><strong>${escapeHtml(f.text)}</strong> <span style="font-size: 11px; color: var(--text-dim);">(${status})</span></li>`;
  }).join('');

  el.markdownViewCode.textContent = JSON.stringify(facts, null, 2);
  el.jsonViewCode.textContent = JSON.stringify(facts, null, 2);
}

// Global Search
async function executeGlobalSearch(keyword) {
  const query = keyword.trim();
  if (!query) {
    el.searchResultsList.innerHTML = '<div class="empty-state"><p>Type a keyword above to find matches across all your Bee files.</p></div>';
    return;
  }

  const selectedMode = document.querySelector('input[name="searchEngine"]:checked')?.value || 'local';

  if (selectedMode === 'bm25' || selectedMode === 'neural') {
    el.searchResultsList.innerHTML = '<div class="empty-state"><p>Searching Bee Cloud (' + (selectedMode === 'neural' ? 'Neural Semantic' : 'BM25 Keyword') + ')...</p></div>';
    try {
      const res = await window.beeAPI.searchApi({ query, neural: selectedMode === 'neural', limit: 15 });
      const apiResults = res.results || [];
      if (apiResults.length === 0) {
        el.searchResultsList.innerHTML = `<div class="empty-state"><h3>No results found for "${escapeHtml(query)}"</h3><p>Try fuzzy neural search or local instant search.</p></div>`;
        return;
      }
      el.searchResultsList.innerHTML = apiResults.map(r => {
        const title = r.title || r.short_summary || (r.type === 'daily' ? `Daily Summary ${r.id}` : `Conversation ${r.id}`);
        const snippet = r.summary || r.text || '';
        const highlightedTitle = highlightKeyword(title, query);
        const highlightedSnippet = highlightKeyword(snippet, query);
        const targetType = r.type === 'daily' ? 'daily' : 'conversations';
        return `
          <div class="search-hit-card" onclick="openSearchResult('${targetType}', '${r.id}')">
            <div class="hit-type">${escapeHtml(r.type || 'result')} (Score: ${r.score ? r.score.toFixed(2) : 'N/A'})</div>
            <div class="hit-title">${highlightedTitle}</div>
            <div class="hit-match">${highlightedSnippet}</div>
          </div>
        `;
      }).join('');
      return;
    } catch (e) {
      console.warn('Cloud search failed, falling back to local search:', e.message);
    }
  }

  const results = [];

  // 1. Search conversations
  (state.localData.conversations || []).forEach(c => {
    const titleMatch = (c.title || '').toLowerCase().includes(query);
    const summaryMatch = (c.summarySnippet || '').toLowerCase().includes(query);
    if (titleMatch || summaryMatch) {
      results.push({
        type: 'conversation',
        id: c.id,
        title: c.title,
        snippet: c.summarySnippet || '',
        category: 'Conversations'
      });
    }
  });

  // 2. Search daily
  (state.localData.daily || []).forEach(d => {
    const titleMatch = (d.title || '').toLowerCase().includes(query);
    const summaryMatch = (d.summarySnippet || '').toLowerCase().includes(query);
    if (titleMatch || summaryMatch) {
      results.push({
        type: 'daily',
        id: d.id,
        title: d.title,
        snippet: d.summarySnippet || '',
        category: 'Daily Summaries'
      });
    }
  });

  // 3. Search journals
  (state.localData.journals || []).forEach(j => {
    const titleMatch = (j.title || '').toLowerCase().includes(query);
    const summaryMatch = (j.summarySnippet || '').toLowerCase().includes(query);
    if (titleMatch || summaryMatch) {
      results.push({
        type: 'journals',
        id: j.id,
        title: j.title,
        snippet: j.summarySnippet || '',
        category: 'Journals'
      });
    }
  });

  // 4. Search todos
  (state.localData.todos || []).forEach(t => {
    if ((t.text || '').toLowerCase().includes(query)) {
      results.push({
        type: 'todos',
        id: t.id,
        title: t.text,
        snippet: t.completed ? 'Completed Task' : 'Pending Action Item',
        category: 'Action Items'
      });
    }
  });

  // 5. Search facts
  (state.localData.facts || []).forEach(f => {
    if ((f.text || '').toLowerCase().includes(query)) {
      results.push({
        type: 'facts',
        id: f.id,
        title: f.text,
        snippet: f.confirmed ? 'Confirmed Memory Fact' : 'Unconfirmed Fact',
        category: 'Memory Bank'
      });
    }
  });

  if (results.length === 0) {
    el.searchResultsList.innerHTML = `<div class="empty-state"><h3>No results found for "${escapeHtml(keyword)}"</h3><p>Try searching for a different keyword or synching your latest Bee records.</p></div>`;
    return;
  }

  el.searchResultsList.innerHTML = results.map(r => {
    const highlightedTitle = highlightKeyword(r.title, query);
    const highlightedSnippet = highlightKeyword(r.snippet, query);

    return `
      <div class="search-hit-card" onclick="openSearchResult('${r.type}', '${r.id}')">
        <div class="hit-type">${escapeHtml(r.category)}</div>
        <div class="hit-title">${highlightedTitle}</div>
        <div class="hit-match">${highlightedSnippet}</div>
      </div>
    `;
  }).join('');
}

function highlightKeyword(text, keyword) {
  if (!text) return '';
  const escaped = escapeHtml(text);
  const regex = new RegExp(`(${keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')})`, 'gi');
  return escaped.replace(regex, '<mark>$1</mark>');
}

window.openSearchResult = function(type, id) {
  if (type === 'todos' || type === 'facts') {
    switchView(type);
  } else {
    switchView(type);
    selectItem(type, id);
  }
};

// Syncing
window.startSyncProcess = async function() {
  el.syncModal.style.display = 'flex';
  el.syncProgressFill.style.width = '0%';
  el.syncProgressPercent.textContent = '0%';
  el.syncProgressMessage.textContent = 'Connecting to Bee API...';
  el.syncLogs.innerHTML = '<div>Starting sync session...</div>';

  try {
    const result = await window.beeAPI.startSync();
    if (result.success) {
      appendSyncLog('Sync completed successfully!');
      setTimeout(async () => {
        el.syncModal.style.display = 'none';
        await refreshLocalData();
        checkStatusIndicator();
      }, 800);
    } else {
      appendSyncLog(`Sync stopped: ${result.error || 'Unknown error'}`);
    }
  } catch (err) {
    appendSyncLog(`Sync error: ${err.message}`);
  }
};

function appendSyncLog(msg) {
  const line = document.createElement('div');
  line.textContent = `[${new Date().toLocaleTimeString()}] ${msg}`;
  el.syncLogs.appendChild(line);
  el.syncLogs.scrollTop = el.syncLogs.scrollHeight;
}

window.loadDemoData = async function() {
  const result = await window.beeAPI.loadDemoData();
  await refreshLocalData();
  alert('Sample Bee.computer developer data loaded successfully! You can now browse conversations, transcripts, daily executive summaries, and action items.');
};

// Event Listeners Setup
function setupEventListeners() {
  // Navigation
  el.navItems.forEach(item => {
    item.addEventListener('click', () => switchView(item.dataset.view));
  });

  el.btnAccountBadge.addEventListener('click', () => switchView('settings'));
  el.btnQuickSync.addEventListener('click', startSyncProcess);

  // Search inputs
  el.searchInput.addEventListener('input', () => renderActiveView());
  el.bigSearchInput.addEventListener('input', (e) => executeGlobalSearch(e.target.value));
  document.querySelectorAll('input[name="searchEngine"]').forEach(r => {
    r.addEventListener('change', () => {
      if (el.bigSearchInput.value) executeGlobalSearch(el.bigSearchInput.value);
    });
  });

  // Tabs in detail pane
  el.viewTabs.forEach(tab => {
    tab.addEventListener('click', () => {
      el.viewTabs.forEach(t => t.classList.remove('active'));
      tab.classList.add('active');
      state.currentTab = tab.dataset.tab;

      el.panelSynthesized.classList.toggle('active', state.currentTab === 'synthesized');
      el.panelMarkdown.classList.toggle('active', state.currentTab === 'markdown');
      el.panelRawJson.classList.toggle('active', state.currentTab === 'raw-json');
    });
  });

  // Detail actions
  el.btnOpenMd.addEventListener('click', async () => {
    if (state.currentItemDetail?.mdPath) {
      await window.beeAPI.openFileInSystem(state.currentItemDetail.mdPath);
    }
  });

  el.btnOpenJson.addEventListener('click', async () => {
    if (state.currentItemDetail?.jsonPath) {
      await window.beeAPI.openFileInSystem(state.currentItemDetail.jsonPath);
    }
  });

  el.btnRevealFile.addEventListener('click', async () => {
    if (state.currentItemDetail?.mdPath) {
      await window.beeAPI.revealInFinder(state.currentItemDetail.mdPath);
    }
  });

  el.btnCopyTranscript.addEventListener('click', () => {
    const text = state.currentItemDetail?.markdownData || '';
    if (text) {
      navigator.clipboard.writeText(text);
      el.btnCopyTranscript.textContent = 'Copied!';
      setTimeout(() => {
        el.btnCopyTranscript.innerHTML = `<svg class="icon icon-xs" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg><span>Copy</span>`;
      }, 1500);
    }
  });

  // Settings: Radio mode change
  el.radioConnModes.forEach(radio => {
    radio.addEventListener('change', (e) => {
      const mode = e.target.value;
      if (mode === 'public') {
        el.inputEndpoint.value = 'https://api.developer.bee.amazon.dev';
        el.groupEndpoint.style.display = 'none';
        el.groupToken.style.display = 'flex';
      } else if (mode === 'proxy') {
        el.inputEndpoint.value = 'http://127.0.0.1:8787';
        el.groupEndpoint.style.display = 'none';
        el.groupToken.style.display = 'none'; // Proxy handles auth!
      } else if (mode === 'custom') {
        el.groupEndpoint.style.display = 'flex';
        el.groupToken.style.display = 'flex';
      }
    });
  });

  // Toggle token visibility
  el.btnToggleTokenVisibility.addEventListener('click', () => {
    if (el.inputToken.type === 'password') {
      el.inputToken.type = 'text';
      el.btnToggleTokenVisibility.textContent = 'Hide';
    } else {
      el.inputToken.type = 'password';
      el.btnToggleTokenVisibility.textContent = 'Show';
    }
  });

  // Test connection
  el.btnTestConnection.addEventListener('click', async () => {
    el.connResultAlert.style.display = 'none';
    el.btnTestConnection.disabled = true;
    el.btnTestConnection.textContent = 'Testing GET /v1/me...';

    const testConfig = {
      endpoint: el.inputEndpoint.value.trim(),
      token: el.inputToken.value.trim()
    };

    const res = await window.beeAPI.testConnection(testConfig);
    el.btnTestConnection.disabled = false;
    el.btnTestConnection.textContent = 'Verify Connection (GET /v1/me)';
    el.connResultAlert.style.display = 'flex';

    if (res.success) {
      el.connResultAlert.className = 'alert-box alert-success';
      const u = res.data;
      el.connResultAlert.innerHTML = `✅ Successfully connected to Bee! Logged in as: <strong>${escapeHtml(u.name || u.email || u.id || 'Bee Developer')}</strong>`;
      checkStatusIndicator();
    } else {
      el.connResultAlert.className = 'alert-box alert-error';
      el.connResultAlert.innerHTML = `❌ Connection failed: ${escapeHtml(res.message || 'Check your token or proxy')}`;
    }
  });

  // Save config
  el.btnSaveConfig.addEventListener('click', async () => {
    const updated = {
      endpoint: el.inputEndpoint.value.trim(),
      token: el.inputToken.value.trim(),
      storageDir: el.inputStorageDir.value.trim()
    };
    await window.beeAPI.saveConfig(updated);
    state.config = updated;
    el.sidebarStoragePath.textContent = updated.storageDir;
    alert('Settings saved successfully!');
    checkStatusIndicator();
  });

  // Folder actions
  el.btnBrowseFolder.addEventListener('click', async () => {
    const folder = await window.beeAPI.selectStorageFolder();
    if (folder) {
      el.inputStorageDir.value = folder;
      el.sidebarStoragePath.textContent = folder;
    }
  });

  el.btnOpenFolderSidebar.addEventListener('click', () => window.beeAPI.openStorageFolder());
  el.btnOpenStorageFinder.addEventListener('click', () => window.beeAPI.openStorageFolder());
  el.btnOpenFolderFilesPage.addEventListener('click', () => window.beeAPI.openStorageFolder());

  // ZIP export
  el.btnExportZip.addEventListener('click', exportZipFile);
  el.btnExportZipFilesPage.addEventListener('click', exportZipFile);

  // Load demo data
  el.btnLoadDemo.addEventListener('click', loadDemoData);

  // Modal Cancel
  el.btnCancelSync.addEventListener('click', async () => {
    await window.beeAPI.cancelSync();
    el.syncProgressMessage.textContent = 'Cancelling sync...';
  });

  // Sync Progress Listener from Electron Main
  window.beeAPI.onSyncProgress((progress) => {
    el.syncProgressFill.style.width = `${progress.percent}%`;
    el.syncProgressPercent.textContent = `${progress.percent}%`;
    el.syncProgressMessage.textContent = progress.message;
    appendSyncLog(progress.message);
  });
}

async function exportZipFile() {
  const res = await window.beeAPI.exportZip();
  if (res.success) {
    alert(`Backup complete! Saved zip file to:\n${res.path}`);
  } else if (!res.cancelled) {
    alert(`Export failed: ${res.error}`);
  }
}

// Start
document.addEventListener('DOMContentLoaded', init);
