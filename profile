<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Profile — RealityCheck</title>
  <link rel="stylesheet" href="css/variables.css" />
  <link rel="stylesheet" href="css/components.css" />
  <link rel="stylesheet" href="css/layout.css" />
  <script src="js/app.js"></script>
</head>
<body>

<div class="page-shell">
  <div id="header-slot"></div>

  <main class="page-content">
    <div class="page-content-inner">

      <!-- Profile header -->
      <div class="card card-body section-sm animate-fade-in">
        <div style="display:flex;align-items:center;gap:var(--space-4);margin-bottom:var(--space-4)">
          <div class="avatar" style="width:56px;height:56px;font-size:var(--text-md)">YO</div>
          <div style="flex:1">
            <div style="font-size:var(--text-lg);font-weight:var(--weight-semibold);
                        color:var(--color-text-primary)">You</div>
            <div style="font-size:var(--text-sm);color:var(--color-text-secondary)">
              Contributor · Banjara Hills area
            </div>
            <div style="margin-top:var(--space-2);display:flex;gap:var(--space-2);flex-wrap:wrap">
              <span class="badge" style="background:#EEEDFE;color:#3C3489">Score 18.4</span>
              <span class="badge badge-verified">84% accuracy</span>
            </div>
          </div>
        </div>

        <!-- Earnings summary -->
        <div style="background:linear-gradient(135deg,var(--color-brand-light),#fff);
                    border-radius:var(--radius-md);padding:var(--space-4);
                    display:flex;justify-content:space-between;align-items:center">
          <div>
            <div style="font-size:var(--text-xs);color:var(--color-brand-primary);
                        font-weight:var(--weight-semibold);text-transform:uppercase;
                        letter-spacing:0.06em;margin-bottom:var(--space-1)">Total earned</div>
            <div style="font-size:var(--text-2xl);font-weight:var(--weight-semibold);
                        color:var(--color-brand-primary)">₹42.80</div>
            <div style="font-size:var(--text-xs);color:var(--color-text-tertiary)">
              ₹28.50 posts · ₹14.30 validations
            </div>
          </div>
          <button class="btn btn-ghost btn-sm" onclick="claimRewards()">
            Claim to wallet
          </button>
        </div>

        <!-- Wallet claim notice (UPI users) -->
        <div id="claim-notice" style="margin-top:var(--space-3);padding:var(--space-3);
                                       background:#FEF8ED;border-radius:var(--radius-md);
                                       border:1px solid #f5dfa0">
          <div style="font-size:var(--text-sm);font-weight:var(--weight-medium);
                      color:#92610A;margin-bottom:var(--space-1)">
            💡 Connect a wallet to receive rewards
          </div>
          <div style="font-size:var(--text-xs);color:#B07B1A;margin-bottom:var(--space-2)">
            Your ₹42.80 is held securely in the smart contract. Connect MetaMask to claim.
          </div>
          <button class="btn btn-sm" onclick="connectWallet()"
                  style="background:#F5A623;color:white;border:none">
            Connect wallet → claim ₹42.80
          </button>
        </div>
      </div>

      <!-- Stats row -->
      <div class="stats-row section-sm animate-fade-in stagger-1">
        <div class="stat-card">
          <div class="stat-value">23</div>
          <div class="stat-label">Posts</div>
        </div>
        <div class="stat-card">
          <div class="stat-value">67</div>
          <div class="stat-label">Validations</div>
        </div>
        <div class="stat-card">
          <div class="stat-value" style="color:var(--color-brand-primary)">84%</div>
          <div class="stat-label">Accuracy</div>
        </div>
      </div>

      <!-- Reputation tiers -->
      <div class="section animate-fade-in stagger-2">
        <div class="section-label">Reputation tier</div>
        <div class="card">
          <div id="tier-list"></div>
        </div>
        <!-- Progress to next tier -->
        <div style="margin-top:var(--space-3);padding:var(--space-3) var(--space-4);
                    background:var(--color-surface-subtle);border-radius:var(--radius-md)">
          <div style="display:flex;justify-content:space-between;align-items:center;
                      margin-bottom:var(--space-2)">
            <span style="font-size:var(--text-sm);color:var(--color-text-secondary)">
              Progress to Trusted (score 20)
            </span>
            <span style="font-size:var(--text-sm);font-weight:var(--weight-semibold);
                         color:var(--color-brand-primary)">18.4 / 20</span>
          </div>
          <div class="progress-bar-wrap">
            <div class="progress-bar-fill" style="width:92%"></div>
          </div>
          <div style="font-size:var(--text-xs);color:var(--color-text-tertiary);margin-top:var(--space-2)">
            1.6 more score needed · +3 accurate validations will get you there
          </div>
        </div>
      </div>

      <!-- Recent activity -->
      <div class="section animate-fade-in stagger-3">
        <div class="section-label">Recent activity</div>
        <div class="card">
          <div id="activity-list"></div>
        </div>
      </div>

      <!-- Anti-gaming notice -->
      <div class="section animate-fade-in stagger-4">
        <div style="padding:var(--space-4);background:var(--color-surface-subtle);
                    border-radius:var(--radius-md)">
          <div style="font-size:var(--text-xs);color:var(--color-text-tertiary);
                      font-weight:var(--weight-semibold);text-transform:uppercase;
                      letter-spacing:0.06em;margin-bottom:var(--space-2)">How your identity works</div>
          <p style="font-size:var(--text-sm);color:var(--color-text-secondary);
                    line-height:var(--leading-relaxed)">
            Your identity is bound to your phone + device + session. This protects against
            fake accounts while keeping you anonymous. No name or email is ever stored.
            Validation limit: 10 per hour to prevent farming.
          </p>
        </div>
      </div>

    </div>
  </main>

  <div id="bottom-nav-slot"></div>
  <div id="footer-slot"></div>
