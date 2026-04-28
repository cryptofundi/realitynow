/* ============================================
   RealityCheck — Shared JS Utilities
   ============================================ */

// ── Header / Footer injection ──────────────
// Call on each page to inject shared components.
function injectHeader(config = {}) {
  const {
    type = 'home',        // 'home' | 'page' | 'step'
    title = '',
    subtitle = '',
    step = 1,
    totalSteps = 3,
    backHref = 'index.html',
    showNotif = false,
  } = config;

  let html = '';

  if (type === 'home') {
    html = `
      <header class="site-header">
        <div class="site-header-brand">
          <div class="site-header-logo">⚡</div>
          <div>
            <div class="site-header-name">RealityCheck</div>
            <div class="site-header-location" id="location-label" onclick="promptLocation()">
              📍 <span id="location-text">Banjara Hills, Hyderabad</span> ›
            </div>
          </div>
        </div>
        <div class="site-header-actions">
          ${showNotif ? `<button class="btn btn-icon btn-secondary" style="position:relative" onclick="window.location='validate.html'">
            🔔<span class="notif-dot" style="position:absolute;top:6px;right:6px"></span>
          </button>` : ''}
          <a href="profile.html" class="btn btn-icon btn-secondary" title="Profile">👤</a>
        </div>
      </header>`;
  }

  if (type === 'page') {
    html = `
      <header class="page-header">
        <a href="${backHref}" class="page-header-back" title="Back">←</a>
        <div class="page-header-content">
          <div class="page-header-title">${title}</div>
          ${subtitle ? `<div class="page-header-sub">${subtitle}</div>` : ''}
        </div>
      </header>`;
  }

  if (type === 'step') {
    const pct = Math.round((step / totalSteps) * 100);
    html = `
      <header class="step-header">
        <div class="step-header-top">
          <a href="${backHref}" class="page-header-back" title="Back">←</a>
          <div class="step-header-title">${title}</div>
          <span style="font-size:var(--text-xs);color:var(--color-text-tertiary)">
            ${step} / ${totalSteps}
          </span>
        </div>
        <div class="step-progress">
          <div class="step-progress-fill" style="width:${pct}%"></div>
        </div>
      </header>`;
  }

  const el = document.getElementById('header-slot');
  if (el) el.innerHTML = html;
}

function injectBottomNav(activePage = 'feed') {
  const pages = [
    { id: 'feed',     href: 'index.html',    icon: '🏠', label: 'Feed' },
    { id: 'validate', href: 'validate.html', icon: '✅', label: 'Validate' },
    { id: 'post',     href: 'post.html',     icon: '+',  label: '', isFab: true },
    { id: 'location', href: 'location.html', icon: '📍', label: 'Places' },
    { id: 'profile',  href: 'profile.html',  icon: '👤', label: 'Profile' },
  ];

  const items = pages.map(p => {
    if (p.isFab) {
      return `<a href="${p.href}" class="post-fab" title="Post reality">+</a>`;
    }
    const active = p.id === activePage ? 'active' : '';
    return `
      <a href="${p.href}" class="bottom-nav-item ${active}">
        <span class="bottom-nav-icon">${p.icon}</span>
        <span class="bottom-nav-label">${p.label}</span>
      </a>`;
  }).join('');

  const el = document.getElementById('bottom-nav-slot');
  if (el) el.innerHTML = `<nav class="bottom-nav">${items}</nav>`;
}

function injectFooter() {
  const html = `
    <footer class="site-footer">
      <div class="site-footer-inner">
        <div class="site-footer-brand">⚡ RealityCheck</div>
        <div class="site-footer-links">
          <a href="about.html" class="site-footer-link">How it works</a>
          <a href="#" class="site-footer-link">Privacy</a>
          <a href="#" class="site-footer-link">Terms</a>
        </div>
        <div class="site-footer-copy">
          Truth is on-chain. Immutable. Forever. · Built on Polygon
        </div>
      </div>
    </footer>`;
  const el = document.getElementById('footer-slot');
  if (el) el.innerHTML = html;
}

// ── Confidence helpers ─────────────────────
function confClass(pct) {
  if (pct >= 75) return 'high';
  if (pct >= 50) return 'medium';
  return 'low';
}

function confLabel(pct) {
  if (pct >= 75) return 'High confidence';
  if (pct >= 50) return 'Building confidence';
  return 'Low confidence';
}

