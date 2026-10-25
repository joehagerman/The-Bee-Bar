/**
 * Bee Sync Engine
 * Handles communication with Bee.computer API (Public endpoint or Local proxy),
 * downloads all conversations, daily summaries, journals, todos, and facts,
 * formats them into Markdown and JSON, and manages local sync status.
 */

const fs = require('fs');
const path = require('path');
const archiver = require('archiver');
const {
  formatDate,
  formatDuration,
  getUtterances,
  formatConversationMarkdown,
  formatDailySummaryMarkdown,
  formatJournalMarkdown,
  formatTodosMarkdown,
  formatFactsMarkdown,
  formatInsightsMarkdown,
  formatPureTranscriptText,
  formatPureTranscriptMarkdown,
  classifyConversation
} = require('./markdown-formatter');

class BeeSyncEngine {
  constructor(options = {}) {
    this.endpoint = options.endpoint || 'http://127.0.0.1:8787';
    this.token = options.token || '';
    this.storageDir = options.storageDir || path.join(process.env.HOME || '', 'Documents', 'Bee Exports');
    this.isSyncing = false;
    this.cancelRequested = false;
  }

  updateConfig(config) {
    if (config.endpoint !== undefined) this.endpoint = config.endpoint.replace(/\/+$/, '');
    if (config.token !== undefined) this.token = config.token.trim();
    if (config.storageDir !== undefined) this.storageDir = config.storageDir;
  }

