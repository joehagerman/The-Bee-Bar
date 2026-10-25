/**
 * Markdown Formatter for Bee.computer Exports
 * Formats conversations, summaries, daily reviews, journals, todos, and facts
 * into clean, readable Markdown documents suitable for Obsidian, Notion, GitHub, and local readers.
 */

function formatDate(ts) {
  if (!ts) return 'Unknown Date';
  try {
    let num = typeof ts === 'number' ? ts : (typeof ts === 'string' && /^\d+$/.test(ts) ? Number(ts) : null);
    const d = num !== null ? new Date(num) : new Date(String(ts));
    if (isNaN(d.getTime())) return String(ts);
    return d.toLocaleString('en-US', {
      dateStyle: 'medium',
      timeStyle: 'short'
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

function getUtterances(conv) {
  let utterances = conv.utterances || conv.messages || conv.transcript || [];
  if ((!utterances || utterances.length === 0) && Array.isArray(conv.transcriptions)) {
    utterances = conv.transcriptions.flatMap(t => t.utterances || []);
  }
  return utterances;
}

function formatConversationMarkdown(rawConv) {
  const conv = rawConv.conversation || rawConv;
  const title = conv.title || conv.short_summary || conv.name || 
    (conv.summary ? conv.summary.replace(/^#+\s*/, '').split('\n')[0].slice(0, 80) : '') || 
    `Conversation ${conv.id ? conv.id : ''}`;
    
  const dateStr = formatDate(conv.created_at || conv.start_time || conv.timestamp || conv.date);
  const updatedStr = conv.updated_at ? formatDate(conv.updated_at) : null;
  const durMs = conv.duration_ms || (conv.end_time && conv.start_time ? (conv.end_time - conv.start_time) : null);
  const durationStr = durMs ? formatDuration(durMs) : null;

  let md = `---
id: "${conv.id || ''}"
title: "${title.replace(/"/g, '\\"')}"
date: "${dateStr}"
${updatedStr ? `updated: "${updatedStr}"\n` : ''}${durationStr ? `duration: "${durationStr}"\n` : ''}type: conversation
source: bee.computer
---

# 💬 ${title}

- **Date:** ${dateStr}
${durationStr ? `- **Duration:** ${durationStr}\n` : ''}- **ID:** \`${conv.id || 'N/A'}\`
${conv.primary_location && conv.primary_location.address ? `- **Location:** ${conv.primary_location.address}\n` : ''}

`;

  // Summary / Executive Summary
  const summary = conv.summary || conv.executive_summary || conv.overview || (conv.conversation_summary ? conv.conversation_summary.text : null);
  if (summary) {
    md += `${summary}\n\n`;
  }

  // Key Highlights / Takeaways
  const keyPoints = conv.key_points || conv.takeaways || conv.highlights || conv.insights;
  if (Array.isArray(keyPoints) && keyPoints.length > 0) {
    md += `## 💡 Key Highlights & Insights\n\n`;
    for (const point of keyPoints) {
      if (typeof point === 'string') {
        md += `- ${point}\n`;
      } else if (point && point.text) {
        md += `- ${point.text}\n`;
      }
    }
    md += `\n`;
  }

  // Action Items / Todos
  const actionItems = conv.action_items || conv.todos || (conv.conversation_summary && conv.conversation_summary.todos);
  if (Array.isArray(actionItems) && actionItems.length > 0) {
    md += `## ✅ Action Items & Tasks\n\n`;
    for (const item of actionItems) {
      const text = typeof item === 'string' ? item : (item.text || item.title || JSON.stringify(item));
      const done = item.completed ? '[x]' : '[ ]';
      md += `- ${done} ${text}\n`;
    }
    md += `\n`;
  }

  // Topics
  const topics = conv.topics || conv.tags;
  if (Array.isArray(topics) && topics.length > 0) {
    md += `## 🏷️ Topics\n\n`;
    md += topics.map(t => `\`${typeof t === 'string' ? t : t.name || t.label}\``).join(' ') + '\n\n';
  }

  // Utterance Transcript
  md += `## 🎙️ Transcript\n\n`;
  const utterances = getUtterances(conv);
  
  if (Array.isArray(utterances) && utterances.length > 0) {
    for (const u of utterances) {
      const speaker = u.speaker || u.role || u.speaker_name || 'Speaker';
      const speakerIcon = speaker.toLowerCase().includes('you') || speaker.toLowerCase().includes('user') ? '👤' : (speaker.toLowerCase().includes('bee') ? '🐝' : '🗣️');
      const time = u.spoken_at ? formatDate(u.spoken_at) : (u.timestamp ? formatDate(u.timestamp) : (u.start !== undefined ? `${u.start}s` : ''));
      const text = u.text || u.content || u.utterance || '';
      
      md += `### ${speakerIcon} **${speaker}** ${time ? `*(${time})*` : ''}\n\n`;
      md += `> ${text.split('\n').join('\n> ')}\n\n`;
    }
  } else if (conv.transcript_text) {
    md += `${conv.transcript_text}\n\n`;
  } else if (conv.raw_transcript) {
    md += `${conv.raw_transcript}\n\n`;
  } else {
    md += `*No detailed utterance breakdown provided for this conversation.*\n\n`;
  }

  return md;
}

function formatDailySummaryMarkdown(rawDaily) {
  const daily = rawDaily.daily_summary || rawDaily;
  const dateStr = formatDate(daily.date_time || daily.date || daily.created_at || daily.timestamp);
  const title = daily.title || daily.short_summary || `Daily Executive Summary - ${dateStr}`;

  let md = `---
id: "${daily.id || ''}"
title: "${title.replace(/"/g, '\\"')}"
date: "${dateStr}"
type: daily-summary
source: bee.computer
---

# 🌅 ${title}

- **Date:** ${dateStr}
- **ID:** \`${daily.id || 'N/A'}\`

`;

  // Summary
  const summary = daily.summary || daily.short_summary || daily.executive_summary || daily.text || daily.content;
  if (summary) {
    md += `${summary}\n\n`;
  }

  // Morning / Evening Brief
  if (daily.morning_brief) {
    md += `### ☕ Morning Brief\n\n${daily.morning_brief}\n\n`;
  }
  if (daily.evening_brief || daily.evening_recap) {
    md += `### 🌙 Evening Recap\n\n${daily.evening_brief || daily.evening_recap}\n\n`;
  }
  if (daily.calendar_summary) {
    md += `### 📅 Calendar Summary\n\n${daily.calendar_summary}\n\n`;
  }
  if (daily.email_summary) {
    md += `### ✉️ Email Summary\n\n${daily.email_summary}\n\n`;
  }

  // Highlights
  const highlights = daily.highlights || daily.key_events || daily.takeaways;
  if (Array.isArray(highlights) && highlights.length > 0) {
    md += `## 🌟 Key Highlights\n\n`;
    for (const h of highlights) {
      const text = typeof h === 'string' ? h : (h.text || JSON.stringify(h));
      md += `- ${text}\n`;
    }
    md += `\n`;
  }

  // Action Items / Completed Todos
  if (Array.isArray(daily.todos) && daily.todos.length > 0) {
    md += `## ✅ Daily Tasks & Action Items\n\n`;
    for (const t of daily.todos) {
      const text = typeof t === 'string' ? t : (t.text || JSON.stringify(t));
      const done = t.completed ? '[x]' : '[ ]';
      md += `- ${done} ${text}\n`;
    }
    md += `\n`;
  }

  // Associated Conversations
  if (Array.isArray(daily.conversations) && daily.conversations.length > 0) {
    md += `## 💬 Conversations from this Day\n\n`;
    for (const c of daily.conversations) {
      const cTitle = c.short_summary || c.title || c.name || `Conversation ${c.id}`;
      md += `- **${cTitle}** (\`${c.id || ''}\`)\n`;
      if (c.summary) {
        md += `  > ${c.summary.slice(0, 200).replace(/\n/g, ' ')}\n`;
      }
    }
    md += `\n`;
  }

  return md;
}

function formatJournalMarkdown(rawJournal) {
  const journal = rawJournal.journal || rawJournal;
  const dateStr = formatDate(journal.created_at || journal.date);
  const title = journal.title || `Journal Entry - ${dateStr}`;

  let md = `---
id: "${journal.id || ''}"
title: "${title.replace(/"/g, '\\"')}"
date: "${dateStr}"
type: journal
source: bee.computer
---

# 📖 ${title}

- **Date:** ${dateStr}
- **ID:** \`${journal.id || 'N/A'}\`

`;

  const content = journal.text || journal.content || journal.entry;
  if (content) {
    md += `## ✍️ Journal Content\n\n${content}\n\n`;
  }

  if (Array.isArray(journal.reflections) && journal.reflections.length > 0) {
    md += `## 💭 Reflections\n\n`;
    for (const r of journal.reflections) {
      md += `- ${typeof r === 'string' ? r : r.text}\n`;
    }
    md += `\n`;
  }

  return md;
}

function formatTodosMarkdown(rawTodos) {
  const todos = Array.isArray(rawTodos) ? rawTodos : (rawTodos.todos || []);
  let md = `# ✅ Bee.computer Action Items & Todos\n\n`;
  md += `*Exported on ${new Date().toLocaleString()}*\n\n`;

  const pending = todos.filter(t => !t.completed);
  const completed = todos.filter(t => t.completed);

  md += `## ⏳ Pending Tasks (${pending.length})\n\n`;
  if (pending.length === 0) {
    md += `*No pending tasks!*\n\n`;
  } else {
    for (const t of pending) {
      const alarm = t.alarm_at ? ` ⏰ *(Alarm: ${formatDate(t.alarm_at)})*` : '';
      md += `- [ ] **${t.text || 'Untitled Task'}**${alarm} \`[${t.id || ''}]\`\n`;
    }
    md += `\n`;
  }

  md += `## ✔️ Completed Tasks (${completed.length})\n\n`;
  if (completed.length === 0) {
    md += `*No completed tasks.*\n\n`;
  } else {
    for (const t of completed) {
      md += `- [x] ~${t.text || 'Untitled Task'}~ \`[${t.id || ''}]\`\n`;
    }
    md += `\n`;
  }

  return md;
}

function formatFactsMarkdown(rawFacts) {
  const facts = Array.isArray(rawFacts) ? rawFacts : (rawFacts.facts || []);
  let md = `# 💡 Bee.computer Facts & Memory Bank\n\n`;
  md += `*Exported on ${new Date().toLocaleString()}*\n\n`;

  if (!Array.isArray(facts) || facts.length === 0) {
    md += `*No facts recorded yet.*\n`;
    return md;
  }

  for (const f of facts) {
    const status = f.confirmed ? '✅ Confirmed' : '❔ Unconfirmed';
    const date = f.created_at ? ` - *(${formatDate(f.created_at)})*` : '';
    const tags = Array.isArray(f.tags) && f.tags.length ? ` \`[${f.tags.join(', ')}]\`` : '';
    md += `- **${f.text || 'Untitled Fact'}** (${status})${tags}${date} \`[${f.id || ''}]\`\n`;
  }

  return md;
}

function formatInsightsMarkdown(rawInsights) {
  const insights = Array.isArray(rawInsights) ? rawInsights : (rawInsights.insights || []);
  let md = `# 🧠 Bee.computer Insights & Behavioral Patterns\n\n`;
  md += `*Exported on ${new Date().toLocaleString()}*\n\n`;

  if (!Array.isArray(insights) || insights.length === 0) {
    md += `*No insights extracted yet.*\n`;
    return md;
  }

  for (const ins of insights) {
    md += `### 💡 ${ins.title || 'Insight'}\n\n`;
    if (ins.description) {
      md += `${ins.description}\n\n`;
    }
    if (ins.category) {
      md += `*Category: \`${ins.category}\`*\n\n`;
    }
  }

  return md;
}

module.exports = {
  formatDate,
  formatDuration,
  getUtterances,
  formatConversationMarkdown,
  formatDailySummaryMarkdown,
  formatJournalMarkdown,
  formatTodosMarkdown,
  formatFactsMarkdown,
  formatInsightsMarkdown
};
