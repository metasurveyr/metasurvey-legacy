# Visual UI components for the Recipe Explorer

app_css <- function() {
  htmltools::tags$style(htmltools::HTML("
    :root {
      --slate-900: #0f172a;
      --slate-800: #1e293b;
      --slate-700: #334155;
      --slate-600: #475569;
      --slate-500: #64748b;
      --slate-400: #94a3b8;
      --slate-300: #cbd5e1;
      --slate-200: #e2e8f0;
      --slate-100: #f1f5f9;
      --slate-50:  #f8fafc;
      --indigo: #6366f1;
      --indigo-light: #818cf8;
      --indigo-50: #eef2ff;
      --emerald: #10b981;
      --emerald-50: #ecfdf5;
      --amber: #f59e0b;
      --amber-50: #fffbeb;
      --sky: #0ea5e9;
      --sky-50: #f0f9ff;
      --rose: #f43f5e;
      --violet: #8b5cf6;
    }

    /* ── Global ── */
    body { background: var(--slate-50); color: var(--slate-800); }
    .navbar {
      box-shadow: 0 1px 3px rgba(15,23,42,.08);
      border-bottom: 1px solid var(--slate-200);
    }

    /* ── Recipe Grid ── */
    .recipe-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 1rem;
      padding: 1rem 0;
    }

    /* ── Recipe Card ── */
    .recipe-card {
      border: 1px solid var(--slate-200);
      border-radius: 10px;
      overflow: hidden;
      transition: transform .15s ease,
        box-shadow .15s ease,
        border-color .15s ease;
      cursor: pointer;
      background: #fff;
    }
    .recipe-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 16px rgba(99,102,241,.1);
      border-color: var(--indigo-light);
    }
    .recipe-card-header {
      padding: .875rem 1.125rem .625rem;
      position: relative;
      border-bottom: 1px solid var(--slate-100);
    }
    .recipe-card-header.cert-community {
      background: var(--slate-50);
      color: var(--slate-800);
      border-left: 3px solid var(--amber);
    }
    .recipe-card-header.cert-reviewed {
      background: var(--sky-50);
      color: var(--slate-800);
      border-left: 3px solid var(--sky);
    }
    .recipe-card-header.cert-official {
      background: var(--emerald-50);
      color: var(--slate-800);
      border-left: 3px solid var(--emerald);
    }
    .recipe-card-header h5 {
      margin: 0;
      font-weight: 700;
      font-size: 1rem;
      line-height: 1.35;
      color: var(--slate-900);
    }
    .recipe-card-header .card-subtitle {
      color: var(--slate-500);
      font-size: .78rem;
      margin-top: .25rem;
    }
    .recipe-card-body {
      padding: .875rem 1.125rem;
    }
    .recipe-card-body .description {
      color: var(--slate-500);
      font-size: .84rem;
      line-height: 1.55;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      margin-bottom: .625rem;
    }
    .recipe-card-footer {
      padding: .625rem 1.125rem;
      background: var(--slate-50);
      border-top: 1px solid var(--slate-100);
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
    .recipe-card-footer .downloads {
      color: var(--slate-400);
      font-size: .78rem;
      display: flex;
      align-items: center;
      gap: .3rem;
    }
    .recipe-card-footer .btn-view {
      font-size: .78rem;
      padding: .2rem .7rem;
      border-radius: 6px;
      font-weight: 600;
    }

    /* ── Category Tags ── */
    .category-tag {
      display: inline-block;
      padding: .125rem .55rem;
      border-radius: 4px;
      font-size: .7rem;
      font-weight: 600;
      margin: .1rem;
      letter-spacing: .01em;
    }
    .tag-labor_market { background: #dcfce7; color: #166534; }
    .tag-income       { background: #dbeafe; color: #1e40af; }
    .tag-education    { background: #fef3c7; color: #92400e; }
    .tag-health       { background: #ffe4e6; color: #9f1239; }
    .tag-demographics { background: #f3e8ff; color: #6b21a8; }
    .tag-housing      { background: var(--slate-100); color: var(--slate-600); }
    .tag-default      { background: var(--slate-100); color: var(--slate-500); }

    /* ── Cert Badge ── */
    .cert-badge {
      display: inline-flex;
      align-items: center;
      gap: .3rem;
      padding: .15rem .6rem;
      border-radius: 4px;
      font-size: .7rem;
      font-weight: 700;
      text-transform: uppercase;
      letter-spacing: .04em;
    }
    .cert-badge-community {
      background: var(--amber-50);
      color: #92400e;
      border: 1px solid #fde68a;
    }
    .cert-badge-reviewed {
      background: var(--sky-50);
      color: #0369a1;
      border: 1px solid #bae6fd;
    }
    .cert-badge-official {
      background: var(--emerald-50);
      color: #065f46;
      border: 1px solid #a7f3d0;
    }

    /* ── Modal Positioning Fix ── */
    .modal-dialog {
      margin-top: 1.5rem !important;
    }
    .modal-content {
      max-height: 90vh;
      overflow-y: auto;
    }
    .modal-body {
      padding: 0;
    }

    /* ── Detail Modal ── */
    .recipe-detail-header {
      padding: 1.75rem 2rem 1.25rem;
      border-radius: 0;
      position: relative;
    }
    .recipe-detail-header.cert-community {
      background: var(--slate-800);
      color: #fff;
      border-bottom: 3px solid var(--amber);
    }
    .recipe-detail-header.cert-reviewed {
      background: var(--slate-800);
      color: #fff;
      border-bottom: 3px solid var(--sky);
    }
    .recipe-detail-header.cert-official {
      background: var(--slate-800);
      color: #fff;
      border-bottom: 3px solid var(--emerald);
    }
    .recipe-detail-header h3 {
      font-weight: 800;
      margin-bottom: .5rem;
      font-size: 1.35rem;
    }
    .recipe-detail-header .meta-row {
      display: flex;
      flex-wrap: wrap;
      gap: 1.25rem;
      font-size: .85rem;
      opacity: .85;
    }
    .recipe-detail-header .meta-item {
      display: flex;
      align-items: center;
      gap: .35rem;
    }

    /* ── Pipeline Graph ── */
    .pipeline-graph-container {
      background: var(--slate-50);
      border: 1px solid var(--slate-200);
      border-radius: 8px;
      overflow: hidden;
      margin-bottom: .5rem;
    }

    /* ── Workflow Timeline ── */
    .workflow-step {
      display: flex;
      align-items: flex-start;
      margin-bottom: .75rem;
      position: relative;
      padding-left: 2.25rem;
    }
    .workflow-step::before {
      content: '';
      position: absolute;
      left: 13px;
      top: 28px;
      bottom: -.75rem;
      width: 2px;
      background: var(--slate-200);
    }
    .workflow-step:last-child::before { display: none; }
    .wf-dot {
      position: absolute;
      left: 4px;
      top: 6px;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: .55rem;
      font-weight: 800;
      color: #fff;
      z-index: 1;
    }
    .wf-dot-svymean   { background: var(--amber); }
    .wf-dot-svytotal  { background: var(--rose); }
    .wf-dot-svyratio  { background: var(--violet); }
    .wf-dot-svyby     { background: var(--sky); }
    .step-type-svymean   { color: var(--amber); }
    .step-type-svytotal  { color: var(--rose); }
    .step-type-svyratio  { color: var(--violet); }
    .step-type-svyby     { color: var(--sky); }

    /* ── Pipeline Timeline ── */
    .pipeline-section { padding: 1.25rem 0; }
    .pipeline-step {
      display: flex;
      align-items: flex-start;
      margin-bottom: .75rem;
      position: relative;
      padding-left: 2.25rem;
    }
    .pipeline-step::before {
      content: '';
      position: absolute;
      left: 13px;
      top: 28px;
      bottom: -.75rem;
      width: 2px;
      background: var(--slate-200);
    }
    .pipeline-step:last-child::before { display: none; }
    .step-dot {
      position: absolute;
      left: 4px;
      top: 6px;
      width: 20px;
      height: 20px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: .6rem;
      font-weight: 800;
      color: #fff;
      z-index: 1;
    }
    .step-dot-compute  { background: var(--indigo); }
    .step-dot-recode   { background: var(--violet); }
    .step-dot-rename   { background: var(--amber); }
    .step-dot-remove   { background: var(--rose); }
    .step-dot-join     { background: var(--emerald); }
    .step-dot-default  { background: var(--slate-400); }
    .step-content {
      background: #fff;
      border: 1px solid var(--slate-200);
      border-radius: 6px;
      padding: .5rem .875rem;
      flex: 1;
    }
    .step-type {
      font-weight: 700;
      font-size: .78rem;
      text-transform: uppercase;
      letter-spacing: .04em;
    }
    .step-type-compute  { color: var(--indigo); }
    .step-type-recode   { color: var(--violet); }
    .step-type-rename   { color: var(--amber); }
    .step-type-remove   { color: var(--rose); }
    .step-type-join     { color: var(--emerald); }
    .step-outputs {
      color: var(--slate-800);
      font-size: .84rem;
      font-weight: 600;
    }

    /* ── Variable Chips ── */
    .var-chip {
      display: inline-block;
      padding: .15rem .55rem;
      border-radius: 4px;
      font-size: .75rem;
      font-family: 'SFMono-Regular', 'Consolas', monospace;
      margin: .1rem;
      font-weight: 500;
    }
    .var-chip-input {
      background: #dbeafe;
      color: #1e40af;
      border: 1px solid #bfdbfe;
    }
    .var-chip-output {
      background: #dcfce7;
      color: #166534;
      border: 1px solid #bbf7d0;
    }
    .var-chip-output-cat {
      background: #f3e8ff;
      color: #6b21a8;
      border: 1px solid #e9d5ff;
    }

    /* ── Cross-reference Chips ── */
    .cross-ref-chip {
      display: inline-block;
      padding: .2rem .65rem;
      border-radius: 5px;
      font-size: .78rem;
      font-weight: 600;
      cursor: pointer;
      transition: all .15s ease;
      margin: .1rem;
      text-decoration: none;
    }
    .cross-ref-recipe {
      background: var(--indigo-50);
      color: var(--indigo);
      border: 1px solid #c7d2fe;
    }
    .cross-ref-recipe:hover {
      background: var(--indigo); color: #fff;
    }
    .cross-ref-workflow {
      background: var(--amber-50); color: #92400e; border: 1px solid #fde68a;
    }
    .cross-ref-workflow:hover {
      background: var(--amber); color: #fff;
    }
    .est-type-badge {
      display: inline-block;
      padding: .125rem .5rem;
      border-radius: 4px;
      font-size: .7rem;
      font-weight: 600;
      margin: .1rem;
    }
    .est-type-annual    { background: #dcfce7; color: #166534; }
    .est-type-quarterly { background: #dbeafe; color: #1e40af; }
    .est-type-monthly   { background: #fef3c7; color: #92400e; }

    /* ── Edition Badges ── */
    .edition-badges {
      display: flex;
      flex-wrap: wrap;
      gap: .2rem;
      margin-top: .35rem;
    }
    .edition-badge {
      display: inline-block;
      padding: .1rem .35rem;
      border-radius: 3px;
      font-size: .62rem;
      font-weight: 600;
      background: rgba(99,102,241,.08);
      color: var(--indigo);
      border: 1px solid rgba(99,102,241,.15);
      letter-spacing: .02em;
    }

    /* ── Section Titles ── */
    .section-title {
      font-weight: 700;
      font-size: .9rem;
      color: var(--slate-700);
      padding-bottom: .5rem;
      margin-bottom: .875rem;
      border-bottom: 1px solid var(--slate-200);
      display: flex;
      align-items: center;
      gap: .4rem;
    }
    .section-title svg { opacity: .5; }

    /* ── Stats Row ── */
    .stat-box {
      text-align: center;
      padding: .875rem;
      border-radius: 8px;
      background: #fff;
      border: 1px solid var(--slate-200);
    }
    .stat-box .stat-number {
      font-size: 1.6rem;
      font-weight: 800;
      color: var(--indigo);
    }
    .stat-box .stat-label {
      font-size: .72rem;
      color: var(--slate-400);
      text-transform: uppercase;
      letter-spacing: .05em;
    }

    /* ── Navbar fix ── */
    .navbar .navbar-brand {
      display: flex;
      align-items: center;
      padding-top: 0;
      padding-bottom: 0;
    }

    /* ── Search Bar ── */
    .search-container {
      background: #fff;
      border-radius: 10px;
      padding: .75rem 1rem;
      border: 1px solid var(--slate-200);
      margin-bottom: 1rem;
    }
    .search-row {
      display: flex;
      align-items: center;
      gap: .5rem;
    }
    .search-field {
      flex: 2;
      min-width: 180px;
    }
    .filter-field {
      flex: 1;
      min-width: 120px;
    }
    .refresh-field {
      flex: 0 0 auto;
    }
    .search-row .form-group {
      margin-bottom: 0;
    }

    /* ── Hero Section ── */
    .hero-section {
      background: linear-gradient(
        135deg,
        var(--slate-900) 0%,
        var(--slate-800) 100%
      );
      border-radius: 12px;
      padding: 2rem 2.25rem;
      margin-bottom: 1.25rem;
      color: #fff;
      position: relative;
      overflow: hidden;
    }
    .hero-section::before {
      content: '';
      position: absolute;
      top: -40%;
      right: -10%;
      width: 300px;
      height: 300px;
      background: radial-gradient(
        circle,
        rgba(99,102,241,.2) 0%,
        transparent 70%
      );
      border-radius: 50%;
    }
    .hero-section h2 {
      font-weight: 800;
      font-size: 1.5rem;
      margin-bottom: .5rem;
      position: relative;
    }
    .hero-section .hero-subtitle {
      color: var(--slate-300);
      font-size: .9rem;
      line-height: 1.6;
      max-width: 600px;
      position: relative;
    }
    .hero-features {
      display: flex;
      gap: 1.5rem;
      margin-top: 1rem;
      flex-wrap: wrap;
      position: relative;
    }
    .hero-feature {
      display: flex;
      align-items: center;
      gap: .4rem;
      font-size: .8rem;
      color: var(--slate-300);
    }
    .hero-feature svg { color: var(--indigo-light); }

    /* ── Auth Layout ── */
    .auth-layout {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 0;
      max-width: 820px;
      margin: 2rem auto;
      background: #fff;
      border-radius: 14px;
      overflow: hidden;
      border: 1px solid var(--slate-200);
      box-shadow: 0 4px 24px rgba(15,23,42,.08);
    }
    .auth-branding {
      background: linear-gradient(
        135deg,
        var(--slate-900) 0%,
        #1e1b4b 100%
      );
      color: #fff;
      padding: 2.5rem 2rem;
      display: flex;
      flex-direction: column;
      justify-content: center;
      position: relative;
      overflow: hidden;
      min-height: 420px;
    }
    .auth-branding::before {
      content: '';
      position: absolute;
      bottom: -30%;
      right: -20%;
      width: 280px;
      height: 280px;
      background: radial-gradient(
        circle,
        rgba(99,102,241,.3) 0%,
        transparent 70%
      );
      border-radius: 50%;
    }
    .auth-branding::after {
      content: '';
      position: absolute;
      top: -20%;
      left: -15%;
      width: 200px;
      height: 200px;
      background: radial-gradient(
        circle,
        rgba(139,92,246,.18) 0%,
        transparent 70%
      );
      border-radius: 50%;
    }
    .auth-branding h2 {
      font-weight: 800;
      font-size: 1.6rem;
      margin-bottom: .75rem;
      position: relative;
    }
    .auth-branding .tagline {
      color: var(--slate-300);
      font-size: .88rem;
      line-height: 1.65;
      margin-bottom: 1.5rem;
      position: relative;
    }
    .auth-feature-list {
      list-style: none;
      padding: 0;
      margin: 0;
      position: relative;
    }
    .auth-feature-list li {
      display: flex;
      align-items: flex-start;
      gap: .5rem;
      padding: .4rem 0;
      font-size: .82rem;
      color: var(--slate-300);
    }
    .auth-feature-list li svg {
      color: var(--indigo-light);
      flex-shrink: 0;
      margin-top: 2px;
    }
    .auth-form-panel {
      padding: 2.5rem 2rem;
      display: flex;
      flex-direction: column;
      justify-content: center;
    }
    .auth-form-panel h3 {
      font-weight: 800;
      color: var(--slate-800);
      margin-bottom: .25rem;
      font-size: 1.2rem;
    }
    .auth-form-panel .auth-form-sub {
      color: var(--slate-400);
      font-size: .82rem;
      margin-bottom: 1.25rem;
    }
    .auth-form-panel .btn-primary {
      width: 100%;
      padding: .55rem;
      font-weight: 600;
      border-radius: 8px;
      font-size: .9rem;
    }
    .auth-form-panel .form-label {
      font-weight: 600;
      font-size: .82rem;
      color: var(--slate-600);
    }
    .auth-form-panel .form-control {
      border-radius: 8px;
      border-color: var(--slate-200);
      padding: .5rem .75rem;
    }
    .auth-form-panel .form-control:focus {
      border-color: var(--indigo);
      box-shadow: 0 0 0 3px rgba(99,102,241,.1);
    }
    .auth-form-panel .nav-pills .nav-link {
      font-weight: 600;
      font-size: .82rem;
      color: var(--slate-500);
      border-radius: 8px;
    }
    .auth-form-panel .nav-pills .nav-link.active {
      background: var(--indigo);
    }
    /* ── Auth Stats Bar ── */
    .auth-stats-bar {
      display: flex;
      gap: 1.25rem;
      margin-top: 2rem;
      padding-top: 1.25rem;
      border-top: 1px solid rgba(255,255,255,.1);
      position: relative;
    }
    .auth-stat {
      display: flex;
      flex-direction: column;
      gap: .15rem;
    }
    .auth-stat-num {
      font-size: .95rem;
      font-weight: 800;
      color: #fff;
      letter-spacing: -.01em;
    }
    .auth-stat-lbl {
      font-size: .7rem;
      color: var(--slate-400);
      text-transform: uppercase;
      letter-spacing: .04em;
    }
    /* ── Auth Legal Note ── */
    .auth-legal-note {
      display: flex;
      align-items: center;
      gap: .3rem;
      font-size: .72rem;
      color: var(--slate-400);
      margin-top: .6rem;
      margin-bottom: .25rem;
    }
    .auth-legal-note svg { color: var(--emerald); flex-shrink: 0; }
    /* ── Auth Switch Hint (login → register nudge) ── */
    .auth-switch-hint {
      font-size: .75rem;
      color: var(--slate-400);
      margin-top: .75rem;
      padding-top: .75rem;
      border-top: 1px solid var(--slate-100);
    }
    .auth-switch-hint strong { color: var(--indigo); }
    /* ── Register CTA Button ── */
    .btn-register-cta {
      background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%) !important;
      border: none !important;
      box-shadow: 0 4px 14px rgba(99,102,241,.35) !important;
      transition: box-shadow .2s, transform .15s !important;
    }
    .btn-register-cta:hover {
      box-shadow: 0 6px 20px rgba(99,102,241,.5) !important;
      transform: translateY(-1px);
    }
    .btn-register-cta:active { transform: translateY(0); }

    /* ── Empty State ── */
    .empty-state {
      text-align: center;
      padding: 3rem 2rem;
      color: var(--slate-400);
    }
    .empty-state svg { opacity: .25; margin-bottom: .75rem; }
    .empty-state h5 { color: var(--slate-500); font-weight: 600; }

    /* ── Profile ── */
    .profile-header {
      background: var(--slate-800);
      color: #fff;
      padding: 2rem;
      border-radius: 12px;
      margin-bottom: 1.25rem;
      border-bottom: 3px solid var(--indigo);
    }
    .profile-header h3 { font-weight: 800; font-size: 1.3rem; }
    .profile-header .user-type-label {
      display: inline-block;
      padding: .15rem .6rem;
      border-radius: 4px;
      background: rgba(255,255,255,.12);
      font-size: .78rem;
      margin-top: .4rem;
    }

    /* ── Code Block ── */
    .code-block-wrapper {
      position: relative;
      margin: .75rem 0;
    }
    .code-block-wrapper .code-block-header {
      display: flex;
      align-items: center;
      gap: .4rem;
      padding: .4rem .875rem;
      background: var(--slate-800);
      color: var(--slate-400);
      border-radius: 8px 8px 0 0;
      font-size: .75rem;
      font-weight: 600;
    }
    .code-block-wrapper pre {
      margin: 0;
      padding: .875rem 1rem;
      background: var(--slate-900);
      color: #e2e8f0;
      border-radius: 0 0 8px 8px;
      font-family: 'JetBrains Mono', 'Fira Code', 'Consolas', monospace;
      font-size: .8rem;
      line-height: 1.6;
      overflow-x: auto;
      white-space: pre;
      tab-size: 2;
    }
    .code-block-wrapper pre .code-comment { color: var(--slate-500); }
    .code-block-wrapper pre .code-string  { color: #86efac; }
    .code-block-wrapper pre .code-func    { color: var(--indigo-light); }
    .code-block-wrapper .btn-copy-code {
      position: absolute;
      top: .3rem;
      right: .4rem;
      padding: .15rem .5rem;
      font-size: .65rem;
      background: rgba(255,255,255,.08);
      color: var(--slate-400);
      border: 1px solid rgba(255,255,255,.1);
      border-radius: 4px;
      cursor: pointer;
      transition: all .15s;
    }
    .code-block-wrapper .btn-copy-code:hover {
      background: rgba(255,255,255,.15);
      color: #fff;
    }

    /* ── Token Section ── */
    .token-section {
      background: var(--indigo-50);
      border: 1px solid #c7d2fe;
      border-radius: 10px;
      padding: 1.25rem;
      margin-bottom: 1.25rem;
    }
    .token-section h5 {
      margin: 0 0 .75rem;
      font-weight: 700;
      color: var(--slate-800);
      font-size: .95rem;
    }
    .token-section .token-help {
      font-size: .78rem;
      color: var(--slate-500);
      margin-top: .6rem;
    }

    /* ── Responsive ── */
    @media (max-width: 768px) {
      .recipe-grid {
        grid-template-columns: 1fr;
        gap: .75rem;
      }
      .search-row {
        flex-wrap: wrap;
      }
      .search-field {
        flex: 1 1 100%;
      }
      .filter-field {
        flex: 1 1 calc(33% - .5rem);
      }
      .recipe-detail-header {
        padding: 1.25rem;
      }
      .recipe-detail-header h3 {
        font-size: 1.1rem;
      }
      .recipe-detail-header .meta-row {
        gap: .75rem;
        font-size: .8rem;
      }
      .stat-box .stat-number {
        font-size: 1.3rem;
      }
      .profile-header {
        padding: 1.25rem;
      }
      .auth-layout {
        grid-template-columns: 1fr;
        margin: 1rem;
      }
      .auth-branding {
        padding: 1.5rem;
      }
      .auth-branding h2 {
        font-size: 1.2rem;
      }
      .auth-form-panel {
        padding: 1.5rem;
      }
      .hero-section {
        padding: 1.5rem;
      }
      .hero-section h2 {
        font-size: 1.2rem;
      }
      .hero-features {
        gap: .75rem;
      }
      .code-block-wrapper pre {
        font-size: .72rem;
        padding: .625rem .75rem;
      }
    }
    @media (max-width: 576px) {
      .recipe-detail-header .meta-row {
        flex-direction: column;
        gap: .4rem;
      }
      .hero-features {
        flex-direction: column;
        gap: .4rem;
      }
    }

    /* ── Pipeline graph spinner ── */
    .graph-loading-wrapper {
      position: relative;
      min-height: 350px;
    }
    .graph-loading-wrapper .graph-spinner {
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: .75rem;
      color: var(--slate-400);
      font-size: .85rem;
      z-index: 10;
      pointer-events: none;
    }
    .graph-loading-wrapper .graph-spinner .spinner-ring {
      width: 36px;
      height: 36px;
      border: 3px solid var(--slate-200);
      border-top-color: var(--indigo);
      border-radius: 50%;
      animation: graph-spin .8s linear infinite;
    }
    .graph-loading-wrapper.loaded .graph-spinner {
      display: none;
    }
    @keyframes graph-spin {
      to { transform: translate(-50%, -50%) rotate(360deg); }
    }

    /* ── Star Rating ── */
    .star-rating {
      display: inline-flex;
      gap: .15rem;
      align-items: center;
    }
    .star-rating .star-btn {
      background: none;
      border: none;
      padding: 0;
      cursor: pointer;
      font-size: 1.25rem;
      color: var(--slate-300);
      transition: color .15s;
      line-height: 1;
    }
    .star-rating .star-btn:hover,
    .star-rating .star-btn.active {
      color: var(--amber);
    }
    .star-rating .star-btn.readonly {
      cursor: default;
    }
    .star-rating-summary {
      display: inline-flex;
      align-items: center;
      gap: .35rem;
      font-size: .8rem;
      color: var(--slate-500);
    }
    .star-rating-summary .star-avg {
      font-weight: 700;
      color: var(--amber);
    }
    .star-rating-inline {
      display: inline-flex;
      align-items: center;
      gap: .25rem;
      margin-left: .75rem;
    }
    .star-rating-inline .star-icon {
      color: var(--amber);
      font-size: .8rem;
    }

    /* ── Comments ── */
    .comments-section {
      padding: 1rem 0;
    }
    .comment-card {
      display: flex;
      gap: .75rem;
      padding: .75rem 0;
      border-bottom: 1px solid var(--slate-100);
    }
    .comment-card:last-child {
      border-bottom: none;
    }
    .comment-avatar {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      background: var(--indigo-50);
      color: var(--indigo);
      display: flex;
      align-items: center;
      justify-content: center;
      font-weight: 700;
      font-size: .75rem;
      flex-shrink: 0;
    }
    .comment-body {
      flex: 1;
      min-width: 0;
    }
    .comment-meta {
      display: flex;
      align-items: center;
      gap: .5rem;
      margin-bottom: .25rem;
    }
    .comment-author {
      font-weight: 600;
      font-size: .82rem;
      color: var(--slate-800);
    }
    .comment-date {
      font-size: .72rem;
      color: var(--slate-400);
    }
    .comment-text {
      font-size: .85rem;
      color: var(--slate-600);
      line-height: 1.5;
    }
    .comment-delete {
      background: none;
      border: none;
      color: var(--slate-400);
      cursor: pointer;
      font-size: .7rem;
      padding: .1rem .3rem;
      border-radius: 3px;
      transition: all .15s;
    }
    .comment-delete:hover {
      color: var(--rose);
      background: rgba(244,63,94,.08);
    }
    .comment-form {
      display: flex;
      gap: .5rem;
      margin-top: .75rem;
      align-items: flex-start;
    }
    .comment-form textarea {
      flex: 1;
      border: 1px solid var(--slate-200);
      border-radius: 6px;
      padding: .5rem .75rem;
      font-size: .82rem;
      resize: vertical;
      min-height: 60px;
      max-height: 150px;
      font-family: inherit;
      color: var(--slate-800);
    }
    .comment-form textarea:focus {
      outline: none;
      border-color: var(--indigo);
      box-shadow: 0 0 0 2px rgba(99,102,241,.1);
    }
    .comment-form .btn-comment {
      padding: .5rem .75rem;
      font-size: .78rem;
      border-radius: 6px;
      white-space: nowrap;
    }
    .empty-comments {
      text-align: center;
      padding: 1.5rem;
      color: var(--slate-400);
      font-size: .85rem;
    }

    /* ── Dependents (Used by) ── */
    .dependents-section {
      padding: 1rem 0;
    }

    /* ── Pipeline graph disclaimer ── */
    .graph-disclaimer {
      display: flex;
      align-items: center;
      gap: .5rem;
      padding: .5rem .75rem;
      margin-bottom: .5rem;
      background: #fef3c7;
      color: #92400e;
      border: 1px solid #fde68a;
      border-radius: 6px;
      font-size: .78rem;
      line-height: 1.4;
    }
  "))
}

# --- Component builders ---

cert_badge <- function(level) {
  cls <- paste0("cert-badge cert-badge-", level)
  icon <- switch(level,
    "official"  = bsicons::bs_icon("star-fill", size = ".75rem"),
    "reviewed"  = bsicons::bs_icon("check-circle-fill", size = ".75rem"),
    "community" = bsicons::bs_icon("people-fill", size = ".75rem"),
    ""
  )
  label <- switch(level,
    "official" = "Official",
    "reviewed" = "Reviewed",
    "community" = "Community",
    level
  )
  htmltools::tags$span(class = cls, icon, label)
}

category_tag <- function(name) {
  if (is.null(name) || length(name) == 0 || !nzchar(name)) {
    return(NULL)
  }
  cls <- paste0("category-tag tag-", name)
  # Fallback for unknown categories
  known <- c(
    "labor_market", "income", "education",
    "health", "demographics", "housing"
  )
  if (!name %in% known) {
    cls <- "category-tag tag-default"
  }
  pretty <- gsub("_", " ", name)
  htmltools::tags$span(class = cls, pretty)
}

format_downloads <- function(n) {
  n <- as.integer(n)
  if (n >= 1000) {
    paste0(round(n / 1000, 1), "k")
  } else {
    as.character(n)
  }
}

# Reusable code block with copy button
code_block_ui <- function(code, label = "R Code", block_id = NULL) {
  if (is.null(block_id)) {
    block_id <- paste0(
      "cb_",
      as.integer(Sys.time() * 1000) %% 1e6
    )
  }
  # Strip HTML tags and decode entities for clipboard
  plain_code <- gsub("<[^>]+>", "", code)
  plain_code <- gsub("&lt;", "<", plain_code)
  plain_code <- gsub("&gt;", ">", plain_code)
  plain_code <- gsub("&amp;", "&", plain_code)
  escaped_code <- gsub("'", "\\\\'", gsub("\n", "\\\\n", plain_code))
  copy_js <- sprintf(
    paste0(
      "var btn=this; ",
      "navigator.clipboard.writeText('%s')",
      ".then(function(){",
      "btn.textContent='Copied!'; ",
      "setTimeout(function(){",
      "btn.textContent='Copy'},1500)});"
    ),
    escaped_code
  )

  htmltools::tags$div(
    class = "code-block-wrapper",
    htmltools::tags$div(
      class = "code-block-header",
      bsicons::bs_icon("code-slash", size = ".85rem"),
      label
    ),
    htmltools::tags$button(
      class = "btn-copy-code",
      onclick = htmltools::HTML(copy_js),
      "Copy"
    ),
    htmltools::tags$pre(htmltools::HTML(code))
  )
}

# Hero section for explore pages
hero_section_ui <- function(type = "recipes") {
  if (type == "recipes") {
    htmltools::tags$div(
      class = "hero-section",
      htmltools::tags$h2(
        bsicons::bs_icon("journal-code", size = "1.4rem"),
        " Recipes"
      )
    )
  } else {
    htmltools::tags$div(
      class = "hero-section",
      htmltools::tags$h2(
        bsicons::bs_icon("bar-chart-fill", size = "1.4rem"),
        " Workflows"
      )
    )
  }
}

# Format edition display — handles single string or array
format_edition <- function(edition) {
  eds <- as.character(unlist(edition))
  if (length(eds) == 0) {
    return("Unknown")
  }
  if (length(eds) == 1) {
    return(eds)
  }
  # Show range for consecutive years
  paste0(eds[1], "-", eds[length(eds)])
}

# Star rating display for cards (read-only inline)
star_rating_inline <- function(average, count) {
  avg_raw <- average %||% 0
  avg <- round(as.numeric(if (length(avg_raw) == 0) 0 else avg_raw[[1]]), 1)
  n_raw <- count %||% 0
  n <- as.integer(if (length(n_raw) == 0) 0L else n_raw[[1]])
  if (n == 0) {
    return(NULL)
  }
  htmltools::tags$span(
    class = "star-rating-inline",
    htmltools::tags$span(
      class = "star-icon",
      bsicons::bs_icon("star-fill", size = ".75rem")
    ),
    htmltools::tags$span(
      style = paste0(
        "font-weight:600;",
        "font-size:.78rem;",
        "color:var(--amber);"
      ),
      avg
    ),
    htmltools::tags$span(
      style = paste0(
        "font-size:.72rem;",
        "color:var(--slate-400);"
      ),
      paste0("(", n, ")")
    )
  )
}

# Interactive star rating widget for detail views
star_rating_widget <- function(ns, id_prefix,
                               average = 0,
                               count = 0,
                               user_value = NULL,
                               logged_in = FALSE) {
  avg_raw <- average %||% 0
  avg <- round(as.numeric(if (length(avg_raw) == 0) 0 else avg_raw[[1]]), 1)
  n_raw <- count %||% 0
  n <- as.integer(if (length(n_raw) == 0) 0L else n_raw[[1]])
  uv_raw <- user_value %||% 0
  uv <- as.integer(if (length(uv_raw) == 0) 0L else uv_raw[[1]])

  stars <- lapply(1:5, function(i) {
    filled <- i <= uv
    cls <- paste0(
      "star-btn",
      if (filled) " active" else "",
      if (!logged_in) " readonly" else ""
    )
    icon <- if (filled) "star-fill" else "star"
    if (logged_in) {
      htmltools::tags$button(
        class = cls,
        onclick = sprintf(
          "Shiny.setInputValue('%s', %d, {priority: 'event'})",
          ns(paste0(id_prefix, "_star_click")), i
        ),
        bsicons::bs_icon(icon, size = "1.1rem")
      )
    } else {
      htmltools::tags$span(
        class = cls,
        bsicons::bs_icon(
          if (i <= round(avg)) "star-fill" else "star",
          size = "1.1rem"
        )
      )
    }
  })

  htmltools::tags$div(
    style = "display:flex;align-items:center;gap:.75rem;",
    htmltools::tags$div(class = "star-rating", stars),
    htmltools::tags$span(
      class = "star-rating-summary",
      htmltools::tags$span(class = "star-avg", avg),
      paste0("(", n, " ", if (n == 1) "rating" else "ratings", ")")
    )
  )
}

# Comment card component
comment_card_ui <- function(comment, ns,
                            current_user = NULL) {
  user_name <- comment$user_name %||%
    comment$user %||% "Anonymous"
  initials <- toupper(substr(user_name, 1, 1))
  date_str <- comment$created_at %||% ""
  if (nzchar(date_str)) {
    date_str <- tryCatch(
      format(as.POSIXct(date_str), "%b %d, %Y"),
      error = function(e) date_str
    )
  }
  is_author <- !is.null(current_user) &&
    identical(comment$user, current_user)

  htmltools::tags$div(
    class = "comment-card",
    htmltools::tags$div(class = "comment-avatar", initials),
    htmltools::tags$div(
      class = "comment-body",
      htmltools::tags$div(
        class = "comment-meta",
        htmltools::tags$span(
          class = "comment-author", user_name
        ),
        htmltools::tags$span(
          class = "comment-date", date_str
        ),
        if (is_author && !is.null(ns)) {
          htmltools::tags$button(
            class = "comment-delete",
            onclick = sprintf(
              "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
              ns("delete_comment"), comment$id
            ),
            bsicons::bs_icon("trash", size = ".7rem"),
            " Delete"
          )
        }
      ),
      htmltools::tags$div(
        class = "comment-text",
        comment$text %||% ""
      )
    )
  )
}

# Comments section (list + form)
comments_section_ui <- function(comments, ns,
                                id_prefix,
                                current_user = NULL,
                                logged_in = FALSE) {
  comment_list <- if (length(comments) > 0) {
    htmltools::tagList(lapply(comments, function(c) {
      comment_card_ui(c, ns, current_user)
    }))
  } else {
    htmltools::tags$div(
      class = "empty-comments",
      "No comments yet."
    )
  }

  form <- if (logged_in && !is.null(ns)) {
    htmltools::tags$div(
      class = "comment-form",
      htmltools::tags$textarea(
        id = ns(paste0(id_prefix, "_comment_text")),
        placeholder = "Add a comment...",
        maxlength = "2000"
      ),
      htmltools::tags$button(
        class = "btn btn-sm btn-primary btn-comment",
        onclick = sprintf(
          paste0(
            "var ta=document.getElementById('%s');",
            "if(ta.value.trim()){",
            "Shiny.setInputValue('%s',ta.value,{priority:'event'});",
            "ta.value='';}"
          ),
          ns(paste0(id_prefix, "_comment_text")),
          ns(paste0(id_prefix, "_submit_comment"))
        ),
        bsicons::bs_icon("send", size = ".75rem"),
        " Send"
      )
    )
  }

  htmltools::tags$div(
    class = "comments-section",
    htmltools::tags$div(
      class = "section-title",
      bsicons::bs_icon("chat-dots-fill"),
      paste("Comments (", length(comments), ")")
    ),
    comment_list,
    form
  )
}

# Dependents section (backlinks)
dependents_section_ui <- function(dependents, ns = NULL) {
  if (length(dependents) == 0) {
    return(NULL)
  }

  dep_chips <- lapply(dependents, function(dep) {
    dep_name <- dep$name %||% dep$id
    if (!is.null(ns)) {
      htmltools::tags$span(
        class = "cross-ref-chip cross-ref-recipe",
        onclick = sprintf(
          "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
          ns("navigate_dep_recipe"), dep$id
        ),
        bsicons::bs_icon("journal-code", size = ".75rem"),
        " ", dep_name
      )
    } else {
      htmltools::tags$span(
        class = "cross-ref-chip cross-ref-recipe",
        bsicons::bs_icon("journal-code", size = ".75rem"),
        " ", dep_name
      )
    }
  })

  htmltools::tags$div(
    class = "dependents-section",
    htmltools::tags$div(
      class = "section-title",
      bsicons::bs_icon("diagram-2-fill"),
      paste("Used by (", length(dependents), "recipes )")
    ),
    htmltools::tagList(dep_chips)
  )
}

# Build S3 object path from recipe data_source metadata
s3_object_path <- function(recipe, edition_str) {
  ds <- recipe$data_source
  if (is.null(ds) || is.null(ds$s3_bucket)) {
    return(NULL)
  }
  s3_file <- gsub("\\{edition\\}", edition_str, ds$file_pattern %||% "")
  list(
    bucket = ds$s3_bucket,
    object = paste0(ds$s3_prefix, s3_file)
  )
}

# Convert a weight_spec to add_weight() R code (HTML-escaped)
.weight_spec_to_code <- function(ws) {
  if (is.null(ws) || length(ws) == 0) {
    return(NULL)
  }
  parts <- character(0)
  for (pname in names(ws)) {
    entry <- ws[[pname]]
    if (is.null(entry$type) || entry$type == "simple") {
      parts <- c(parts, paste0(
        pname, ' = <span class="code-string">"', entry$variable, '"</span>'
      ))
    } else if (entry$type == "replicate") {
      src <- entry$replicate_source
      if (!is.null(src) && identical(src$provider, "anda")) {
        rep_path <- paste0(
          '<span class="code-func">anda_download_microdata</span>(',
          '<span class="code-string">"', src$edition %||% "2023", '"</span>, ',
          'resource = <span class="code-string">"', src$resource, '"</span>)'
        )
      } else {
        rep_path <- paste0(
          '<span class="code-string">',
          '"path/to/replicate_weights"',
          "</span>"
        )
      }
      rep_id_str <- paste0(
        'c(<span class="code-string">',
        '"ID"</span> = ',
        '<span class="code-string">',
        '"ID"</span>)'
      )
      if (!is.null(entry$replicate_id)) {
        sk <- entry$replicate_id$survey_key %||% "ID"
        rk <- entry$replicate_id$replicate_key %||% "ID"
        rep_id_str <- paste0(
          paste0(
            'c(<span class="code-string">"',
            sk,
            '"</span> = ',
            '<span class="code-string">"',
            rk, '"</span>)'
          )
        )
      }
      parts <- c(parts, paste0(
        pname, ' = <span class="code-func">add_replicate</span>(\n',
        '    <span class="code-string">"',
        entry$variable %||% "W",
        '"</span>,\n',
        "    replicate_path = ", rep_path, ",\n",
        "    replicate_pattern = ",
        '<span class="code-string">"',
        entry$replicate_pattern %||% "wr[0-9]+",
        '"</span>,\n',
        "    replicate_id = ", rep_id_str, ",\n",
        "    replicate_type = ",
        '<span class="code-string">"',
        entry$replicate_type %||% "bootstrap",
        '"</span>\n',
        "  )"
      ))
    }
  }
  paste0(
    '<span class="code-func">add_weight</span>(\n  ',
    paste(parts, collapse = ",\n  "),
    "\n)"
  )
}

# Generate R code snippet for using a recipe (tidy API only)
recipe_code_snippet <- function(recipe) {
  rid <- recipe$id %||% "recipe_id"
  stype <- recipe$survey_type %||% "ech"
  eds <- as.character(unlist(recipe$edition %||% "2023"))
  edition_str <- eds[length(eds)]
  dep_recipes <- as.character(unlist(recipe$depends_on_recipes))

  lines <- c("library(metasurvey)", "")

  # Fetch recipe(s)
  lines <- c(
    lines,
    '<span class="code-comment"># Get recipe from registry</span>',
    paste0(
      "recipe &lt;- ",
      '<span class="code-func">',
      "api_get_recipe</span>(",
      '<span class="code-string">"',
      rid, '"</span>)'
    )
  )

  if (length(dep_recipes) > 0) {
    for (i in seq_along(dep_recipes)) {
      lines <- c(lines, paste0(
        "dep_", i,
        " &lt;- ",
        '<span class="code-func">',
        "api_get_recipe</span>(",
        '<span class="code-string">"',
        dep_recipes[i],
        '"</span>)'
      ))
    }
  }
  lines <- c(lines, "")

  # Build weight code — recipes don't have weight_spec, use heuristic
  edition_num <- suppressWarnings(as.integer(edition_str))
  if (tolower(stype) == "ech") {
    weight_name <- if (!is.na(edition_num) && edition_num >= 2022) "W_ANO" else "pesoano"
    weight_code <- paste0(
      '<span class="code-func">',
      "add_weight</span>(annual = ",
      '<span class="code-string">"',
      weight_name, '"</span>)'
    )
  } else {
    weight_code <- paste0(
      '<span class="code-func">',
      "add_weight</span>(annual = ",
      '<span class="code-string">',
      '"weight"</span>)'
    )
  }

  # Load survey with load_survey
  if (tolower(stype) == "ech") {
    lines <- c(
      lines,
      paste0(
        '<span class="code-comment">',
        "# Load ECH microdata from ANDA",
        " and apply recipe</span>"
      ),
      'svy &lt;- <span class="code-func">load_survey</span>(',
      paste0(
        '  <span class="code-func">',
        "anda_download_microdata</span>(",
        '<span class="code-string">"',
        edition_str, '"</span>),'
      ),
      paste0(
        "  svy_type    = ",
        '<span class="code-string">"',
        stype, '"</span>,'
      ),
      paste0(
        "  svy_edition = ",
        '<span class="code-string">"',
        edition_str, '"</span>,'
      ),
      paste0("  svy_weight  = ", weight_code, ",")
    )
  } else {
    lines <- c(
      lines,
      paste0(
        '<span class="code-comment">',
        "# Load survey with recipe</span>"
      ),
      paste0(
        "svy &lt;- ",
        '<span class="code-func">',
        "load_survey</span>("
      ),
      paste0(
        '  <span class="code-string">',
        '"path/to/', stype, "_",
        edition_str, '.csv"</span>,'
      ),
      paste0(
        "  svy_type    = ",
        '<span class="code-string">"',
        stype, '"</span>,'
      ),
      paste0(
        "  svy_edition = ",
        '<span class="code-string">"',
        edition_str, '"</span>,'
      ),
      paste0(
        "  svy_weight  = ",
        weight_code, ","
      )
    )
  }

  # Add recipes parameter
  if (length(dep_recipes) > 0) {
    dep_list <- paste0("dep_", seq_along(dep_recipes), collapse = ", ")
    lines <- c(
      lines,
      paste0("  recipes     = list(", dep_list, ", recipe),"),
      '  bake        = <span class="code-keyword">TRUE</span>',
      ")"
    )
  } else {
    lines <- c(
      lines,
      "  recipes     = recipe,",
      '  bake        = <span class="code-keyword">TRUE</span>',
      ")"
    )
  }

  paste(lines, collapse = "\n")
}

# Generate R code snippet for using a workflow (tidy API only)
workflow_code_snippet <- function(wf) {
  recipe_ids <- unlist(wf$recipe_ids)
  calls <- unlist(wf$calls)
  stype <- wf$survey_type %||% "ech"
  eds <- as.character(unlist(wf$edition %||% "2023"))
  edition <- eds[length(eds)]

  lines <- c("library(metasurvey)", "")

  # Fetch recipes
  if (length(recipe_ids) > 0) {
    lines <- c(lines, paste0(
      '<span class="code-comment">',
      "# Get recipes from registry",
      "</span>"
    ))
    for (i in seq_along(recipe_ids)) {
      rvar <- paste0("r", i)
      lines <- c(lines, paste0(
        rvar,
        " &lt;- ",
        '<span class="code-func">',
        "api_get_recipe</span>(",
        '<span class="code-string">"',
        recipe_ids[i], '"</span>)'
      ))
    }
    lines <- c(lines, "")
  }

  # Build weight code from weight_spec if available,
  # else fallback to heuristic
  weight_code <- .weight_spec_to_code(
    wf$weight_spec
  )
  if (is.null(weight_code)) {
    if (tolower(stype) == "ech") {
      weight_name <- if (
        as.integer(edition) >= 2022
      ) {
        "W_ANO"
      } else {
        "pesoano"
      }
      weight_code <- paste0(
        '<span class="code-func">',
        "add_weight</span>(annual = ",
        '<span class="code-string">"',
        weight_name, '"</span>)'
      )
    } else {
      weight_code <- paste0(
        '<span class="code-func">',
        "add_weight</span>(annual = ",
        '<span class="code-string">',
        '"weight"</span>)'
      )
    }
  }

  # Load survey with load_survey
  if (tolower(stype) == "ech") {
    lines <- c(
      lines,
      paste0(
        '<span class="code-comment">',
        "# Load ECH microdata from ANDA",
        " and apply recipes</span>"
      ),
      paste0(
        "svy &lt;- ",
        '<span class="code-func">',
        "load_survey</span>("
      ),
      paste0(
        '  <span class="code-func">',
        "anda_download_microdata</span>(",
        '<span class="code-string">"',
        edition, '"</span>),'
      ),
      paste0(
        "  svy_type    = ",
        '<span class="code-string">"',
        stype, '"</span>,'
      ),
      paste0(
        "  svy_edition = ",
        '<span class="code-string">"',
        edition, '"</span>,'
      ),
      paste0(
        "  svy_weight  = ",
        weight_code, ","
      )
    )
  } else {
    lines <- c(
      lines,
      paste0(
        '<span class="code-comment">',
        "# Load survey with recipes</span>"
      ),
      paste0(
        "svy &lt;- ",
        '<span class="code-func">',
        "load_survey</span>("
      ),
      paste0(
        '  <span class="code-string">',
        '"path/to/', stype, "_",
        edition, '.csv"</span>,'
      ),
      paste0(
        "  svy_type    = ",
        '<span class="code-string">"',
        stype, '"</span>,'
      ),
      paste0(
        "  svy_edition = ",
        '<span class="code-string">"',
        edition, '"</span>,'
      ),
      paste0(
        "  svy_weight  = ",
        weight_code, ","
      )
    )
  }

  if (length(recipe_ids) > 0) {
    recipe_list <- paste0("r", seq_along(recipe_ids), collapse = ", ")
    lines <- c(
      lines,
      paste0("  recipes     = list(", recipe_list, "),"),
      '  bake        = <span class="code-keyword">TRUE</span>',
      ")"
    )
  } else {
    lines <- c(lines, ")")
  }

  if (length(calls) > 0) {
    lines <- c(
      lines, "",
      '<span class="code-comment"># Run estimations</span>',
      'results &lt;- <span class="code-func">workflow</span>('
    )
    lines <- c(lines, "  list(svy),")
    for (i in seq_along(calls)) {
      comma <- if (i < length(calls)) "," else ""
      lines <- c(lines, paste0("  ", calls[i], comma))
    }
    est_types <- unlist(wf$estimation_type)
    if (length(est_types) > 0) {
      lines <- c(lines, paste0(
        '  estimation_type = <span class="code-string">"',
        est_types[1], '"</span>'
      ))
    }
    lines <- c(lines, ")")
  }

  paste(lines, collapse = "\n")
}

recipe_card_ui <- function(recipe, ns, index) {
  doc <- recipe$doc()
  cert_level <- recipe$certification$level %||% "community"
  cert_cls <- paste0("cert-", cert_level)

  cat_tags <- if (length(recipe$categories) > 0) {
    htmltools::tagList(lapply(
      recipe$categories,
      function(c) category_tag(c$name)
    ))
  } else if (!is.null(recipe$topic)) {
    category_tag(recipe$topic)
  }

  htmltools::tags$div(
    class = "recipe-card",
    onclick = sprintf(
      "Shiny.setInputValue('%s', %d, {priority: 'event'})",
      ns("card_click"), index
    ),
    htmltools::tags$div(
      class = paste("recipe-card-header", cert_cls),
      htmltools::tags$h5(recipe$name),
      htmltools::tags$div(
        class = "card-subtitle",
        bsicons::bs_icon("person-fill", size = ".75rem"),
        recipe$user,
        htmltools::tags$span(
          style = "margin-left: .75rem;",
          bsicons::bs_icon("journal-code", size = ".75rem"),
          paste(recipe$survey_type, "/", format_edition(recipe$edition))
        )
      )
    ),
    htmltools::tags$div(
      class = "recipe-card-body",
      htmltools::tags$div(
        class = "description",
        recipe$description %||% "No description provided."
      ),
      htmltools::tags$div(style = "margin-bottom: .5rem;", cat_tags),
      cert_badge(cert_level),
      # Edition badges
      if (length(unlist(recipe$edition)) > 1) {
        eds <- as.character(unlist(recipe$edition))
        htmltools::tags$div(
          class = "edition-badges",
          lapply(eds, function(ed) {
            htmltools::tags$span(class = "edition-badge", ed)
          })
        )
      }
    ),
    htmltools::tags$div(
      class = "recipe-card-footer",
      htmltools::tags$div(
        class = "downloads",
        bsicons::bs_icon("download", size = ".85rem"),
        format_downloads(recipe$downloads)
      ),
      htmltools::tags$span(
        style = "color: #95a5a6; font-size: .75rem;",
        paste0("v", recipe$version %||% "1.0.0")
      ),
      htmltools::tags$button(
        class = "btn btn-sm btn-outline-primary btn-view",
        bsicons::bs_icon("arrow-right", size = ".75rem"),
        " View"
      )
    )
  )
}

recipe_detail_ui <- function(
    recipe,
    ns = NULL,
    referencing_workflows = list(),
    graph_output_id = "recipe_graph",
    all_recipes = list(),
    anda_labels = list()) {
  doc <- recipe$doc()
  cert_level <- recipe$certification$level %||% "community"
  cert_cls <- paste0("cert-", cert_level)

  # Header
  header <- htmltools::tags$div(
    class = paste("recipe-detail-header", cert_cls),
    htmltools::tags$h3(recipe$name),
    htmltools::tags$div(
      class = "meta-row",
      htmltools::tags$span(
        class = "meta-item",
        bsicons::bs_icon("person-fill"), recipe$user
      ),
      htmltools::tags$span(
        class = "meta-item",
        bsicons::bs_icon("journal-code"),
        paste(recipe$survey_type, "/", format_edition(recipe$edition))
      ),
      htmltools::tags$span(
        class = "meta-item",
        bsicons::bs_icon("tag-fill"), paste0("v", recipe$version %||% "1.0.0")
      ),
      htmltools::tags$span(
        class = "meta-item",
        bsicons::bs_icon("download"),
        format_downloads(recipe$downloads)
      ),
      if (!is.null(recipe$doi)) {
        htmltools::tags$span(
          class = "meta-item",
          bsicons::bs_icon("link-45deg"), recipe$doi
        )
      }
    ),
    htmltools::tags$div(
      style = "margin-top: .75rem;",
      cert_badge(cert_level),
      if (!is.null(recipe$certification$certified_by)) {
        htmltools::tags$span(
          style = paste0(
            "color: rgba(255,255,255,.85);",
            " font-size: .8rem;",
            " margin-left: .5rem;"
          ),
          paste("by", recipe$certification$certified_by$name)
        )
      }
    ),
    if (length(unlist(recipe$edition)) > 1) {
      eds <- as.character(unlist(recipe$edition))
      htmltools::tags$div(
        style = "margin-top: .6rem;",
        htmltools::tags$span(
          style = paste0(
            "color: rgba(255,255,255,.6);",
            " font-size: .75rem;",
            " margin-right: .4rem;"
          ),
          "Compatible:"
        ),
        htmltools::tags$div(
          class = "edition-badges", style = "display: inline-flex;",
          lapply(eds, function(ed) {
            htmltools::tags$span(
              class = "edition-badge",
              style = paste0(
                "background:",
                " rgba(255,255,255,.1);",
                " color:",
                " rgba(255,255,255,.85);",
                " border-color:",
                " rgba(255,255,255,.15);"
              ),
              ed
            )
          })
        )
      )
    }
  )

  # Description
  desc_section <- if (
    !is.null(recipe$description) &&
      nzchar(recipe$description)) {
    htmltools::tags$div(
      style = "padding: 1.25rem 0;",
      htmltools::tags$p(
        style = "color: #555; font-size: .95rem; line-height: 1.7;",
        recipe$description
      )
    )
  }

  # Data Source — show ANDA for ECH, S3 for others
  stype <- recipe$survey_type %||% ""
  ds <- recipe$data_source
  data_source_section <- if (tolower(stype) == "ech") {
    eds <- as.character(unlist(recipe$edition))
    htmltools::tags$div(
      style = "padding: 1rem 0;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("cloud-arrow-down-fill"), "Data Source"
      ),
      htmltools::tags$div(
        style = paste0(
          "display: flex;",
          " flex-wrap: wrap;",
          " gap: .75rem;",
          " align-items: center;"
        ),
        htmltools::tags$span(
          class = "var-chip var-chip-input",
          style = "font-size: .78rem;",
          bsicons::bs_icon(
            "database",
            size = ".75rem"
          ),
          " INE Uruguay (ANDA5)"
        ),
        htmltools::tags$span(
          class = "var-chip",
          style = paste0(
            "font-size: .72rem;",
            " background:",
            " var(--emerald-50);",
            " color: #065f46;",
            " border: 1px solid #a7f3d0;"
          ),
          paste0("anda_download_microdata(\"", eds[length(eds)], "\")")
        )
      ),
      htmltools::tags$div(
        style = paste0(
          "margin-top: .5rem;",
          " font-size: .78rem;",
          " color: var(--slate-500);"
        ),
        paste0("Ediciones disponibles: ", paste(eds, collapse = ", "))
      )
    )
  } else if (!is.null(ds) && !is.null(ds$s3_bucket)) {
    eds <- as.character(unlist(recipe$edition))
    latest_ed <- eds[length(eds)]
    s3_path <- gsub("\\{edition\\}", latest_ed, ds$file_pattern %||% "")
    s3_full <- paste0("s3://", ds$s3_bucket, "/", ds$s3_prefix, s3_path)

    htmltools::tags$div(
      style = "padding: 1rem 0;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("cloud-arrow-down-fill"), "Data Source"
      ),
      htmltools::tags$div(
        style = paste0(
          "display: flex;",
          " flex-wrap: wrap;",
          " gap: .75rem;",
          " align-items: center;"
        ),
        htmltools::tags$span(
          class = "var-chip var-chip-input",
          style = "font-size: .78rem;",
          bsicons::bs_icon(
            "database",
            size = ".75rem"
          ),
          paste0(" ", ds$provider %||% "")
        ),
        htmltools::tags$span(
          class = "var-chip",
          style = paste0(
            "font-size: .72rem;",
            " background:",
            " var(--slate-100);",
            " color: var(--slate-600);",
            " border: 1px solid",
            " var(--slate-200);"
          ),
          s3_full
        )
      )
    )
  }

  # Categories
  cat_section <- if (length(recipe$categories) > 0) {
    htmltools::tags$div(
      style = "padding-bottom: 1rem;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("tags-fill"), "Categories"
      ),
      htmltools::tagList(lapply(recipe$categories, function(c) {
        category_tag(c$name)
      }))
    )
  }

  # Depends on Recipes (recipe-to-recipe dependencies)
  dep_recipes_ids <- as.character(unlist(recipe$depends_on_recipes))
  dep_recipes_section <- if (length(dep_recipes_ids) > 0) {
    dep_chips <- lapply(dep_recipes_ids, function(rid) {
      rname <- rid
      for (r in all_recipes) {
        if (as.character(r$id) == rid) {
          rname <- r$name
          break
        }
      }
      if (!is.null(ns)) {
        htmltools::tags$span(
          class = "cross-ref-chip cross-ref-recipe",
          onclick = sprintf(
            "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
            ns("navigate_dep_recipe"), rid
          ),
          bsicons::bs_icon("journal-code", size = ".75rem"),
          " ", rname
        )
      } else {
        htmltools::tags$span(
          class = "cross-ref-chip cross-ref-recipe",
          bsicons::bs_icon("journal-code", size = ".75rem"),
          " ", rname
        )
      }
    })

    htmltools::tags$div(
      style = "padding: 1rem 0;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("arrow-left-right"), "Requires Recipes"
      ),
      htmltools::tagList(dep_chips)
    )
  }

  # Pipeline graph (visNetwork)
  has_visnetwork <- requireNamespace("visNetwork", quietly = TRUE)
  n_steps <- length(doc$pipeline)
  graph_section <- if (
    n_steps > 0 &&
      has_visnetwork &&
      !is.null(ns)) {
    disclaimer <- if (n_steps > 20) {
      htmltools::tags$div(
        class = "graph-disclaimer",
        bsicons::bs_icon("exclamation-triangle-fill", size = ".85rem"),
        sprintf(
          paste0(
            "This recipe has %d steps. ",
            "The graph may be hard to read at this scale. ",
            "Use the timeline below for details."
          ),
          n_steps
        )
      )
    }

    graph_height <- if (n_steps > 100) "500px" else "350px"

    htmltools::tags$div(
      style = "padding: 1rem 0;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("diagram-3-fill"),
        paste("Pipeline Graph (", n_steps, "steps )")
      ),
      disclaimer,
      htmltools::tags$div(
        class = "graph-loading-wrapper",
        id = paste0("graph-wrap-", graph_output_id),
        htmltools::tags$div(
          class = "graph-spinner",
          htmltools::tags$div(class = "spinner-ring"),
          "Loading graph..."
        ),
        visNetwork::visNetworkOutput(ns(graph_output_id), height = graph_height)
      ),
      htmltools::tags$script(htmltools::HTML(sprintf(
        "$(document).on('shiny:value', function(e) {
          if (e.name && e.name.indexOf('%s') !== -1) {
            var w = document.getElementById('graph-wrap-%s');
            if (w) w.classList.add('loaded');
          }
        });",
        graph_output_id, graph_output_id
      )))
    )
  }

  # Pipeline timeline
  pipeline_section <- if (length(doc$pipeline) > 0) {
    steps_html <- lapply(doc$pipeline, function(step) {
      step_type <- if (is.list(step$type)) {
        step$type[[1]]
      } else {
        step$type %||% "unknown"
      }
      base_type <- gsub("ast_", "", step_type)
      valid_types <- c(
        "compute", "recode", "rename",
        "remove", "join"
      )
      dot_suffix <- if (
        base_type %in% valid_types
      ) {
        base_type
      } else {
        "default"
      }
      dot_cls <- paste0(
        "step-dot step-dot-", dot_suffix
      )
      type_cls <- paste0("step-type step-type-", base_type)

      outputs <- unlist(step$outputs)
      outputs_str <- if (length(outputs) > 0) {
        paste(outputs, collapse = ", ")
      } else {
        "(no output)"
      }
      comment_txt <- if (
        is.list(step$comment)
      ) {
        step$comment[[1]]
      } else {
        step$comment
      }
      comment_html <- if (
        !is.null(comment_txt) &&
          length(comment_txt) == 1 &&
          nzchar(comment_txt)) {
        htmltools::tags$div(
          style = paste0(
            "font-size:.75rem;",
            " color:#95a5a6;",
            " font-style:italic;"
          ),
          comment_txt
        )
      }

      # Expression / formula display
      expr_txt <- if (
        is.list(step$expression)
      ) {
        step$expression[[1]]
      } else {
        step$expression
      }
      expr_html <- if (
        !is.null(expr_txt) &&
          length(expr_txt) == 1 &&
          nzchar(expr_txt)) {
        htmltools::tags$div(
          style = paste0(
            "font-family:'JetBrains Mono',",
            "'Fira Code','Consolas',",
            "monospace;font-size:.72rem;",
            "color:var(--slate-700);",
            "background:var(--slate-50);",
            "border:1px solid",
            " var(--slate-200);",
            "border-radius:4px;",
            "padding:.3rem .5rem;",
            "margin-top:.3rem;",
            "white-space:pre-wrap;",
            "word-break:break-all;"
          ),
          expr_txt
        )
      }

      # Conditions display for recode steps
      conditions <- step$conditions
      conditions_html <- if (!is.null(conditions) && length(conditions) > 0) {
        cond_items <- lapply(conditions, function(cond) {
          val <- cond$value %||% cond[[1]] %||% ""
          label <- cond$label %||% cond[[2]] %||% ""
          cond_expr <- cond$condition %||% cond[[3]] %||% ""
          htmltools::tags$div(
            style = "font-size:.7rem;color:var(--slate-600);padding:.1rem 0;",
            htmltools::tags$span(
              style = paste0(
                "font-weight:600;",
                "color:var(--violet);"
              ),
              val
            ),
            if (nzchar(label)) {
              htmltools::tags$span(
                style = "margin:0 .3rem;",
                paste0("(", label, ")")
              )
            },
            if (nzchar(cond_expr)) {
              htmltools::tags$span(
                style = paste0(
                  "font-family:monospace;",
                  "color:var(--slate-500);",
                  "font-size:.65rem;"
                ),
                paste0(" <- ", cond_expr)
              )
            }
          )
        })
        htmltools::tags$div(
          style = paste0(
            "margin-top:.3rem;",
            "padding:.3rem .5rem;",
            "background:var(--slate-50);",
            "border:1px solid",
            " var(--slate-200);",
            "border-radius:4px;",
            "max-height:120px;",
            "overflow-y:auto;"
          ),
          htmltools::tagList(cond_items)
        )
      }

      htmltools::tags$div(
        class = "pipeline-step",
        htmltools::tags$div(class = dot_cls, step$index),
        htmltools::tags$div(
          class = "step-content",
          htmltools::tags$span(class = type_cls, step_type),
          htmltools::tags$span(
            style = "margin: 0 .35rem; color: #bbb;",
            bsicons::bs_icon("arrow-right", size = ".7rem")
          ),
          htmltools::tags$span(class = "step-outputs", outputs_str),
          comment_html,
          expr_html,
          conditions_html
        )
      )
    })

    htmltools::tags$div(
      class = "pipeline-section",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("list-ol"),
        "Step Details"
      ),
      htmltools::tagList(steps_html)
    )
  }

  # Build ANDA metadata lookup: variable_name -> full metadata list
  var_meta_map <- list()
  if (length(anda_labels) > 0) {
    for (al in anda_labels) {
      nm <- al$name %||% ""
      if (nzchar(nm)) var_meta_map[[tolower(nm)]] <- al
    }
  }

  # Helper: render a variable chip with ANDA
  # metadata (label, type, description, value_labels)
  var_chip <- function(v, cls, suffix = NULL) {
    meta <- var_meta_map[[tolower(v)]]
    label <- meta$label %||% ""
    vtype <- meta$type %||% ""
    desc <- meta$description %||% ""
    vlabels <- meta$value_labels

    # Build tooltip text with full metadata
    tooltip_parts <- c()
    if (nzchar(label)) tooltip_parts <- c(tooltip_parts, label)
    if (nzchar(vtype)) {
      tooltip_parts <- c(
        tooltip_parts,
        paste0("Type: ", vtype)
      )
    }
    if (nzchar(desc)) tooltip_parts <- c(tooltip_parts, desc)
    if (!is.null(vlabels) && length(vlabels) > 0) {
      n_vals <- min(length(vlabels), 8)
      val_strs <- vapply(seq_len(n_vals), function(i) {
        paste0(names(vlabels)[i], " = ", vlabels[[i]])
      }, character(1))
      if (length(vlabels) > 8) {
        val_strs <- c(
          val_strs,
          paste0(
            "... (", length(vlabels),
            " total)"
          )
        )
      }
      tooltip_parts <- c(tooltip_parts, paste(val_strs, collapse = " | "))
    }
    tooltip <- paste(tooltip_parts, collapse = "\n")

    # Type badge
    type_badge <- if (nzchar(vtype)) {
      type_color <- if (vtype == "discrete") "var(--violet)" else "var(--sky)"
      htmltools::tags$span(
        style = paste0(
          "font-size:.55rem;",
          "padding:.05rem .3rem;",
          "border-radius:3px;",
          "margin-left:.3rem;",
          "background:", type_color,
          ";color:#fff;",
          "font-weight:600;",
          "font-family:system-ui,",
          "sans-serif;"
        ),
        vtype
      )
    }

    # Value labels count badge
    vlabel_badge <- if (!is.null(vlabels) && length(vlabels) > 0) {
      htmltools::tags$span(
        style = paste0(
          "font-size:.55rem;",
          "opacity:.5;",
          "margin-left:.2rem;",
          "font-family:system-ui,",
          "sans-serif;"
        ),
        paste0("(", length(vlabels), " cat.)")
      )
    }

    htmltools::tags$span(
      class = cls,
      title = tooltip,
      style = if (nzchar(label)) "cursor:help;" else NULL,
      v,
      if (!is.null(suffix)) suffix,
      if (nzchar(label)) {
        htmltools::tags$span(
          style = paste0(
            "font-size:.6rem;",
            "opacity:.55;",
            "margin-left:.35rem;",
            "font-family:system-ui,",
            "sans-serif;",
            "font-weight:400;"
          ),
          label
        )
      },
      type_badge,
      vlabel_badge
    )
  }

  # Input variables
  input_vars <- unlist(doc$input_variables)
  input_section <- if (length(input_vars) > 0) {
    htmltools::tags$div(
      style = "padding: 1rem 0;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("box-arrow-in-right"),
        paste("Requires (", length(input_vars), "variables )")
      ),
      htmltools::tagList(lapply(input_vars, function(v) {
        var_chip(v, "var-chip var-chip-input")
      }))
    )
  }

  # Output variables
  output_vars <- unlist(doc$output_variables)
  output_section <- if (length(output_vars) > 0) {
    # Build type map from pipeline
    type_map <- list()
    for (step in doc$pipeline) {
      outputs <- unlist(step$outputs)
      inf_type <- if (
        is.list(step$inferred_type)
      ) {
        step$inferred_type[[1]]
      } else {
        step$inferred_type
      }
      if (length(outputs) > 0 && !is.null(inf_type)) {
        for (o in outputs) type_map[[o]] <- inf_type
      }
    }

    htmltools::tags$div(
      style = "padding: 1rem 0;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("box-arrow-right"),
        paste("Produces (", length(output_vars), "variables )")
      ),
      htmltools::tagList(lapply(output_vars, function(v) {
        var_type <- type_map[[v]] %||% "unknown"
        cls <- if (var_type == "categorical") {
          "var-chip var-chip-output-cat"
        } else {
          "var-chip var-chip-output"
        }
        type_badge <- htmltools::tags$span(
          style = "font-size:.65rem; opacity:.7; margin-left:.3rem;",
          paste0("[", var_type, "]")
        )
        var_chip(v, cls, suffix = type_badge)
      }))
    )
  }

  # Used in Workflows (cross-reference section)
  workflow_section <- if (length(referencing_workflows) > 0) {
    wf_chips <- lapply(referencing_workflows, function(wf) {
      wf_name <- wf$name %||% wf$id
      n_est <- length(wf$call_metadata)
      if (!is.null(ns)) {
        htmltools::tags$span(
          class = "cross-ref-chip cross-ref-workflow",
          onclick = sprintf(
            "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
            ns("navigate_workflow"), wf$id
          ),
          bsicons::bs_icon("bar-chart-fill", size = ".75rem"),
          " ", wf_name,
          htmltools::tags$span(
            style = "font-size:.65rem; opacity:.7; margin-left:.3rem;",
            paste0("(", n_est, " est.)")
          )
        )
      } else {
        htmltools::tags$span(
          class = "cross-ref-chip cross-ref-workflow",
          bsicons::bs_icon("bar-chart-fill", size = ".75rem"),
          " ", wf_name
        )
      }
    })

    htmltools::tags$div(
      style = "padding: 1rem 0;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("bar-chart-fill"),
        paste("Used in Workflows (", length(referencing_workflows), ")")
      ),
      htmltools::tagList(wf_chips)
    )
  }

  # R Code snippet
  code_section <- htmltools::tags$div(
    style = "padding: 1rem 0;",
    htmltools::tags$div(
      class = "section-title",
      bsicons::bs_icon("terminal-fill"),
      "Use in R"
    ),
    code_block_ui(
      recipe_code_snippet(recipe),
      label = "R Code",
      block_id = paste0("recipe_code_", recipe$id %||% "x")
    )
  )

  # Assemble
  htmltools::tags$div(
    header,
    htmltools::tags$div(
      style = "padding: 0 2rem 1.5rem;",
      desc_section,
      data_source_section,
      cat_section,
      dep_recipes_section,
      graph_section,
      pipeline_section,
      workflow_section,
      input_section,
      output_section,
      code_section
    )
  )
}