</div>

<script>
  const TIERS = [
    { name: 'Newbie',      range: '0–5',   validate: false, weight: '1×',   reward: '1×',   current: false },
    { name: 'Contributor', range: '5–20',  validate: true,  weight: '1.5×', reward: '1.1×', current: true  },
    { name: 'Trusted',     range: '20–50', validate: true,  weight: '3×',   reward: '1.3×', current: false },
    { name: 'Expert',      range: '50+',   validate: true,  weight: '6×',   reward: '1.5×', current: false },
  ];

  const ACTIVITY = [
    { type: 'post',     icon: '📸', text: 'Posted: Jubilee Hills traffic — Slow',       time: '2h ago',  earn: '+₹2.40', ok: true  },
    { type: 'validate', icon: '✓',  text: 'Validated: GVK Mall — Busy (correct)',        time: '3h ago',  earn: '+₹0.33', ok: true  },
    { type: 'validate', icon: '✓',  text: 'Validated: Apollo Queue — Busy (correct)',    time: '5h ago',  earn: '+₹0.33', ok: true  },
    { type: 'post',     icon: '📸', text: 'Posted: PVNR traffic — Moderate',             time: '1d ago',  earn: '+₹2.40', ok: true  },
    { type: 'validate', icon: '✗',  text: 'Validated: Café — Empty (wrong)',             time: '1d ago',  earn: '₹0',     ok: false },
    { type: 'post',     icon: '📸', text: 'Posted: Inorbit Parking — Full',              time: '2d ago',  earn: '+₹1.80', ok: true  },
  ];

  document.addEventListener('DOMContentLoaded', () => {
    injectHeader({
      type: 'page',
      title: 'Profile',
      backHref: 'index.html',
    });
    injectBottomNav('profile');
    injectFooter();
    renderTiers();
    renderActivity();
  });

  function renderTiers() {
    const list = document.getElementById('tier-list');
    list.innerHTML = TIERS.map((t, i) => `
      <div style="display:flex;align-items:center;gap:var(--space-3);
                  padding:var(--space-3) var(--space-4);
                  border-bottom:${i < TIERS.length-1 ? '1px solid var(--color-border)' : 'none'};
                  background:${t.current ? 'var(--color-brand-light)' : 'transparent'}">
        <div style="width:32px;height:32px;border-radius:50%;
                    background:${t.current ? 'var(--color-brand-primary)' : 'var(--color-surface-subtle)'};
                    color:${t.current ? 'white' : 'var(--color-text-tertiary)'};
                    display:flex;align-items:center;justify-content:center;
                    font-size:var(--text-xs);font-weight:var(--weight-semibold);
                    flex-shrink:0">
          ${i + 1}
        </div>
        <div style="flex:1">
          <div style="font-size:var(--text-sm);font-weight:var(--weight-semibold);
                      color:${t.current ? 'var(--color-brand-dark)' : 'var(--color-text-primary)'}">
            ${t.name} (${t.range})
            ${t.current ? '<span style="font-size:10px;color:var(--color-brand-primary)"> ← you</span>' : ''}
          </div>
          <div style="font-size:var(--text-xs);color:var(--color-text-tertiary);margin-top:2px">
            Vote weight: ${t.weight} · Reward: ${t.reward} · Validate: ${t.validate ? '✓' : '✗'}
          </div>
        </div>
        ${t.current ? `<span class="badge badge-verified">Current</span>` : ''}
      </div>`).join('');
  }

  function renderActivity() {
    const list = document.getElementById('activity-list');
    list.innerHTML = ACTIVITY.map((a, i) => `
      <div style="display:flex;align-items:center;gap:var(--space-3);
                  padding:var(--space-3) var(--space-4);
                  border-bottom:${i < ACTIVITY.length-1 ? '1px solid var(--color-border)' : 'none'}">
        <div style="width:28px;height:28px;border-radius:50%;flex-shrink:0;
                    background:${a.ok ? 'var(--color-brand-light)' : 'var(--color-busy-bg)'};
                    color:${a.ok ? 'var(--color-brand-primary)' : 'var(--color-busy)'};
                    display:flex;align-items:center;justify-content:center;font-size:12px">
          ${a.icon}
        </div>
        <div style="flex:1;min-width:0">
          <div style="font-size:var(--text-sm);color:var(--color-text-primary);
                      white-space:nowrap;overflow:hidden;text-overflow:ellipsis">${a.text}</div>
          <div style="font-size:var(--text-xs);color:var(--color-text-tertiary)">${a.time}</div>
        </div>
        <span class="badge ${a.ok ? 'badge-earn' : 'badge-neutral'}" style="flex-shrink:0">
          ${a.earn}
        </span>
      </div>`).join('');
  }

  function claimRewards() {
    showToast('🔐 Connect MetaMask to claim ₹42.80');
  }

  function connectWallet() {
    showToast('🔐 MetaMask connection coming soon');
  }
</script>
</body>
</html>
