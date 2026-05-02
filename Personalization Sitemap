SalesforceInteractions.Personalization.Config.initialize({

  customFlickerDefenseConfig: {
    redisplayTimeoutMilliseconds: 2000,
    renderPersonalizationAfterTimeoutElapsed: false,
  },

  additionalTransformers: [
    // ── EXISTING NUDGE (30-second bottom-right pill + orb) ─────────────────
    {
      name: "ElectraNudge",
      transformerType: "Handlebars",
      lastModifiedDate: 0,
      substitutionDefinitions: {
        ctaUrl: { defaultValue: "[attributes].[ctaUrl]" }
      },
      transformerTypeDetails: {
        html: `
          <style>
            #ec-widget {
              position: fixed; bottom: 36px; right: 36px;
              display: flex; align-items: center;
              z-index: 9999; opacity: 0; transform: translateY(20px);
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            }
            #ec-orb {
              width: 64px; height: 64px; border-radius: 50%;
              background: #1e2235; cursor: pointer; flex-shrink: 0;
              position: relative; display: flex; align-items: center; justify-content: center;
              text-decoration: none;
              box-shadow: 0 0 0 1.5px rgba(249,115,22,0.45), 0 2px 4px rgba(0,0,0,0.4), 0 8px 24px rgba(0,0,0,0.3);
              transition: transform 0.35s cubic-bezier(0.34,1.4,0.64,1), box-shadow 0.3s ease;
              z-index: 2;
            }
            #ec-orb:hover {
              transform: scale(1.08);
              box-shadow: 0 0 0 1.5px rgba(249,115,22,0.7), 0 4px 8px rgba(0,0,0,0.4), 0 16px 40px rgba(0,0,0,0.3);
            }
            .ec-orb-pulse {
              position: absolute; inset: -8px; border-radius: 50%;
              border: 1px solid rgba(249,115,22,0.2);
              animation: ec-orb-breathe 3s ease-in-out infinite; pointer-events: none;
            }
            @keyframes ec-orb-breathe {
              0%,100% { transform:scale(1); opacity:0.7; } 50% { transform:scale(1.1); opacity:0; }
            }
            .ec-orb-ring {
              position: absolute; inset: -5px; border-radius: 50%;
              border: 1.5px solid transparent; border-top-color: #F97316;
              border-right-color: rgba(249,115,22,0.35);
              animation: ec-orb-spin 5s linear infinite; pointer-events: none;
            }
            @keyframes ec-orb-spin { to { transform: rotate(360deg); } }
            .ec-orb-ring2 {
              position: absolute; inset: -9px; border-radius: 50%;
              border: 1px solid transparent; border-bottom-color: rgba(249,115,22,0.15);
              border-left-color: rgba(249,115,22,0.08);
              animation: ec-orb-spin 9s linear infinite reverse; pointer-events: none;
            }
            .ec-orb-gloss {
              position: absolute; top: 6px; left: 9px; right: 9px; height: 16px;
              background: radial-gradient(ellipse at 50% 0%, rgba(255,255,255,0.12) 0%, transparent 100%);
              border-radius: 50%; pointer-events: none;
            }
            .ec-orb-icon { position: relative; z-index: 1; width: 24px; height: 24px; }
            .ec-orb-badge {
              position: absolute; top: -1px; right: -1px; width: 18px; height: 18px;
              background: #ef4444; border-radius: 50%; border: 2.5px solid #0d0f14;
              display: flex; align-items: center; justify-content: center;
              font-size: 9px; font-weight: 800; color: #fff; font-family: inherit;
              opacity: 0; transform: scale(0); box-shadow: 0 2px 6px rgba(239,68,68,0.5);
            }
            #ec-pill {
              height: 64px; background: #252a3a;
              display: flex; align-items: center;
              position: relative; margin-right: -4px; z-index: 1;
              box-shadow: 0 0 0 1.5px rgba(249,115,22,0.5), 0 2px 4px rgba(0,0,0,0.3), 0 8px 32px rgba(0,0,0,0.25);
              width: 0; overflow: hidden;
              border-radius: 32px 0 0 32px; opacity: 0;
              text-decoration: none; cursor: pointer;
              transition: width 0.8s cubic-bezier(0.16,1,0.3,1), opacity 0.6s ease;
            }
            #ec-pill.ec-open { width: 340px; opacity: 1; }
            #ec-pill.ec-closed { width: 0; opacity: 0; transition: width 0.5s cubic-bezier(0.4,0,0.2,1), opacity 0.3s ease; }
            .ec-pill-inner { display: flex; align-items: center; padding: 0 8px 0 28px; width: 340px; flex-shrink: 0; }
            .ec-pill-text { flex: 1; min-width: 0; }
            .ec-pill-eyebrow {
              font-size: 9px; font-weight: 800; letter-spacing: 0.2em; text-transform: uppercase;
              color: #F97316; margin-bottom: 5px; display: flex; align-items: center; gap: 6px;
            }
            .ec-pill-live {
              width: 6px; height: 6px; border-radius: 50%; background: #F97316; flex-shrink: 0;
              animation: ec-pill-pulse 2s ease-in-out infinite; box-shadow: 0 0 6px rgba(249,115,22,0.8);
            }
            @keyframes ec-pill-pulse {
              0%,100% { opacity:1; transform:scale(1); } 50% { opacity:0.4; transform:scale(0.6); }
            }
            .ec-pill-msg {
              font-size: 15px; font-weight: 400; font-style: italic; color: #ffffff;
              letter-spacing: 0.01em; line-height: 1.2; white-space: nowrap;
              font-family: Georgia, 'Times New Roman', serif;
            }
            .ec-pill-cursor {
              display: inline-block; width: 1.5px; height: 13px; background: #F97316;
              vertical-align: middle; margin-left: 2px; border-radius: 1px;
              animation: ec-cur-blink 0.9s step-end infinite;
            }
            @keyframes ec-cur-blink { 0%,100%{opacity:1} 50%{opacity:0} }
            .ec-pill-rule {
              width: 1px; height: 28px;
              background: linear-gradient(180deg, transparent, rgba(249,115,22,0.3) 30%, rgba(249,115,22,0.3) 70%, transparent);
              flex-shrink: 0; margin: 0 14px;
            }
            .ec-pill-dismiss {
              background: transparent; border: none; cursor: pointer;
              width: 36px; height: 36px; display: flex; align-items: center; justify-content: center;
              flex-shrink: 0; color: rgba(255,255,255,0.3); font-size: 13px;
              border-radius: 50%; margin-right: 6px;
              transition: color 0.2s, background 0.2s; font-family: inherit;
            }
            .ec-pill-dismiss:hover { color: #F97316; background: rgba(249,115,22,0.1); }
          </style>

          <div id="ec-widget">
            <a id="ec-pill" href="{{subVar 'ctaUrl'}}" target="_blank" rel="noopener noreferrer">
              <div class="ec-pill-inner">
                <div class="ec-pill-text">
                  <div class="ec-pill-eyebrow"><span class="ec-pill-live"></span>Agentforce AI</div>
                  <div class="ec-pill-msg"><span id="ec-typed"></span><span class="ec-pill-cursor"></span></div>
                </div>
                <div class="ec-pill-rule"></div>
                <button class="ec-pill-dismiss" id="ec-dismiss" aria-label="Dismiss">&#x2715;</button>
              </div>
            </a>
            <a id="ec-orb" href="{{subVar 'ctaUrl'}}" target="_blank" rel="noopener noreferrer" aria-label="Book a test drive with Electra AI">
              <div class="ec-orb-pulse"></div>
              <div class="ec-orb-ring"></div>
              <div class="ec-orb-ring2"></div>
              <div class="ec-orb-gloss"></div>
              <svg class="ec-orb-icon" viewBox="0 0 24 24" fill="#F97316">
                <path d="M13 2L4.09 12.96A1 1 0 005 14.5h5.5L10 22l9.91-10.96A1 1 0 0019 9.5H13.5L13 2z"/>
              </svg>
              <div class="ec-orb-badge" id="ec-badge">1</div>
            </a>
          </div>
        `
      }
    },

    // ── EXIT INTENT NUDGE (v3 — layout fixed) ─────────────────────────────
    {
      name: "ElectraExitNudge",
      transformerType: "Handlebars",
      lastModifiedDate: 0,
      substitutionDefinitions: {
        ctaUrl:   { defaultValue: "[attributes].[ctaUrl]" },
        headline: { defaultValue: "[attributes].[headline]" },
        bodyText: { defaultValue: "[attributes].[bodyText]" },
        ctaLabel: { defaultValue: "[attributes].[ctaLabel]" }
      },
      transformerTypeDetails: {
        html: `
          <style>
            /* Scoped entirely under #elx24 — unique prefix prevents all site CSS conflicts */
            #elx24-bd {
              position:fixed!important;inset:0!important;
              background:rgba(5,7,15,0.82)!important;
              backdrop-filter:blur(8px)!important;-webkit-backdrop-filter:blur(8px)!important;
              z-index:2147483640!important;opacity:0!important;
              transition:opacity 0.4s ease!important;pointer-events:none!important;
            }
            #elx24-bd.elx24-on{opacity:1!important;pointer-events:all!important;}
            #elx24-card {
              position:fixed!important;top:50%!important;left:50%!important;
              transform:translate(-50%,-56%) scale(0.92)!important;
              z-index:2147483641!important;
              width:min(396px,calc(100vw - 32px))!important;
              max-width:396px!important;
              background:#111627!important;
              border-radius:20px!important;
              overflow:hidden!important;
              opacity:0!important;
              transition:transform 0.45s cubic-bezier(0.16,1,0.3,1),opacity 0.35s ease!important;
              pointer-events:none!important;
              border:1px solid rgba(249,115,22,0.22)!important;
              box-shadow:0 40px 100px rgba(0,0,0,0.75),inset 0 1px 0 rgba(255,255,255,0.04)!important;
              font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif!important;
              box-sizing:border-box!important;
            }
            #elx24-card.elx24-on{
              transform:translate(-50%,-50%) scale(1)!important;
              opacity:1!important;pointer-events:all!important;
            }
            /* keyframes — must use unique names */
            @keyframes elx24-car-in{from{transform:translateX(48px);opacity:0}to{transform:translateX(0);opacity:1}}
            @keyframes elx24-live{0%,100%{opacity:1;transform:scale(1)}50%{opacity:0.3;transform:scale(0.6)}}
          </style>

          <div id="elx24-bd"></div>
          <div id="elx24-card">

            <!-- close button — all inline -->
            <button id="elx24-close" style="
              position:absolute!important;top:12px!important;right:12px!important;z-index:10!important;
              width:28px!important;height:28px!important;border-radius:50%!important;
              background:rgba(255,255,255,0.08)!important;border:1px solid rgba(255,255,255,0.13)!important;
              color:rgba(255,255,255,0.5)!important;font-size:13px!important;cursor:pointer!important;
              display:flex!important;align-items:center!important;justify-content:center!important;
              font-family:inherit!important;line-height:1!important;padding:0!important;
            ">&#x2715;</button>

            <!-- orange top bar -->
            <div style="height:2px!important;background:linear-gradient(90deg,transparent,#F97316 35%,#fb923c 55%,transparent)!important;display:block!important;"></div>

            <!-- illustration strip -->
            <div style="
              height:148px!important;position:relative!important;
              background:linear-gradient(180deg,#0a0c18 0%,#0d1020 100%)!important;
              display:flex!important;align-items:center!important;justify-content:center!important;
              overflow:hidden!important;
            ">
              <!-- road -->
              <div style="position:absolute!important;bottom:0!important;left:0!important;right:0!important;height:28px!important;background:#090b15!important;">
                <div style="position:absolute!important;bottom:12px!important;left:0!important;right:0!important;height:1.5px!important;background:linear-gradient(90deg,transparent,rgba(249,115,22,0.45) 30%,rgba(249,115,22,0.6) 50%,rgba(249,115,22,0.45) 70%,transparent)!important;"></div>
              </div>
              <!-- floor glow -->
              <div style="position:absolute!important;bottom:28px!important;left:50%!important;transform:translateX(-50%)!important;width:200px!important;height:18px!important;background:radial-gradient(ellipse at 50% 100%,rgba(249,115,22,0.2) 0%,transparent 70%)!important;pointer-events:none!important;"></div>
              <!-- headlight beam -->
              <div style="position:absolute!important;right:36px!important;bottom:42px!important;width:100px!important;height:44px!important;background:conic-gradient(from -7deg at 0% 55%,rgba(251,191,36,0.1) 0deg,rgba(251,191,36,0.02) 18deg,transparent 19deg)!important;pointer-events:none!important;"></div>
              <!-- speed lines -->
              <div style="position:absolute!important;left:20px!important;top:44px!important;display:flex!important;flex-direction:column!important;gap:7px!important;">
                <div style="width:46px!important;height:1.5px!important;border-radius:2px!important;background:linear-gradient(90deg,transparent,rgba(249,115,22,0.4))!important;opacity:.85!important;"></div>
                <div style="width:30px!important;height:1.5px!important;border-radius:2px!important;background:linear-gradient(90deg,transparent,rgba(249,115,22,0.4))!important;opacity:.5!important;"></div>
                <div style="width:40px!important;height:1.5px!important;border-radius:2px!important;background:linear-gradient(90deg,transparent,rgba(249,115,22,0.4))!important;opacity:.3!important;"></div>
              </div>
              <!-- car SVG -->
              <div style="position:relative!important;z-index:2!important;filter:drop-shadow(0 4px 12px rgba(249,115,22,0.14))!important;animation:elx24-car-in 0.7s 0.1s cubic-bezier(0.16,1,0.3,1) both!important;">
                <svg width="240" height="86" viewBox="0 0 280 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <ellipse cx="140" cy="96" rx="108" ry="5" fill="rgba(0,0,0,0.45)"/>
                  <rect x="20" y="54" width="240" height="30" rx="8" fill="#1c2140"/>
                  <path d="M76 54 C82 30 104 22 130 21 L158 21 C180 21 200 30 206 54 Z" fill="#222844"/>
                  <path d="M157 22 C177 26 200 36 205 54 L165 54 Z" fill="rgba(140,170,220,0.13)"/>
                  <path d="M78 53 C84 34 104 24 130 23 L130 53 Z" fill="rgba(140,170,220,0.08)"/>
                  <path d="M130 22 L158 22 C172 22 188 28 196 38 L130 38 Z" fill="rgba(255,255,255,0.04)"/>
                  <path d="M206 54 L232 54 Q260 54 264 66 L206 66 Z" fill="#161b33"/>
                  <path d="M76 54 L52 54 Q24 54 18 66 L76 66 Z" fill="#161b33"/>
                  <line x1="76" y1="66" x2="206" y2="66" stroke="rgba(249,115,22,0.12)" stroke-width="1"/>
                  <rect x="24" y="76" width="232" height="8" rx="4" fill="#0f1228"/>
                  <rect x="244" y="57" width="18" height="10" rx="3" fill="#1a1f38"/>
                  <rect x="246" y="59" width="12" height="6" rx="2" fill="#F97316" opacity="0.95"/>
                  <rect x="247" y="60" width="9" height="4" rx="1.5" fill="#fbbf24" opacity="0.5"/>
                  <rect x="244" y="55" width="18" height="2" rx="1" fill="rgba(251,191,36,0.4)"/>
                  <rect x="18" y="57" width="14" height="10" rx="3" fill="#1a1f38"/>
                  <rect x="19" y="58" width="10" height="8" rx="2" fill="#ef4444" opacity="0.75"/>
                  <rect x="18" y="55" width="14" height="2" rx="1" fill="rgba(239,68,68,0.4)"/>
                  <circle cx="210" cy="82" r="16" fill="#0d0f1e"/>
                  <circle cx="210" cy="82" r="12" fill="#111428" stroke="#2a3060" stroke-width="1.5"/>
                  <circle cx="210" cy="82" r="7" fill="#141828" stroke="rgba(249,115,22,0.6)" stroke-width="1.5"/>
                  <line x1="210" y1="75" x2="210" y2="89" stroke="rgba(249,115,22,0.3)" stroke-width="1"/>
                  <line x1="203" y1="82" x2="217" y2="82" stroke="rgba(249,115,22,0.3)" stroke-width="1"/>
                  <line x1="205" y1="77" x2="215" y2="87" stroke="rgba(249,115,22,0.2)" stroke-width="1"/>
                  <line x1="215" y1="77" x2="205" y2="87" stroke="rgba(249,115,22,0.2)" stroke-width="1"/>
                  <circle cx="210" cy="82" r="2.5" fill="#F97316" opacity="0.7"/>
                  <circle cx="72" cy="82" r="16" fill="#0d0f1e"/>
                  <circle cx="72" cy="82" r="12" fill="#111428" stroke="#2a3060" stroke-width="1.5"/>
                  <circle cx="72" cy="82" r="7" fill="#141828" stroke="rgba(249,115,22,0.6)" stroke-width="1.5"/>
                  <line x1="72" y1="75" x2="72" y2="89" stroke="rgba(249,115,22,0.3)" stroke-width="1"/>
                  <line x1="65" y1="82" x2="79" y2="82" stroke="rgba(249,115,22,0.3)" stroke-width="1"/>
                  <line x1="67" y1="77" x2="77" y2="87" stroke="rgba(249,115,22,0.2)" stroke-width="1"/>
                  <line x1="77" y1="77" x2="67" y2="87" stroke="rgba(249,115,22,0.2)" stroke-width="1"/>
                  <circle cx="72" cy="82" r="2.5" fill="#F97316" opacity="0.7"/>
                  <rect x="130" y="64" width="28" height="2" rx="1" fill="rgba(255,255,255,0.08)"/>
                  <line x1="155" y1="21" x2="158" y2="12" stroke="rgba(255,255,255,0.18)" stroke-width="1.5" stroke-linecap="round"/>
                  <circle cx="158" cy="11" r="2" fill="rgba(249,115,22,0.5)"/>
                </svg>
              </div>
            </div>

            <!-- content body — all inline styles -->
            <div style="padding:18px 20px 20px!important;box-sizing:border-box!important;">

              <!-- eyebrow -->
              <div style="display:flex!important;align-items:center!important;gap:6px!important;margin-bottom:8px!important;">
                <span style="width:5px!important;height:5px!important;border-radius:50%!important;background:#F97316!important;flex-shrink:0!important;display:inline-block!important;box-shadow:0 0 6px rgba(249,115,22,0.9)!important;animation:elx24-live 2s ease-in-out infinite!important;"></span>
                <span style="font-size:10px!important;font-weight:700!important;letter-spacing:0.15em!important;text-transform:uppercase!important;color:#F97316!important;font-family:inherit!important;">Agentforce AI</span>
              </div>

              <!-- headline -->
              <div style="font-size:20px!important;font-weight:700!important;color:#ffffff!important;line-height:1.2!important;letter-spacing:-0.02em!important;margin-bottom:7px!important;font-family:inherit!important;">{{subVar 'headline'}}</div>

              <!-- body text -->
              <div style="font-size:13px!important;color:rgba(255,255,255,0.52)!important;line-height:1.6!important;margin-bottom:14px!important;font-family:inherit!important;">{{subVar 'bodyText'}}</div>

              <!-- pills row -->
              <div style="display:flex!important;flex-wrap:wrap!important;gap:6px!important;margin-bottom:16px!important;">
                <span style="display:inline-flex!important;align-items:center!important;gap:5px!important;padding:3px 10px 3px 7px!important;background:rgba(249,115,22,0.09)!important;border:1px solid rgba(249,115,22,0.22)!important;border-radius:100px!important;font-size:11px!important;font-weight:500!important;color:rgba(255,255,255,0.7)!important;font-family:inherit!important;"><span style="width:5px!important;height:5px!important;border-radius:50%!important;background:#F97316!important;flex-shrink:0!important;display:inline-block!important;"></span>Books in 2 minutes</span>
                <span style="display:inline-flex!important;align-items:center!important;gap:5px!important;padding:3px 10px 3px 7px!important;background:rgba(249,115,22,0.09)!important;border:1px solid rgba(249,115,22,0.22)!important;border-radius:100px!important;font-size:11px!important;font-weight:500!important;color:rgba(255,255,255,0.7)!important;font-family:inherit!important;"><span style="width:5px!important;height:5px!important;border-radius:50%!important;background:#F97316!important;flex-shrink:0!important;display:inline-block!important;"></span>AI-matched model</span>
                <span style="display:inline-flex!important;align-items:center!important;gap:5px!important;padding:3px 10px 3px 7px!important;background:rgba(249,115,22,0.09)!important;border:1px solid rgba(249,115,22,0.22)!important;border-radius:100px!important;font-size:11px!important;font-weight:500!important;color:rgba(255,255,255,0.7)!important;font-family:inherit!important;"><span style="width:5px!important;height:5px!important;border-radius:50%!important;background:#F97316!important;flex-shrink:0!important;display:inline-block!important;"></span>Nearest dealership</span>
              </div>

              <!-- divider -->
              <div style="height:1px!important;margin-bottom:16px!important;background:linear-gradient(90deg,transparent,rgba(255,255,255,0.07) 40%,rgba(255,255,255,0.07) 60%,transparent)!important;"></div>

              <!-- actions: CTA + Maybe later side by side -->
              <div style="display:flex!important;gap:8px!important;align-items:stretch!important;">
                <a id="elx24-cta" href="{{subVar 'ctaUrl'}}" target="_blank" rel="noopener noreferrer" style="
                  flex:1!important;display:flex!important;align-items:center!important;justify-content:center!important;gap:9px!important;
                  padding:13px 18px!important;
                  background:#F97316!important;
                  border:none!important;border-radius:10px!important;
                  font-size:14px!important;font-weight:700!important;color:#ffffff!important;
                  cursor:pointer!important;text-decoration:none!important;white-space:nowrap!important;
                  box-shadow:0 2px 0 #c45a0a,0 6px 20px rgba(249,115,22,0.4)!important;
                  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif!important;
                  box-sizing:border-box!important;
                  position:relative!important;overflow:hidden!important;
                ">
                  <span style="position:absolute!important;inset:0!important;background:linear-gradient(180deg,rgba(255,255,255,0.13) 0%,transparent 55%)!important;pointer-events:none!important;border-radius:10px!important;"></span>
                  <span style="position:relative!important;z-index:1!important;">{{subVar 'ctaLabel'}}</span>
                  <svg width="14" height="14" viewBox="0 0 14 14" fill="none" style="flex-shrink:0!important;position:relative!important;z-index:1!important;">
                    <path d="M8 1L2.5 7.5H6.5L6 13L11.5 6.5H7.5L8 1Z" fill="white" stroke="white" stroke-width="0.5" stroke-linejoin="round"/>
                  </svg>
                </a>
                <button id="elx24-later" style="
                  flex-shrink:0!important;
                  padding:13px 16px!important;
                  background:rgba(255,255,255,0.05)!important;
                  border:1px solid rgba(255,255,255,0.12)!important;border-radius:10px!important;
                  font-size:13px!important;font-weight:500!important;color:rgba(255,255,255,0.5)!important;
                  cursor:pointer!important;white-space:nowrap!important;
                  font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif!important;
                  box-sizing:border-box!important;
                ">Maybe later</button>
              </div>

            </div>
          </div>
        `
      }
    }
  ],

  personalizationExperienceConfigs: {
    lastModifiedDate: "2026-04-23T00:00:00.000+0000",
    list: [
      // ── EXISTING 30-SECOND PILL NUDGE ──────────────────────────────────────
      {
        name: "ElectraNudge_Experience",
        label: "Electra Nudge",
        dataProvider: { type: "PersonalizationPoint", value: "Electra_Car_Chat_Overlay" },
		sourceMatchers: [
  { type: "PageType", value: "Electra Homepage" },
  { type: "PageType", value: "Electra Vehicle" }
],
        transformationConfig: {
          when: "Immediately", method: "AddOverlay", engagementDestination: "Other",
          transformations: [{ transformerName: "ElectraNudge", substitutionValues: {} }]
        },
        publishedDate: "2026-04-22T00:00:00.000+0000",
        lastModifiedDate: "2026-04-22T00:00:00.000+0000",
        isEnabled: true
      },

      // ── EXIT INTENT NUDGE ──────────────────────────────────────────────────
      {
        name: "ElectraExitNudge_Experience",
        label: "Electra Exit Intent Nudge",
        dataProvider: { type: "PersonalizationPoint", value: "Electra_Exit_Intent_Overlay" },
		sourceMatchers: [
  { type: "PageType", value: "Electra Homepage" },
  { type: "PageType", value: "Electra Vehicle" }
],
        transformationConfig: {
          when: "Immediately", method: "AddOverlay", engagementDestination: "Other",
          transformations: [{ transformerName: "ElectraExitNudge", substitutionValues: {} }]
        },
        publishedDate: "2026-04-23T00:00:00.000+0000",
        lastModifiedDate: "2026-04-23T00:00:00.000+0000",
        isEnabled: true
      }
    ]
  }

});