# ── Build a visNetwork graph from recipe pipeline data ──
recipe_pipeline_graph <- function(recipe) {
  if (!requireNamespace("visNetwork", quietly = TRUE)) {
    return(NULL)
  }

  doc <- recipe$doc()
  pipeline <- doc$pipeline
  if (length(pipeline) == 0) {
    return(NULL)
  }

  input_vars <- unlist(doc$input_variables)
  output_vars <- unlist(doc$output_variables)
  workflows <- list() # Workflows now live as separate RecipeWorkflow objects

  # Normalize pipeline steps: MongoDB returns lists, we need character vectors
  pipeline <- lapply(pipeline, function(s) {
    s$outputs <- as.character(unlist(s$outputs))
    s$inputs <- as.character(unlist(s$inputs))
    s$type <- if (is.list(s$type)) s$type[[1]] else s$type
    s$comment <- if (is.list(s$comment)) s$comment[[1]] else s$comment
    s$inferred_type <- if (
      is.list(s$inferred_type)
    ) {
      s$inferred_type[[1]]
    } else {
      s$inferred_type
    }
    s$index <- if (is.list(s$index)) {
      as.integer(s$index[[1]])
    } else {
      as.integer(s$index)
    }
    s
  })

  # ── Palette (aligned with new minimalist design) ──
  pal <- list(
    primary    = "#1e293b",
    compute    = "#6366f1",
    recode     = "#8b5cf6",
    join       = "#10b981",
    remove     = "#f43f5e",
    rename     = "#f59e0b",
    default    = "#94a3b8",
    bg         = "#f8fafc",
    edge       = "#cbd5e1",
    edge_dep   = "#f59e0b",
    input_var  = "#1e40af",
    output_var = "#166534",
    wf_mean    = "#f59e0b",
    wf_total   = "#f43f5e",
    wf_ratio   = "#8b5cf6",
    wf_by      = "#0ea5e9"
  )

  step_color <- function(type) {
    base <- gsub("^(ast_|step_)", "", type)
    switch(base,
      "compute" = pal$compute,
      "recode" = pal$recode,
      "join" = pal$join,
      "remove" = pal$remove,
      "rename" = pal$rename,
      pal$default
    )
  }

  wf_color <- function(type) {
    base <- gsub("^survey::", "", type)
    switch(base,
      "svymean" = pal$wf_mean,
      "svytotal" = pal$wf_total,
      "svyratio" = pal$wf_ratio,
      "svyby" = pal$wf_by,
      pal$wf_mean
    )
  }

  wf_icon <- function(type) {
    base <- gsub("^survey::", "", type)
    switch(base,
      "svymean"  = "f201",
      "svytotal" = "f1fe",
      "svyratio" = "f080",
      "svyby"    = "f1de",
      "f080"
    )
  }

  # ── Build output-to-step map first (for inter-step edges) ──
  produced_by <- list()
  for (s in pipeline) {
    if (length(s$outputs) > 0) {
      for (o in s$outputs) produced_by[[o]] <- s$index
    }
  }

  # ── Build nodes & edges ──
  node_id <- 0L
  nodes <- list()
  edges <- list()
  add_node <- function(df) {
    nodes[[length(nodes) + 1L]] <<- df
  }
  add_edge <- function(from, to, edgetype = "default") {
    edges[[length(edges) + 1L]] <<- data.frame(
      from = from, to = to,
      edgetype = edgetype,
      stringsAsFactors = FALSE
    )
  }

  # Survey root
  node_id <- node_id + 1L
  survey_id <- node_id
  add_node(data.frame(
    id = survey_id,
    label = paste0(
      toupper(recipe$survey_type), " ",
      format_edition(recipe$edition)
    ),
    title = paste0(
      "<div style='font-family:system-ui,sans-serif;padding:10px 14px;'>",
      "<div style='font-weight:800;color:", pal$primary, ";font-size:13px;'>",
      htmltools::htmlEscape(recipe$name), "</div>",
      "<div style='font-size:11px;color:#6c757d;margin-top:4px;'>",
      htmltools::htmlEscape(recipe$survey_type), " / ",
      htmltools::htmlEscape(format_edition(recipe$edition)), "</div></div>"
    ),
    group = "survey", level = 0L,
    stringsAsFactors = FALSE
  ))

  # Input variable nodes
  input_ids <- list()
  for (v in input_vars) {
    node_id <- node_id + 1L
    input_ids[[v]] <- node_id
    add_node(data.frame(
      id = node_id, label = v,
      title = paste0(
        "<div style='font-family:SFMono-Regular,monospace;padding:8px 12px;",
        "font-size:12px;color:", pal$input_var, ";'>Input: <b>",
        htmltools::htmlEscape(v), "</b></div>"
      ),
      group = "input_var", level = 1L,
      stringsAsFactors = FALSE
    ))
    add_edge(survey_id, node_id)
  }

  # Step nodes — with proper inter-step dependency edges
  step_ids <- list()
  for (s in pipeline) {
    node_id <- node_id + 1L
    stype <- s$type %||% "unknown"
    sidx <- as.character(s$index)
    step_ids[[sidx]] <- node_id

    outputs_str <- if (length(s$outputs) > 0) {
      paste(s$outputs, collapse = ", ")
    } else {
      ""
    }
    comment_str <- if (
      !is.null(s$comment) &&
        nzchar(s$comment)
    ) {
      s$comment
    } else {
      ""
    }
    expr_str <- if (is.list(s$expression)) {
      s$expression[[1]]
    } else {
      s$expression %||% ""
    }
    if (is.null(expr_str)) expr_str <- ""

    add_node(data.frame(
      id = node_id,
      label = paste0(s$index, ". ", outputs_str),
      title = paste0(
        paste0(
          "<div style='font-family:",
          "system-ui,sans-serif;",
          "padding:10px 14px;",
          "max-width:350px;'>"
        ),
        paste0(
          "<div style='font-weight:700;",
          "font-size:13px;color:",
          step_color(stype), ";"
        ),
        "text-transform:uppercase;letter-spacing:.04em;margin-bottom:4px;'>",
        htmltools::htmlEscape(stype), "</div>",
        if (nzchar(outputs_str)) {
          paste0(
            paste0(
              "<div style='font-size:12px;",
              "font-weight:600;color:",
              pal$primary, ";'>"
            ),
            htmltools::htmlEscape(outputs_str), "</div>"
          )
        } else {
          ""
        },
        if (nzchar(expr_str)) {
          paste0(
            paste0(
              "<div style='font-family:",
              "SFMono-Regular,monospace;",
              "font-size:10px;color:",
              pal$primary, ";"
            ),
            paste0(
              "background:", pal$bg,
              ";padding:6px 8px;",
              "border-radius:4px;",
              "margin:4px 0;",
              "white-space:pre-wrap;'>"
            ),
            htmltools::htmlEscape(expr_str), "</div>"
          )
        } else {
          ""
        },
        if (nzchar(comment_str)) {
          paste0(
            paste0(
              "<div style='font-size:11px;",
              "color:#95a5a6;",
              "font-style:italic;",
              "margin-top:4px;'>"
            ),
            htmltools::htmlEscape(comment_str),
            "</div>"
          )
        } else {
          ""
        },
        "</div>"
      ),
      group = stype,
      level = as.integer(s$index) + 1L,
      stringsAsFactors = FALSE
    ))

    # Edges: from input vars OR from producing step
    step_inputs <- s$inputs
    has_any_edge <- FALSE
    if (length(step_inputs) > 0) {
      for (inp in step_inputs) {
        if (inp %in% names(input_ids)) {
          add_edge(input_ids[[inp]], node_id)
          has_any_edge <- TRUE
        } else if (inp %in% names(produced_by)) {
          src_step <- step_ids[[as.character(produced_by[[inp]])]]
          if (!is.null(src_step)) {
            add_edge(src_step, node_id, "dependency")
            has_any_edge <- TRUE
          }
        }
      }
    }
    # Fallback: chain to previous step if no edges created
    if (!has_any_edge && s$index > 1) {
      prev_id <- step_ids[[as.character(s$index - 1)]]
      if (!is.null(prev_id)) add_edge(prev_id, node_id)
    }
  }

  # Output variable nodes
  type_map <- list()
  for (s in pipeline) {
    if (length(s$outputs) > 0 && !is.null(s$inferred_type)) {
      for (o in s$outputs) type_map[[o]] <- s$inferred_type
    }
  }

  output_node_ids <- list()
  max_step_level <- if (
    length(pipeline) > 0
  ) {
    max(vapply(
      pipeline,
      function(s) s$index,
      integer(1)
    )) + 1L
  } else {
    1L
  }
  for (v in output_vars) {
    node_id <- node_id + 1L
    output_node_ids[[v]] <- node_id
    vtype <- type_map[[v]] %||% "unknown"
    from_id <- if (v %in% names(produced_by)) {
      step_ids[[as.character(produced_by[[v]])]]
    } else if (length(step_ids) > 0) {
      step_ids[[names(step_ids)[length(step_ids)]]]
    } else {
      survey_id
    }
    add_node(data.frame(
      id = node_id, label = v,
      title = paste0(
        "<div style='font-family:SFMono-Regular,monospace;padding:8px 12px;",
        "font-size:12px;color:", pal$output_var, ";'>Output: <b>",
        htmltools::htmlEscape(v),
        "</b> [",
        htmltools::htmlEscape(vtype),
        "]</div>"
      ),
      group = paste0("output_", vtype), level = max_step_level + 1L,
      stringsAsFactors = FALSE
    ))
    add_edge(from_id, node_id)
  }

  # Workflow nodes
  if (length(workflows) > 0) {
    wf_level <- max_step_level + 2L
    for (i in seq_along(workflows)) {
      wf <- workflows[[i]]
      node_id <- node_id + 1L
      wf_type <- wf$type %||% "svymean"
      base_type <- gsub("^survey::", "", wf_type)
      wf_name <- wf$name %||% paste0(base_type, "(", wf$formula %||% "", ")")
      formula_str <- wf$formula %||% ""
      by_str <- if (
        !is.null(wf$by) && nzchar(wf$by)
      ) {
        paste0(" by ", wf$by)
      } else {
        ""
      }
      desc_str <- wf$description %||% ""

      add_node(data.frame(
        id = node_id,
        label = wf_name,
        title = paste0(
          paste0(
            "<div style='font-family:",
            "system-ui,sans-serif;",
            "padding:10px 14px;",
            "max-width:320px;'>"
          ),
          paste0(
            "<div style='font-weight:700;",
            "font-size:13px;color:",
            wf_color(wf_type), ";"
          ),
          "text-transform:uppercase;letter-spacing:.04em;margin-bottom:4px;'>",
          htmltools::htmlEscape(base_type), "</div>",
          paste0(
            "<div style='font-family:",
            "SFMono-Regular,monospace;",
            "font-size:11px;color:",
            pal$primary, ";"
          ),
          paste0(
            "background:", pal$bg,
            ";padding:6px 8px;",
            "border-radius:4px;",
            "margin:4px 0;'>"
          ),
          paste0(
            htmltools::htmlEscape(paste0(
              base_type, "(",
              formula_str, by_str, ")"
            )),
            "</div>"
          ),
          if (nzchar(desc_str)) {
            paste0(
              paste0(
                "<div style='font-size:11px;",
                "color:#95a5a6;",
                "font-style:italic;",
                "margin-top:4px;'>"
              ),
              htmltools::htmlEscape(desc_str),
              "</div>"
            )
          } else {
            ""
          },
          "</div>"
        ),
        group = paste0("wf_", base_type), level = wf_level,
        stringsAsFactors = FALSE
      ))

      # Connect workflow to the output variables it uses
      wf_vars <- wf$uses %||% character(0)
      connected <- FALSE
      for (wv in wf_vars) {
        if (wv %in% names(output_node_ids)) {
          add_edge(output_node_ids[[wv]], node_id, "workflow")
          connected <- TRUE
        } else if (wv %in% names(input_ids)) {
          add_edge(input_ids[[wv]], node_id, "workflow")
          connected <- TRUE
        }
      }
      # Fallback: connect to last step
      if (!connected && length(step_ids) > 0) {
        last_step <- step_ids[[names(step_ids)[length(step_ids)]]]
        add_edge(last_step, node_id, "workflow")
      }
    }
  }

  # ── Assemble data.frames ──
  all_nodes <- do.call(rbind, nodes)
  all_edges <- if (length(edges) > 0) {
    do.call(rbind, edges)
  } else {
    data.frame(
      from = integer(),
      to = integer(),
      edgetype = character(),
      stringsAsFactors = FALSE
    )
  }

  # ── Build visNetwork ──
  graph <- visNetwork::visNetwork(
    nodes = all_nodes, edges = all_edges,
    height = "400px", width = "100%",
    background = pal$bg
  ) |>
    # Survey node
    visNetwork::visGroups(
      groupname = "survey",
      shape = "icon",
      icon = list(code = "f1c0", size = 55, color = pal$primary),
      font = list(size = 14, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 8, color = "rgba(44,62,80,.15)")
    ) |>
    # Input variables
    visNetwork::visGroups(
      groupname = "input_var",
      shape = "box",
      color = list(
        background = "#ebf5fb", border = "#aed6f1",
        highlight = list(background = "#d4e6f1", border = pal$input_var)
      ),
      font = list(size = 11, color = pal$input_var, face = "monospace"),
      borderWidth = 1,
      shadow = list(enabled = TRUE, size = 3, color = "rgba(36,113,163,.1)")
    ) |>
    # Step groups
    visNetwork::visGroups(
      groupname = "compute",
      shape = "icon",
      icon = list(code = "f1ec", size = 45, color = pal$compute),
      font = list(size = 13, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(52,152,219,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "recode",
      shape = "icon",
      icon = list(code = "f0e8", size = 45, color = pal$recode),
      font = list(size = 13, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(155,89,182,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "join", shape = "icon",
      icon = list(code = "f0c1", size = 45, color = pal$join),
      font = list(size = 13, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(26,188,156,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "step_join", shape = "icon",
      icon = list(code = "f0c1", size = 45, color = pal$join),
      font = list(size = 13, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(26,188,156,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "step_remove", shape = "icon",
      icon = list(code = "f1f8", size = 45, color = pal$remove),
      font = list(size = 13, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(231,76,60,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "remove", shape = "icon",
      icon = list(code = "f1f8", size = 45, color = pal$remove),
      font = list(size = 13, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(231,76,60,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "rename", shape = "icon",
      icon = list(code = "f044", size = 45, color = pal$rename),
      font = list(size = 13, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(230,126,34,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "step_rename", shape = "icon",
      icon = list(code = "f044", size = 45, color = pal$rename),
      font = list(size = 13, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(230,126,34,.2)")
    ) |>
    # Output variable groups
    visNetwork::visGroups(
      groupname = "output_numeric", shape = "box",
      color = list(
        background = "#eafaf1", border = "#a9dfbf",
        highlight = list(background = "#d5f5e3", border = pal$output_var)
      ),
      font = list(size = 11, color = pal$output_var, face = "monospace"),
      borderWidth = 1,
      shadow = list(enabled = TRUE, size = 3, color = "rgba(30,132,73,.1)")
    ) |>
    visNetwork::visGroups(
      groupname = "output_categorical", shape = "box",
      color = list(
        background = "#f5eef8", border = "#d2b4de",
        highlight = list(background = "#ebdef0", border = "#7d3c98")
      ),
      font = list(size = 11, color = "#7d3c98", face = "monospace"),
      borderWidth = 1,
      shadow = list(enabled = TRUE, size = 3, color = "rgba(125,60,152,.1)")
    ) |>
    visNetwork::visGroups(
      groupname = "output_unknown", shape = "box",
      color = list(
        background = "#f8f9fa", border = "#dee2e6",
        highlight = list(background = "#eee", border = "#95a5a6")
      ),
      font = list(size = 11, color = "#6c757d", face = "monospace"),
      borderWidth = 1
    ) |>
    # Workflow groups
    visNetwork::visGroups(
      groupname = "wf_svymean", shape = "icon",
      icon = list(code = "f201", size = 40, color = pal$wf_mean),
      font = list(size = 12, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(243,156,18,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "wf_svytotal", shape = "icon",
      icon = list(code = "f1fe", size = 40, color = pal$wf_total),
      font = list(size = 12, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(231,76,60,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "wf_svyratio", shape = "icon",
      icon = list(code = "f080", size = 40, color = pal$wf_ratio),
      font = list(size = 12, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(142,68,173,.2)")
    ) |>
    visNetwork::visGroups(
      groupname = "wf_svyby", shape = "icon",
      icon = list(code = "f1de", size = 40, color = pal$wf_by),
      font = list(size = 12, color = pal$primary, face = "bold"),
      shadow = list(enabled = TRUE, size = 6, color = "rgba(41,128,185,.2)")
    ) |>
    visNetwork::addFontAwesome() |>
    visNetwork::visEdges(
      arrows = list(
        to = list(
          enabled = TRUE,
          scaleFactor = 0.6,
          type = "arrow"
        )
      ),
      color = list(
        color = pal$edge,
        highlight = pal$compute,
        hover = pal$compute
      ),
      width = 1.5,
      smooth = list(enabled = TRUE, type = "curvedCW", roundness = 0.08)
    ) |>
    visNetwork::visHierarchicalLayout(
      direction = "LR",
      levelSeparation = 180,
      nodeSpacing = 100,
      sortMethod = "directed"
    ) |>
    visNetwork::visInteraction(
      hover = TRUE,
      tooltipDelay = 100,
      tooltipStyle = paste0(
        "position:fixed;visibility:hidden;padding:0;",
        "background:#fff;border-radius:10px;",
        "box-shadow:0 4px 20px rgba(0,0,0,.12);",
        "border:1px solid #eee;pointer-events:none;z-index:9999;"
      ),
      navigationButtons = TRUE
    ) |>
    visNetwork::visOptions(
      highlightNearest = list(enabled = TRUE, degree = 1, hover = TRUE)
    )

  graph
}

# ── Workflow Card UI ──

workflow_card_ui <- function(wf, ns, index) {
  cert_level <- wf$certification$level %||% "community"
  cert_cls <- paste0("cert-", cert_level)
  n_recipes <- length(wf$recipe_ids)
  n_est <- length(wf$call_metadata)

  est_badges <- if (length(wf$estimation_type) > 0) {
    htmltools::tagList(lapply(wf$estimation_type, function(et) {
      cls <- paste0("est-type-badge est-type-", et)
      htmltools::tags$span(class = cls, et)
    }))
  }

  htmltools::tags$div(
    class = "recipe-card",
    onclick = sprintf(
      "Shiny.setInputValue('%s', %d, {priority: 'event'})",
      ns("wf_card_click"), index
    ),
    htmltools::tags$div(
      class = paste("recipe-card-header", cert_cls),
      htmltools::tags$h5(wf$name),
      htmltools::tags$div(
        class = "card-subtitle",
        bsicons::bs_icon("person-fill", size = ".75rem"),
        wf$user,
        htmltools::tags$span(
          style = "margin-left: .75rem;",
          bsicons::bs_icon("bar-chart-fill", size = ".75rem"),
          paste(n_est, "estimations"),
          bsicons::bs_icon("journal-code", size = ".75rem", class = "ms-2"),
          paste(n_recipes, "recipes")
        )
      )
    ),
    htmltools::tags$div(
      class = "recipe-card-body",
      htmltools::tags$div(
        class = "description",
        wf$description %||% "No description provided."
      ),
      htmltools::tags$div(style = "margin-bottom: .5rem;", est_badges),
      cert_badge(cert_level)
    ),
    htmltools::tags$div(
      class = "recipe-card-footer",
      htmltools::tags$div(
        class = "downloads",
        bsicons::bs_icon("download", size = ".85rem"),
        format_downloads(wf$downloads)
      ),
      htmltools::tags$span(
        style = "color: #95a5a6; font-size: .75rem;",
        paste0("v", wf$version %||% "1.0.0")
      ),
      htmltools::tags$button(
        class = "btn btn-sm btn-outline-primary btn-view",
        bsicons::bs_icon("arrow-right", size = ".75rem"),
        " View"
      )
    )
  )
}

# ── Workflow Detail UI ──

workflow_detail_ui <- function(wf, recipes_list = list(), ns = NULL) {
  doc <- wf$doc()
  cert_level <- wf$certification$level %||% "community"
  cert_cls <- paste0("cert-", cert_level)

  # Header
  header <- htmltools::tags$div(
    class = paste("recipe-detail-header", cert_cls),
    htmltools::tags$h3(wf$name),
    htmltools::tags$div(
      class = "meta-row",
      htmltools::tags$div(
        class = "meta-item",
        bsicons::bs_icon("person-fill"), wf$user
      ),
      htmltools::tags$div(
        class = "meta-item",
        bsicons::bs_icon("clipboard-data"),
        paste(
          wf$survey_type, "/",
          format_edition(wf$edition)
        )
      ),
      if (length(wf$estimation_type) > 0) {
        htmltools::tags$div(
          class = "meta-item",
          bsicons::bs_icon("bar-chart-fill"),
          paste(wf$estimation_type, collapse = ", ")
        )
      },
      htmltools::tags$div(
        class = "meta-item",
        bsicons::bs_icon("tag-fill"), paste0("v", wf$version)
      ),
      htmltools::tags$div(
        class = "meta-item",
        bsicons::bs_icon("download"), format_downloads(wf$downloads)
      )
    )
  )

  # Description
  desc_section <- if (!is.null(wf$description) && nzchar(wf$description)) {
    htmltools::tags$div(
      style = "padding: 1rem 1.5rem;",
      htmltools::tags$p(
        style = paste0(
          "color: #6c757d;",
          " line-height: 1.6;"
        ),
        wf$description
      )
    )
  }

  # Uses Recipes (cross-refs)
  recipe_refs <- NULL
  if (length(wf$recipe_ids) > 0) {
    # Build clickable chips for each recipe
    ref_chips <- lapply(wf$recipe_ids, function(rid) {
      # Find recipe name from the list
      rname <- rid
      for (r in recipes_list) {
        if (as.character(r$id) == rid) {
          rname <- r$name
          break
        }
      }
      if (!is.null(ns)) {
        htmltools::tags$span(
          class = "cross-ref-chip cross-ref-recipe",
          onclick = sprintf(
            "Shiny.setInputValue('%s', '%s', {priority: 'event'})",
            ns("navigate_recipe"), rid
          ),
          bsicons::bs_icon("journal-code", size = ".75rem"),
          " ", rname
        )
      } else {
        htmltools::tags$span(
          class = "cross-ref-chip cross-ref-recipe",
          bsicons::bs_icon("journal-code", size = ".75rem"),
          " ", rname
        )
      }
    })

    recipe_refs <- htmltools::tags$div(
      style = "padding: 0 1.5rem 1rem;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("journal-code"), " Uses Recipes"
      ),
      htmltools::tagList(ref_chips)
    )
  }

  # Estimations timeline
  est_section <- NULL
  if (length(doc$estimations) > 0) {
    est_items <- lapply(seq_along(doc$estimations), function(i) {
      cm <- doc$estimations[[i]]
      est_type <- cm$type %||% "unknown"
      dot_cls <- paste0("wf-dot wf-dot-", est_type)
      type_cls <- paste0("step-type step-type-", est_type)

      htmltools::tags$div(
        class = "workflow-step",
        htmltools::tags$div(class = dot_cls, i),
        htmltools::tags$div(
          class = "step-content",
          htmltools::tags$div(class = type_cls, est_type),
          htmltools::tags$div(
            class = "step-outputs",
            cm$formula %||% ""
          ),
          if (!is.null(cm$by)) {
            htmltools::tags$div(
              style = "color: #7f8c8d; font-size: .8rem;",
              paste("by:", cm$by)
            )
          },
          if (!is.null(cm$description) && nzchar(cm$description %||% "")) {
            htmltools::tags$div(
              style = "color: #95a5a6; font-size: .8rem; font-style: italic;",
              cm$description
            )
          }
        )
      )
    })

    est_section <- htmltools::tags$div(
      style = "padding: 0 1.5rem 1rem;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("bar-chart-fill"), " Estimations"
      ),
      htmltools::tagList(est_items)
    )
  }

  # Estimation type badges
  est_type_section <- NULL
  if (length(wf$estimation_type) > 0) {
    est_badges <- lapply(wf$estimation_type, function(et) {
      cls <- paste0("est-type-badge est-type-", et)
      htmltools::tags$span(class = cls, et)
    })
    est_type_section <- htmltools::tags$div(
      style = "padding: 0 1.5rem 1rem;",
      htmltools::tags$div(
        class = "section-title",
        bsicons::bs_icon("clock-fill"), " Estimation Types"
      ),
      htmltools::tagList(est_badges)
    )
  }

  # R Code snippet
  code_section <- htmltools::tags$div(
    style = "padding: 0 1.5rem 1rem;",
    htmltools::tags$div(
      class = "section-title",
      bsicons::bs_icon("terminal-fill"),
      "Use in R"
    ),
    code_block_ui(
      workflow_code_snippet(wf),
      label = "R Code",
      block_id = paste0("wf_code_", wf$id %||% "x")
    )
  )

  htmltools::tagList(
    header, desc_section, recipe_refs,
    est_type_section, est_section,
    code_section
  )
}