  getHeaders() {
    const headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8'
    };
    if (this.token && !this.endpoint.includes('127.0.0.1') && !this.endpoint.includes('localhost')) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    return headers;
  }

  async testConnection() {
    try {
      const url = `${this.endpoint}/v1/me`;
      const response = await fetch(url, {
        method: 'GET',
        headers: this.getHeaders()
      });

      if (!response.ok) {
        const errorText = await response.text();
        let errorJson;
        try { errorJson = JSON.parse(errorText); } catch(e) {}
        return {
          success: false,
          status: response.status,
          message: (errorJson && (errorJson.error || errorJson.message)) || `Server responded with ${response.status}: ${errorText}`
        };
      }

      const userData = await response.json();
      return {
        success: true,
        data: userData
      };
    } catch (err) {
      return {
        success: false,
        message: `Failed to connect to ${this.endpoint}: ${err.message}`
      };
    }
  }

  ensureDirectories() {
    const dirs = [
      this.storageDir,
      path.join(this.storageDir, 'conversations'),
      path.join(this.storageDir, 'transcripts'),
      path.join(this.storageDir, 'daily'),
      path.join(this.storageDir, 'journals'),
      path.join(this.storageDir, 'todos'),
      path.join(this.storageDir, 'facts'),
      path.join(this.storageDir, 'insights')
    ];
    for (const dir of dirs) {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    }
  }

  async fetchApi(pathUrl) {
    const cleanPath = pathUrl.startsWith('/') ? pathUrl : `/${pathUrl}`;
    const url = `${this.endpoint}${cleanPath}`;
    const response = await fetch(url, {
      method: 'GET',
      headers: this.getHeaders()
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`API Error ${response.status} on ${cleanPath}: ${errorText}`);
    }

    return await response.json();
  }

  async fetchAllPages(endpoint, primaryKey, fallbackKeys = [], maxPages = 100, onPageCallback = () => {}) {
    const allItems = [];
    let cursor = null;
    let page = 1;

    do {
      if (this.cancelRequested) break;
      const separator = endpoint.includes('?') ? '&' : '?';
      const url = cursor 
        ? `${endpoint}${separator}cursor=${encodeURIComponent(cursor)}` 
        : endpoint;

      let data;
      try {
        data = await this.fetchApi(url);
      } catch (e) {
        console.warn(`Pagination fetch error on ${url}:`, e.message);
        break;
      }

      let items = data[primaryKey];
      if (!Array.isArray(items)) {
        for (const fk of fallbackKeys) {
          if (Array.isArray(data[fk])) {
            items = data[fk];
            break;
          }
        }
      }

      if (Array.isArray(items)) {
        allItems.push(...items);
        onPageCallback(page, allItems.length);
      }

      cursor = data.next_cursor || null;
      page++;
      if (page > maxPages) break;
    } while (cursor);

    return allItems;
  }

  async searchApi({ query, neural = false, limit = 15 }) {
    const endpointPath = neural ? '/v1/search/conversations/neural' : '/v1/search/conversations';
    const url = `${this.endpoint}${endpointPath}`;
    const headers = this.getHeaders();

    const response = await fetch(url, {
      method: 'POST',
      headers,
      body: JSON.stringify({ query, limit })
    });

    if (!response.ok) {
      throw new Error(`Search failed (${response.status}): ${await response.text()}`);
    }

    return await response.json();
  }

  async syncAll(options = {}, progressCallback = () => {}) {
    if (this.isSyncing) {
      throw new Error('Sync is already in progress.');
    }

    const syncMode = (typeof options === 'string' ? options : options.mode) || 'all';
    const force = typeof options === 'object' && options.force ? true : false;
    const isAll = syncMode === 'all';

    this.isSyncing = true;
    this.cancelRequested = false;
    this.ensureDirectories();

    const stats = {
      mode: syncMode,
      conversations: 0,
      dailySummaries: 0,
      journals: 0,
      todos: 0,
      facts: 0,
      insights: 0,
      startTime: Date.now(),
      errors: []
    };

    const indexData = {
      lastSyncedAt: new Date().toISOString(),
      endpoint: this.endpoint,
      conversations: [],
      daily: [],
      journals: [],
      todos: [],
      facts: [],
      insights: []
    };

    try {
      progressCallback({ stage: 'init', message: `Initializing ${isAll ? 'complete archive' : 'recent'} sync...`, percent: 3 });
      
      let userProfile = null;
      try {
        userProfile = await this.fetchApi('/v1/me');
        indexData.user = userProfile;
      } catch (e) {
        progressCallback({ stage: 'warn', message: `Profile fetch warning: ${e.message}`, percent: 5 });
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 1. Facts
      progressCallback({ stage: 'facts', message: isAll ? 'Paging through all facts...' : 'Downloading recent facts...', percent: 8 });
      try {
        let facts = [];
        if (isAll) {
          facts = await this.fetchAllPages('/v1/facts', 'facts', [], 50, (p, total) => {
            progressCallback({ stage: 'facts', message: `Found ${total} facts (Page ${p})...`, percent: 10 });
          });
        } else {
          const factsData = await this.fetchApi('/v1/facts');
          facts = Array.isArray(factsData) ? factsData : (factsData.facts || []);
        }

        stats.facts = facts.length;
        indexData.facts = facts;
        fs.writeFileSync(path.join(this.storageDir, 'facts', 'facts.json'), JSON.stringify(facts, null, 2));
        fs.writeFileSync(path.join(this.storageDir, 'facts', 'facts.md'), formatFactsMarkdown(facts));
      } catch (err) {
        stats.errors.push(`Facts: ${err.message}`);
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 2. Todos & Suggestions
      progressCallback({ stage: 'todos', message: 'Downloading action items and todos...', percent: 14 });
      try {
        let todos = [];
        if (isAll) {
          todos = await this.fetchAllPages('/v1/todos', 'todos', [], 10);
        } else {
          const todosData = await this.fetchApi('/v1/todos');
          todos = Array.isArray(todosData) ? todosData : (todosData.todos || []);
        }

        stats.todos = todos.length;
        indexData.todos = todos;

        try {
          const suggData = await this.fetchApi('/v1/todoSuggestions');
          indexData.todoSuggestions = suggData.todoSuggestions || [];
          fs.writeFileSync(path.join(this.storageDir, 'todos', 'suggestions.json'), JSON.stringify(indexData.todoSuggestions, null, 2));
        } catch (se) {}

        fs.writeFileSync(path.join(this.storageDir, 'todos', 'todos.json'), JSON.stringify(todos, null, 2));
        fs.writeFileSync(path.join(this.storageDir, 'todos', 'todos.md'), formatTodosMarkdown(todos));
      } catch (err) {
        stats.errors.push(`Todos: ${err.message}`);
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 3. Behavioral Insights
      progressCallback({ stage: 'insights', message: 'Downloading AI behavioral insights (/v1/insights)...', percent: 18 });
      try {
        const insightsData = await this.fetchApi('/v1/insights');
        const insights = Array.isArray(insightsData) ? insightsData : (insightsData.insights || []);
        stats.insights = insights.length;
        indexData.insights = insights;

        fs.writeFileSync(path.join(this.storageDir, 'insights', 'insights.json'), JSON.stringify(insights, null, 2));
        fs.writeFileSync(path.join(this.storageDir, 'insights', 'insights.md'), formatInsightsMarkdown(insights));
      } catch (err) {}

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 4. Journals
      progressCallback({ stage: 'journals', message: 'Checking journals and voice memos...', percent: 22 });
      try {
        let journals = [];
        if (isAll) {
          journals = await this.fetchAllPages('/v1/journals', 'journals', [], 10);
        } else {
          const journalsData = await this.fetchApi('/v1/journals');
          journals = Array.isArray(journalsData) ? journalsData : (journalsData.journals || []);
        }

        let jCount = 0;
        for (const jItem of journals) {
          if (this.cancelRequested) break;
          const jId = jItem.id || jItem.journal_id;
          let fullJournal = jItem;
          if (jId) {
            try {
              const res = await this.fetchApi(`/v1/journals/${jId}`);
              fullJournal = res.journal || res;
            } catch (je) {}
          }
          const safeId = String(jId || `journal_${Date.now()}`).replace(/[^a-zA-Z0-9_-]/g, '_');
          fs.writeFileSync(path.join(this.storageDir, 'journals', `${safeId}.json`), JSON.stringify(fullJournal, null, 2));
          fs.writeFileSync(path.join(this.storageDir, 'journals', `${safeId}.md`), formatJournalMarkdown(fullJournal));
          indexData.journals.push({
            id: safeId,
            title: fullJournal.title || `Journal ${safeId}`,
            date: fullJournal.created_at || fullJournal.date,
            summarySnippet: (fullJournal.text || '').slice(0, 150)
          });
          jCount++;
        }
        stats.journals = jCount;
      } catch (err) {
        stats.errors.push(`Journals: ${err.message}`);
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 5. Daily Summaries
      progressCallback({ stage: 'daily', message: isAll ? 'Paging through all daily summaries...' : 'Downloading recent daily summaries...', percent: 28 });
      try {
        let dailies = [];
        if (isAll) {
          dailies = await this.fetchAllPages('/v1/daily', 'daily_summaries', ['daily', 'summaries'], 30, (p, total) => {
            progressCallback({ stage: 'daily', message: `Found ${total} daily summaries across ${p} pages...`, percent: 30 });
          });
        } else {
          const dailyData = await this.fetchApi('/v1/daily');
          dailies = Array.isArray(dailyData) ? dailyData : (dailyData.daily_summaries || dailyData.daily || dailyData.summaries || []);
        }

        let dCount = 0;
        const totalDailies = dailies.length;

        for (let idx = 0; idx < totalDailies; idx++) {
          if (this.cancelRequested) break;
          const dItem = dailies[idx];
          const dId = dItem.id || dItem.date;
          const safeId = String(dId || `daily_${Date.now()}`).replace(/[^a-zA-Z0-9_-]/g, '_');
          const jsonPath = path.join(this.storageDir, 'daily', `${safeId}.json`);
          const mdPath = path.join(this.storageDir, 'daily', `${safeId}.md`);

          let fullDaily = dItem;
          // Reuse existing file if available to speed up sync unless forced
          if (!force && fs.existsSync(jsonPath) && fs.statSync(jsonPath).size > 10) {
            try {
              const cached = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
              fullDaily = cached.daily_summary || cached;
            } catch(e) {}
          } else if (dId) {
            try {
              const res = await this.fetchApi(`/v1/daily/${dId}`);
              fullDaily = res.daily_summary || res;
              fs.writeFileSync(jsonPath, JSON.stringify(fullDaily, null, 2));
              fs.writeFileSync(mdPath, formatDailySummaryMarkdown(fullDaily));
            } catch (de) {
              fs.writeFileSync(jsonPath, JSON.stringify(fullDaily, null, 2));
              fs.writeFileSync(mdPath, formatDailySummaryMarkdown(fullDaily));
            }
          }

          const dTitle = fullDaily.short_summary || fullDaily.title || `Daily Summary ${safeId}`;
          const dDate = fullDaily.date_time || fullDaily.date || fullDaily.created_at;

          indexData.daily.push({
            id: safeId,
            date: dDate,
            title: dTitle,
            summarySnippet: (fullDaily.summary || fullDaily.short_summary || fullDaily.text || '').slice(0, 200).replace(/\n/g, ' ')
          });
          dCount++;

          if (idx % 5 === 0 || idx === totalDailies - 1) {
            progressCallback({
              stage: 'daily_item',
              message: `Processed daily summary ${idx + 1} of ${totalDailies}...`,
              percent: Math.round(30 + (idx / Math.max(1, totalDailies)) * 20)
            });
          }
        }
        stats.dailySummaries = dCount;
      } catch (err) {
        stats.errors.push(`Daily summaries: ${err.message}`);
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 6. Conversations & Transcripts
      progressCallback({ stage: 'conversations', message: isAll ? 'Paging through all conversations in your history...' : 'Fetching conversation list...', percent: 50 });
      try {
        let convList = [];
        if (isAll) {
          convList = await this.fetchAllPages('/v1/conversations', 'conversations', [], 50, (p, total) => {
            progressCallback({ stage: 'conversations_page', message: `Found ${total} conversations across ${p} pages...`, percent: 53 });
          });
        } else {
          const convsData = await this.fetchApi('/v1/conversations');
          convList = Array.isArray(convsData) ? convsData : (convsData.conversations || []);
        }

        let cCount = 0;
        const totalConvs = convList.length;

        for (let i = 0; i < totalConvs; i++) {
          if (this.cancelRequested) break;
          const convItem = convList[i];
          const convId = convItem.id;
          const safeId = String(convId || `conv_${Date.now()}`).replace(/[^a-zA-Z0-9_-]/g, '_');
          const jsonPath = path.join(this.storageDir, 'conversations', `${safeId}.json`);
          const mdPath = path.join(this.storageDir, 'conversations', `${safeId}.md`);

          let fullConv = convItem;

          // If file already exists locally with non-empty content, reuse it to save bandwidth and speed up full sync!
          const alreadyExists = !force && fs.existsSync(jsonPath) && fs.statSync(jsonPath).size > 10;

          if (alreadyExists) {
            try {
              const cached = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
              fullConv = cached.conversation || cached;
            } catch (e) {}
          } else if (convId) {
            const shortTitle = convItem.short_summary || convItem.title || convId || 'Conversation';
            progressCallback({
              stage: 'conversations_download',
              message: `Downloading transcript ${i + 1} of ${totalConvs}: "${shortTitle.slice(0, 35)}"...`,
              percent: Math.round(55 + (i / Math.max(1, totalConvs)) * 43)
            });

            try {
              const res = await this.fetchApi(`/v1/conversations/${convId}`);
              fullConv = res.conversation || res;
              fs.writeFileSync(jsonPath, JSON.stringify(fullConv, null, 2));
              fs.writeFileSync(mdPath, formatConversationMarkdown(fullConv));
            } catch (ce) {
              console.warn(`Detail fetch failed for conversation ${convId}:`, ce.message);
              fs.writeFileSync(jsonPath, JSON.stringify(fullConv, null, 2));
              fs.writeFileSync(mdPath, formatConversationMarkdown(fullConv));
            }
          }

          const durMs = fullConv.duration_ms || (fullConv.end_time && fullConv.start_time ? (fullConv.end_time - fullConv.start_time) : null);
          const utterances = getUtterances(fullConv);
          const cTitle = fullConv.short_summary || fullConv.title || fullConv.name || 
            (fullConv.summary ? fullConv.summary.replace(/^#+\s*/, '').split('\n')[0].slice(0, 80) : '') || 
            `Conversation ${safeId}`;

          const { tags, keywords } = classifyConversation(fullConv);

          // Always ensure dedicated transcript files exist
          const txtTranscriptPath = path.join(this.storageDir, 'transcripts', `${safeId}_transcript.txt`);
          const mdTranscriptPath = path.join(this.storageDir, 'transcripts', `${safeId}_transcript.md`);
          if (!fs.existsSync(txtTranscriptPath) || force) {
            fs.writeFileSync(txtTranscriptPath, formatPureTranscriptText(fullConv));
          }
          if (!fs.existsSync(mdTranscriptPath) || force) {
            fs.writeFileSync(mdTranscriptPath, formatPureTranscriptMarkdown(fullConv));
          }

          indexData.conversations.push({
            id: safeId,
            title: cTitle,
            created_at: fullConv.start_time || fullConv.created_at || fullConv.timestamp,
            duration_ms: durMs,
            summarySnippet: (fullConv.summary || fullConv.short_summary || '').slice(0, 200).replace(/\n/g, ' '),
            utteranceCount: utterances.length,
            tags,
            keywords,
            location: fullConv.primary_location?.address || null
          });
          cCount++;

          if (alreadyExists && (i % 10 === 0 || i === totalConvs - 1)) {
            progressCallback({
              stage: 'conversations_cached',
              message: `Verified transcript ${i + 1} of ${totalConvs}...`,
              percent: Math.round(55 + (i / Math.max(1, totalConvs)) * 43)
            });
          }
        }
        stats.conversations = cCount;
      } catch (err) {
        stats.errors.push(`Conversations: ${err.message}`);
      }

      // Save index metadata
      fs.writeFileSync(path.join(this.storageDir, 'metadata.json'), JSON.stringify(indexData, null, 2));

      stats.durationMs = Date.now() - stats.startTime;
      progressCallback({ 
        stage: 'completed', 
        message: `Sync complete! Saved ${stats.conversations} conversations, ${stats.dailySummaries} daily summaries, ${stats.facts} facts, and ${stats.todos} todos.`, 
        percent: 100, 
        stats 
      });

      return {
        success: true,
        stats,
        indexData
      };
    } catch (err) {
      progressCallback({ stage: 'error', message: err.message, percent: 100 });
      throw err;
    } finally {
      this.isSyncing = false;
    }
  }

  cancelSync() {
    this.cancelRequested = true;
  }

  loadLocalData(forceRebuild = false) {
    this.ensureDirectories();
    const metaPath = path.join(this.storageDir, 'metadata.json');
    if (!forceRebuild && fs.existsSync(metaPath)) {
      try {
        const raw = fs.readFileSync(metaPath, 'utf8');
        const parsed = JSON.parse(raw);
        if (parsed.conversations && parsed.conversations.length > 0 && parsed.conversations[0].tags) {
          return parsed;
        }
      } catch (e) {}
    }

    // Build index by scanning folders
    const indexData = {
      lastSyncedAt: null,
      conversations: [],
      daily: [],
      journals: [],
      todos: [],
      facts: [],
      insights: []
    };

    // Scan conversations
    const convDir = path.join(this.storageDir, 'conversations');
    if (fs.existsSync(convDir)) {
      const files = fs.readdirSync(convDir).filter(f => f.endsWith('.json'));
      for (const file of files) {
        try {
          const raw = JSON.parse(fs.readFileSync(path.join(convDir, file), 'utf8'));
          const c = raw.conversation || raw;
          const safeId = file.replace('.json', '');
          const durMs = c.duration_ms || (c.end_time && c.start_time ? (c.end_time - c.start_time) : null);
          const utterances = getUtterances(c);
          const cTitle = c.short_summary || c.title || c.name || 
            (c.summary ? c.summary.replace(/^#+\s*/, '').split('\n')[0].slice(0, 80) : '') || 
            `Conversation ${safeId}`;

          const { tags, keywords } = classifyConversation(c);

          // Ensure transcript files are created if missing
          const txtTranscriptPath = path.join(this.storageDir, 'transcripts', `${safeId}_transcript.txt`);
          const mdTranscriptPath = path.join(this.storageDir, 'transcripts', `${safeId}_transcript.md`);
          if (!fs.existsSync(txtTranscriptPath)) {
            try { fs.writeFileSync(txtTranscriptPath, formatPureTranscriptText(c)); } catch (e) {}
          }
          if (!fs.existsSync(mdTranscriptPath)) {
            try { fs.writeFileSync(mdTranscriptPath, formatPureTranscriptMarkdown(c)); } catch (e) {}
          }

          indexData.conversations.push({
            id: safeId,
            title: cTitle,
            created_at: c.start_time || c.created_at || c.timestamp,
            duration_ms: durMs,
            summarySnippet: (c.summary || c.short_summary || '').slice(0, 200).replace(/\n/g, ' '),
            utteranceCount: utterances.length,
            tags,
            keywords,
            location: c.primary_location?.address || null
          });
        } catch(e) {}
      }
    }

    // Scan daily
    const dailyDir = path.join(this.storageDir, 'daily');
    if (fs.existsSync(dailyDir)) {
      const files = fs.readdirSync(dailyDir).filter(f => f.endsWith('.json'));
      for (const file of files) {
        try {
          const raw = JSON.parse(fs.readFileSync(path.join(dailyDir, file), 'utf8'));
          const d = raw.daily_summary || raw;
          const safeId = file.replace('.json', '');
          const dTitle = d.short_summary || d.title || `Daily Summary ${safeId}`;
          const dDate = d.date_time || d.date || d.created_at;

          indexData.daily.push({
            id: safeId,
            date: dDate,
            title: dTitle,
            summarySnippet: (d.summary || d.short_summary || d.text || '').slice(0, 200).replace(/\n/g, ' ')
          });
        } catch(e) {}
      }
    }

    // Scan journals
    const jDir = path.join(this.storageDir, 'journals');
    if (fs.existsSync(jDir)) {
      const files = fs.readdirSync(jDir).filter(f => f.endsWith('.json'));
      for (const file of files) {
        try {
          const raw = JSON.parse(fs.readFileSync(path.join(jDir, file), 'utf8'));
          const j = raw.journal || raw;
          const safeId = file.replace('.json', '');
          indexData.journals.push({
            id: safeId,
            title: j.title || `Journal ${safeId}`,
            date: j.created_at || j.date,
            summarySnippet: (j.text || '').slice(0, 150)
          });
        } catch(e) {}
      }
    }

    // Load todos
    const todosPath = path.join(this.storageDir, 'todos', 'todos.json');
    if (fs.existsSync(todosPath)) {
      try {
        const raw = JSON.parse(fs.readFileSync(todosPath, 'utf8'));
        indexData.todos = Array.isArray(raw) ? raw : (raw.todos || []);
      } catch(e) {}
    }

    // Load facts
    const factsPath = path.join(this.storageDir, 'facts', 'facts.json');
    if (fs.existsSync(factsPath)) {
      try {
        const raw = JSON.parse(fs.readFileSync(factsPath, 'utf8'));
        indexData.facts = Array.isArray(raw) ? raw : (raw.facts || []);
      } catch(e) {}
    }

    // Load insights
    const insightsPath = path.join(this.storageDir, 'insights', 'insights.json');
    if (fs.existsSync(insightsPath)) {
      try {
        const raw = JSON.parse(fs.readFileSync(insightsPath, 'utf8'));
        indexData.insights = Array.isArray(raw) ? raw : (raw.insights || []);
      } catch(e) {}
    }

    // Load todo suggestions
    const suggPath = path.join(this.storageDir, 'todos', 'suggestions.json');
    if (fs.existsSync(suggPath)) {
      try {
        indexData.todoSuggestions = JSON.parse(fs.readFileSync(suggPath, 'utf8'));
      } catch(e) {}
    }

    return indexData;
  }

  getItemFile(type, id) {
    const validTypes = ['conversations', 'transcripts', 'daily', 'journals', 'insights'];
    if (!validTypes.includes(type)) {
      throw new Error(`Invalid type: ${type}`);
    }
    const safeId = String(id).replace(/[^a-zA-Z0-9_-]/g, '_');

    let jsonPath = path.join(this.storageDir, type === 'transcripts' ? 'conversations' : type, `${safeId}.json`);
    let mdPath = type === 'transcripts'
      ? path.join(this.storageDir, 'transcripts', `${safeId}_transcript.md`)
      : path.join(this.storageDir, type, `${safeId}.md`);
    let txtPath = path.join(this.storageDir, 'transcripts', `${safeId}_transcript.txt`);

    let jsonData = null;
    let markdownData = null;
    let textData = null;

    if (fs.existsSync(jsonPath)) {
      try {
        jsonData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
      } catch (e) {}
    }

    if (fs.existsSync(mdPath)) {
      try {
        markdownData = fs.readFileSync(mdPath, 'utf8');
      } catch (e) {}
    }

    if (fs.existsSync(txtPath)) {
      try {
        textData = fs.readFileSync(txtPath, 'utf8');
      } catch (e) {}
    }

    return {
      id: safeId,
      type,
      jsonPath,
      mdPath,
      txtPath,
      jsonData,
      markdownData,
      textData
    };
  }

  async exportZip(outputPath) {
    this.ensureDirectories();
    return new Promise((resolve, reject) => {
      const output = fs.createWriteStream(outputPath);
      const archive = archiver('zip', { zlib: { level: 9 } });

      output.on('close', () => {
        resolve({
          path: outputPath,
          bytes: archive.pointer()
        });
      });

      archive.on('error', (err) => reject(err));
      archive.pipe(output);

      archive.directory(this.storageDir, 'Bee_Export');
      archive.finalize();
    });
  }
}

module.exports = BeeSyncEngine;