// ── SDK INIT ─────────────────────────────────────────────────────────────────
SalesforceInteractions.init({
  cookieDomain: 'orgfarm-543580c7c8.my.site.com',
  consents: [{
    provider: "Test Provider",
    purpose: "Tracking",
    status: SalesforceInteractions.ConsentStatus.OptIn
  }]
}).then(() => {

  //SalesforceInteractions.setLoggingLevel(4);

  // ── HELPER: reads contentKey from current page URL at click time and navigates ──
  // Reads window.location.search at the moment of the click, so SPA navigation
  // to a new page (e.g. vehicle page with a contentKey param) is always reflected.
  function ecHandleCtaClick(e, baseHref) {
    e.preventDefault();
    try {
      var params = new URLSearchParams(window.location.search);
      var contentKey = params.get('contentKey');
      var url = baseHref;
      if (contentKey) {
        var separator = url.indexOf('?') !== -1 ? '&' : '?';
        url = url + separator + 'contentKey=' + encodeURIComponent(contentKey);
      }
      window.open(url, '_blank', 'noopener,noreferrer');
    } catch(e2) {
      window.open(baseHref, '_blank', 'noopener,noreferrer');
    }
  }

  // ── EXISTING — 30s pill nudge ─────────────────────────────────────────────
  function ecInitNudge() {
    var widget  = document.getElementById('ec-widget');
    var pill    = document.getElementById('ec-pill');
    var typedEl = document.getElementById('ec-typed');
    var dismiss = document.getElementById('ec-dismiss');
    var orb     = document.getElementById('ec-orb');
    var badge   = document.getElementById('ec-badge');
    if (!widget || !pill || !typedEl || !dismiss || !orb) { setTimeout(ecInitNudge, 300); return; }

    // Capture base hrefs once from the rendered template, then handle at click time
    var pillBaseHref = pill.getAttribute('href') || '';
    var orbBaseHref  = orb.getAttribute('href') || '';
    pill.addEventListener('click', function(e) { ecHandleCtaClick(e, pillBaseHref); });

    var MSGS = ['Ready to feel the thrill?', 'Find your nearest slot today.', 'Book a test drive in 2 minutes.'];
    var mi = 0, ci = 0, writing = true, pillOpen = false;

    function tick() {
      var msg = MSGS[mi];
      if (writing) {
        if (ci < msg.length) { typedEl.textContent += msg[ci++]; setTimeout(tick, 40 + Math.random() * 22); }
        else { setTimeout(function() { writing = false; tick(); }, 2600); }
      } else {
        if (ci > 0) { typedEl.textContent = msg.substring(0, --ci); setTimeout(tick, 18); }
        else { typedEl.textContent = ''; mi = (mi + 1) % MSGS.length; writing = true; setTimeout(tick, 420); }
      }
    }
    function openPill() { pillOpen = true; pill.classList.remove('ec-closed'); pill.classList.add('ec-open'); }
    function closePill() { pillOpen = false; pill.classList.remove('ec-open'); pill.classList.add('ec-closed'); }

    var BASE = 30000;
    setTimeout(function() {
      widget.style.transition = 'opacity 0.8s ease, transform 0.8s cubic-bezier(0.16,1,0.3,1)';
      widget.style.opacity = '1'; widget.style.transform = 'translateY(0)';
    }, BASE);
    setTimeout(openPill, BASE + 900);
    setTimeout(tick, BASE + 1700);
    setTimeout(function() {
      if (!badge) return;
      badge.style.transition = 'opacity 0.3s ease, transform 0.5s cubic-bezier(0.34,1.56,0.64,1)';
      badge.style.opacity = '1'; badge.style.transform = 'scale(1)';
    }, BASE + 2200);
    dismiss.addEventListener('click', function(e) { e.preventDefault(); e.stopPropagation(); closePill(); });
    // orb: first click opens pill; subsequent clicks (pill already open) navigate with contentKey at click time
    orb.addEventListener('click', function(e) {
      if (!pillOpen) { e.preventDefault(); openPill(); return; }
      ecHandleCtaClick(e, orbBaseHref);
    });
    setTimeout(function() {
      if (!pillOpen) return;
      var s = [0,-6,5,-3,2,0], f = 0;
      var iv = setInterval(function() {
        pill.style.transform = 'translateX(' + s[f] + 'px)'; f++;
        if (f >= s.length) { clearInterval(iv); pill.style.transform = ''; }
      }, 70);
    }, BASE + 10000);
  }
  setTimeout(ecInitNudge, 500);

  // ── EXIT INTENT — v2 ─────────────────────────────────────────────────────
  function ecInitExitNudge() {
    var backdrop = document.getElementById('elx24-bd');
    var card     = document.getElementById('elx24-card');
    var closeBtn = document.getElementById('elx24-close');
    var laterBtn = document.getElementById('elx24-later');
    var ctaBtn   = document.getElementById('elx24-cta');
    if (!backdrop || !card) { setTimeout(ecInitExitNudge, 300); return; }

    // Capture base href once; actual contentKey is read at click time
    var ctaBaseHref = ctaBtn ? (ctaBtn.getAttribute('href') || '') : '';

    var SHOWN_KEY     = 'elx24_shown';
    var CONVERTED_KEY = 'elx24_converted';

    function canShow() {
      try {
        if (sessionStorage.getItem(CONVERTED_KEY)) return false;
        if (sessionStorage.getItem(SHOWN_KEY)) return false;
        return true;
      } catch(e) { return true; }
    }

    function open() {
      if (!canShow()) return;
      try { sessionStorage.setItem(SHOWN_KEY, '1'); } catch(e) {}
      backdrop.classList.add('elx24-on');
      card.classList.add('elx24-on');
      document.addEventListener('keydown', onKey);
    }

    function close() {
      backdrop.classList.remove('elx24-on');
      card.classList.remove('elx24-on');
      document.removeEventListener('keydown', onKey);
    }

    function onKey(e) { if (e.key === 'Escape') close(); }

    if (closeBtn) closeBtn.addEventListener('click', close);
    if (laterBtn) laterBtn.addEventListener('click', close);
    backdrop.addEventListener('click', function(e) { if (e.target === backdrop) close(); });
    if (ctaBtn) ctaBtn.addEventListener('click', function(e) {
      try { sessionStorage.setItem(CONVERTED_KEY, '1'); } catch(e2) {}
      ecHandleCtaClick(e, ctaBaseHref);
    });

    // ── detection ──────────────────────────────────────────────────────────
    var PAGE_GATE_MS = 5000;  // must be on page 5s before trigger is armed
    var enteredAt    = Date.now();
    var armed        = false;

    function arm() {
      if (armed) return;
      armed = true;

      // Desktop: cursor leaves through top of viewport (≤ 20px from top)
      document.addEventListener('mouseleave', function onLeave(e) {
        if (e.clientY > 20) return;
        open();
      });

      // Mobile / tab-switch
      document.addEventListener('visibilitychange', function onVis() {
        if (document.visibilityState !== 'hidden') return;
        if (window.matchMedia('(pointer: coarse)').matches) open();
      });
    }

    // Arm after page gate
    var armTimer = setTimeout(arm, PAGE_GATE_MS);

    // If user moves mouse toward top within first 5s, still fire (edge case)
    document.addEventListener('mousemove', function earlyCheck(e) {
      if (e.clientY < 10 && (Date.now() - enteredAt) > 2000) {
        clearTimeout(armTimer); arm();
        document.removeEventListener('mousemove', earlyCheck);
      }
    });
  }

  setTimeout(ecInitExitNudge, 600);

  // ── SITEMAP ───────────────────────────────────────────────────────────────
  const sitemapConfig = {
    global: {},
    pageTypeDefault: { name: "default", interaction: { name: "Default Page" } },
    pageTypes: [
      {
        name: "Electra Homepage",
        isMatch: () => window.location.pathname === '/ElectraCarsWeb/s/',
        interaction: { name: "Electra Homepage", 
					   eventType: "userEngagement" 
					   }
      },
	  {
        name: "Electra Vehicle",
        isMatch: () => window.location.pathname === '/ElectraCarsWeb/s/vehicle-detail',
        interaction: { name: "Electra Vehicle", 
					   eventType: "userEngagement" 
					   }
      },
	  {
        name: "Concierge Agent",
        isMatch: () => window.location.pathname === '/ElectraCarsWeb/s/concierge-agent',
        interaction: { name: "Concierge Agent", 
					   eventType: "userEngagement" 
					   }
      }
	  
    ]
  };

  
  
      const handleSPAPageChange = () => {
        let url = window.location.href;
        const urlChangeInterval = setInterval(() => {
            if (url !== window.location.href) {
                url = window.location.href;
                SalesforceInteractions.reinit();
            }
        }, 2000);
    }

    handleSPAPageChange();
  
  
  
  SalesforceInteractions.initSitemap(sitemapConfig);

});
