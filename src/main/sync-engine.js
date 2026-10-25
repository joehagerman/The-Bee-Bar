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
  formatInsightsMarkdown
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
      'Content-Type': 'application/json'
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

  async searchApi({ query, neural = false, limit = 15 }) {
    const endpointPath = neural ? '/v1/search/conversations/neural' : '/v1/search/conversations';
    const url = `${this.endpoint}${endpointPath}`;
    const headers = this.getHeaders();
    headers['Content-Type'] = 'application/json; charset=utf-8';

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

  async syncAll(progressCallback = () => {}) {
    if (this.isSyncing) {
      throw new Error('Sync is already in progress.');
    }

    this.isSyncing = true;
    this.cancelRequested = false;
    this.ensureDirectories();

    const stats = {
      conversations: 0,
      dailySummaries: 0,
      journals: 0,
      todos: 0,
      facts: 0,
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
      facts: []
    };

    try {
      progressCallback({ stage: 'init', message: 'Connecting to Bee API (/v1/me)...', percent: 5 });
      
      let userProfile = null;
      try {
        userProfile = await this.fetchApi('/v1/me');
        indexData.user = userProfile;
      } catch (e) {
        progressCallback({ stage: 'warn', message: `Profile fetch warning: ${e.message}`, percent: 8 });
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 1. Facts
      progressCallback({ stage: 'facts', message: 'Downloading facts memory bank (/v1/facts)...', percent: 12 });
      try {
        const factsData = await this.fetchApi('/v1/facts');
        const facts = Array.isArray(factsData) ? factsData : (factsData.facts || []);
        stats.facts = facts.length;
        indexData.facts = facts;

        fs.writeFileSync(path.join(this.storageDir, 'facts', 'facts.json'), JSON.stringify(facts, null, 2));
        fs.writeFileSync(path.join(this.storageDir, 'facts', 'facts.md'), formatFactsMarkdown(facts));
      } catch (err) {
        stats.errors.push(`Facts: ${err.message}`);
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 2. Todos & Suggestions
      progressCallback({ stage: 'todos', message: 'Downloading todos and action items (/v1/todos)...', percent: 20 });
      try {
        const todosData = await this.fetchApi('/v1/todos');
        const todos = Array.isArray(todosData) ? todosData : (todosData.todos || []);
        stats.todos = todos.length;
        indexData.todos = todos;

        // Also fetch suggestions if available
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

      // 2b. Insights & Behavioral Patterns
      progressCallback({ stage: 'insights', message: 'Downloading behavioral insights (/v1/insights)...', percent: 25 });
      try {
        const insightsData = await this.fetchApi('/v1/insights');
        const insights = Array.isArray(insightsData) ? insightsData : (insightsData.insights || []);
        stats.insights = insights.length;
        indexData.insights = insights;

        fs.writeFileSync(path.join(this.storageDir, 'insights', 'insights.json'), JSON.stringify(insights, null, 2));
        fs.writeFileSync(path.join(this.storageDir, 'insights', 'insights.md'), formatInsightsMarkdown(insights));
      } catch (err) {
        // Optional endpoint
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 3. Journals
      progressCallback({ stage: 'journals', message: 'Fetching journals (/v1/journals)...', percent: 30 });
      try {
        const journalsData = await this.fetchApi('/v1/journals');
        const journals = Array.isArray(journalsData) ? journalsData : (journalsData.journals || []);
        
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

      // 4. Daily Summaries
      progressCallback({ stage: 'daily', message: 'Fetching daily executive summaries (/v1/daily)...', percent: 45 });
      try {
        const dailyData = await this.fetchApi('/v1/daily');
        const dailies = Array.isArray(dailyData) ? dailyData : (dailyData.daily_summaries || dailyData.daily || dailyData.summaries || []);
        
        let dCount = 0;
        for (let idx = 0; idx < dailies.length; idx++) {
          if (this.cancelRequested) break;
          const dItem = dailies[idx];
          const dId = dItem.id || dItem.date;
          let fullDaily = dItem;
          if (dId) {
            try {
              const res = await this.fetchApi(`/v1/daily/${dId}`);
              fullDaily = res.daily_summary || res;
            } catch (de) {}
          }
          const safeId = String(dId || `daily_${Date.now()}`).replace(/[^a-zA-Z0-9_-]/g, '_');
          const dTitle = fullDaily.short_summary || fullDaily.title || `Daily Summary ${safeId}`;
          const dDate = fullDaily.date_time || fullDaily.date || fullDaily.created_at;

          fs.writeFileSync(path.join(this.storageDir, 'daily', `${safeId}.json`), JSON.stringify(fullDaily, null, 2));
          fs.writeFileSync(path.join(this.storageDir, 'daily', `${safeId}.md`), formatDailySummaryMarkdown(fullDaily));
          
          indexData.daily.push({
            id: safeId,
            date: dDate,
            title: dTitle,
            summarySnippet: (fullDaily.summary || fullDaily.short_summary || fullDaily.text || '').slice(0, 200).replace(/\n/g, ' ')
          });
          dCount++;
        }
        stats.dailySummaries = dCount;
      } catch (err) {
        stats.errors.push(`Daily summaries: ${err.message}`);
      }

      if (this.cancelRequested) throw new Error('Sync cancelled by user.');

      // 5. Conversations & Transcripts
      progressCallback({ stage: 'conversations', message: 'Fetching conversation list (/v1/conversations)...', percent: 60 });
      try {
        const convsData = await this.fetchApi('/v1/conversations');
        const convList = Array.isArray(convsData) ? convsData : (convsData.conversations || []);
        
        let cCount = 0;
        const totalConvs = convList.length;
        
        for (let i = 0; i < totalConvs; i++) {
          if (this.cancelRequested) break;
          const convItem = convList[i];
          const convId = convItem.id;
          let fullConv = convItem;

          const shortTitle = convItem.short_summary || convItem.title || convId || 'Conversation';
          progressCallback({
            stage: 'conversations_item',
            message: `Downloading transcript ${i + 1} of ${totalConvs}: "${shortTitle.slice(0, 40)}"...`,
            percent: Math.round(60 + (i / Math.max(1, totalConvs)) * 38)
          });

          if (convId) {
            try {
              const res = await this.fetchApi(`/v1/conversations/${convId}`);
              fullConv = res.conversation || res;
            } catch (ce) {
              console.warn(`Detail fetch failed for conversation ${convId}:`, ce.message);
            }
          }

          const safeId = String(convId || `conv_${Date.now()}`).replace(/[^a-zA-Z0-9_-]/g, '_');
          const jsonPath = path.join(this.storageDir, 'conversations', `${safeId}.json`);
          const mdPath = path.join(this.storageDir, 'conversations', `${safeId}.md`);

          fs.writeFileSync(jsonPath, JSON.stringify(fullConv, null, 2));
          fs.writeFileSync(mdPath, formatConversationMarkdown(fullConv));

          const durMs = fullConv.duration_ms || (fullConv.end_time && fullConv.start_time ? (fullConv.end_time - fullConv.start_time) : null);
          const utterances = getUtterances(fullConv);
          const cTitle = fullConv.short_summary || fullConv.title || fullConv.name || 
            (fullConv.summary ? fullConv.summary.replace(/^#+\s*/, '').split('\n')[0].slice(0, 80) : '') || 
            `Conversation ${safeId}`;

          indexData.conversations.push({
            id: safeId,
            title: cTitle,
            created_at: fullConv.start_time || fullConv.created_at || fullConv.timestamp,
            duration_ms: durMs,
            summarySnippet: (fullConv.summary || fullConv.short_summary || '').slice(0, 200).replace(/\n/g, ' '),
            utteranceCount: utterances.length
          });
          cCount++;
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
        message: `Sync complete! Saved ${stats.conversations} transcripts, ${stats.dailySummaries} daily summaries, ${stats.todos} todos, and ${stats.facts} facts.`, 
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

  loadLocalData() {
    this.ensureDirectories();
    const metaPath = path.join(this.storageDir, 'metadata.json');
    if (fs.existsSync(metaPath)) {
      try {
        const raw = fs.readFileSync(metaPath, 'utf8');
        return JSON.parse(raw);
      } catch (e) {
        // Fall back to scanning files
      }
    }

    // Build index by scanning folders
    const indexData = {
      lastSyncedAt: null,
      conversations: [],
      daily: [],
      journals: [],
      todos: [],
      facts: []
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

          indexData.conversations.push({
            id: safeId,
            title: cTitle,
            created_at: c.start_time || c.created_at || c.timestamp,
            duration_ms: durMs,
            summarySnippet: (c.summary || c.short_summary || '').slice(0, 200).replace(/\n/g, ' '),
            utteranceCount: utterances.length
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
    const validTypes = ['conversations', 'daily', 'journals'];
    if (!validTypes.includes(type)) {
      throw new Error(`Invalid type: ${type}`);
    }
    const safeId = String(id).replace(/[^a-zA-Z0-9_-]/g, '_');
    const jsonPath = path.join(this.storageDir, type, `${safeId}.json`);
    const mdPath = path.join(this.storageDir, type, `${safeId}.md`);

    let jsonData = null;
    let markdownData = null;

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

    return {
      id: safeId,
      type,
      jsonPath,
      mdPath,
      jsonData,
      markdownData
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