// ── State helpers ──────────────────────────
function stateBadge(state) {
  const map = {
    BUSY:     { cls: 'badge-busy',     label: 'Busy' },
    MODERATE: { cls: 'badge-moderate', label: 'Moderate' },
    EMPTY:    { cls: 'badge-empty',    label: 'Empty' },
    SLOW:     { cls: 'badge-slow',     label: 'Congested' },
    CLOSED:   { cls: 'badge-closed',   label: 'Closed' },
  };
  const s = map[state] || map.EMPTY;
  return `<span class="badge ${s.cls}">${s.label}</span>`;
}

function stateColor(state) {
  const map = {
    BUSY: 'var(--color-busy)',
    MODERATE: 'var(--color-moderate)',
    EMPTY: 'var(--color-empty)',
    SLOW: 'var(--color-slow)',
    CLOSED: 'var(--color-closed)',
  };
  return map[state] || map.EMPTY;
}

// ── Freshness label ────────────────────────
function freshnessLabel(minutesAgo) {
  if (minutesAgo < 1)  return 'just now';
  if (minutesAgo < 60) return `${minutesAgo}m ago`;
  const h = Math.floor(minutesAgo / 60);
  return `${h}h ago`;
}

function freshnessClass(minutesAgo) {
  if (minutesAgo <= 5)  return 'high';
  if (minutesAgo <= 20) return 'medium';
  return 'low';
}

// ── Toast ──────────────────────────────────
function showToast(message, duration = 2500) {
  let toast = document.querySelector('.toast');
  if (!toast) {
    toast = document.createElement('div');
    toast.className = 'toast';
    document.body.appendChild(toast);
  }
  toast.textContent = message;
  toast.classList.add('show');
  clearTimeout(toast._timer);
  toast._timer = setTimeout(() => toast.classList.remove('show'), duration);
}

// ── Location prompt ────────────────────────
function promptLocation() {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      pos => showToast('📍 Location updated'),
      ()  => showToast('📍 Using saved location')
    );
  }
}

// ── Render feed card HTML ──────────────────
function renderFeedCard(post, index = 0) {
  const conf = post.confidence;
  const cls  = confClass(conf);
  const mins = post.minutesAgo;
  const freshCls = freshnessClass(mins);

  return `
    <article class="feed-card animate-fade-in stagger-${Math.min(index+1,5)}"
             onclick="window.location='location.html?id=${post.id}'">
      <div class="feed-card-image">
        <div class="feed-card-image-placeholder">
          <span style="font-size:28px">${post.categoryIcon}</span>
          <span>${post.locationName}</span>
        </div>
        <div class="feed-card-state-overlay">
          ${stateBadge(post.state)}
        </div>
      </div>
      <div class="feed-card-body">
        <div class="feed-card-meta">
          <div class="feed-card-location">${post.locationName}</div>
          <div class="feed-card-time"
               style="color:var(--color-conf-${freshCls})">
            ${freshnessLabel(mins)}
          </div>
        </div>
        <div class="feed-card-confidence">
          ${stateBadge(post.state)}
          <div class="conf-bar-wrap">
            <div class="conf-bar-fill ${cls}" style="width:${conf}%"></div>
          </div>
          <div class="feed-card-conf-label">${conf}%</div>
        </div>
        <div class="feed-card-actions">
          <button class="btn btn-confirm btn-sm"
                  style="flex:1"
                  onclick="event.stopPropagation();handleConfirm(${post.id})">
            ✓ Confirm · +1 credit
          </button>
          <button class="btn btn-danger btn-sm"
                  style="flex:1"
                  onclick="event.stopPropagation();handleDispute(${post.id})">
            ✗ Dispute
          </button>
        </div>
        <div class="feed-card-footnote">
          ${post.validatorCount} of 3 confirmed · ${post.blockchainHash}
        </div>
      </div>
    </article>`;
}

// ── Render gap card HTML ───────────────────
function renderGapCard(location) {
  return `
    <div class="gap-card animate-fade-in section-sm">
      <div class="gap-card-icon">⏱</div>
      <div class="gap-card-content">
        <div class="gap-card-title">No update — ${location.name}</div>
        <div class="gap-card-sub">
          Last report was ${location.staleMin} min ago.
          Earn +${location.reward} credits to check and post.
        </div>
        <a href="post.html?location=${encodeURIComponent(location.name)}"
           class="btn btn-sm"
           style="background:var(--color-brand-accent);color:#fff;border:none">
          Post update · earn +${location.reward} credits
        </a>
      </div>
    </div>`;
}

// ── Validation helpers ─────────────────────
function handleConfirm(postId) {
  showToast('✓ Confirmation submitted — +1 credit');
}

function handleDispute(postId) {
  showToast('✗ Dispute submitted');
}
