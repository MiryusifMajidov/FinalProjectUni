// settings.jsx — Auto-claim moment + a fully fleshed-out Settings flow.
// Redefines window.Settings (richer than the stub in screens.jsx) and adds
// every sub-page a row can open, including a live-preview map style picker.

// ─── AUTO-CLAIM (loop completes mid-run → captured automatically) ───────
function AutoClaim({ t, ui }) {
  const trail = '120,560 130,520 150,490 185,475 225,470 262,478 290,500 300,535 285,565 245,580 195,585 150,580 122,565';
  return (
    <div style={{ height:'100%', background:ui.bg, position:'relative', overflow:'hidden' }}>
      <ClaimCelebrationStyles/>
      <div style={{ position:'absolute', inset:0 }}>
        <MapBase palette={t.mapStyle} w={402} h={874}>
          {DEFAULT_TERRITORIES.filter(x=>x.id!=='you').map(tr => (
            <Territory key={tr.id} color={tr.color} poly={tr.poly} viz={t.territoryViz} opacity={0.35}/>
          ))}
          <Territory color={t.primary} poly={DEFAULT_TERRITORIES[0].poly} viz={t.territoryViz} opacity={0.7}/>

          {/* the just-closed loop, auto-filling */}
          <g style={{ filter:`drop-shadow(0 0 10px ${t.primary})` }}>
            <polygon points="120,560 150,490 225,470 290,500 300,535 245,580 150,580"
              fill={t.primary} style={{ animation:'rc-fill 0.6s ease-out 0.1s both' }}/>
            <polyline points={trail} fill="none" stroke={t.primary} strokeWidth="5"
              strokeLinecap="round" strokeLinejoin="round"/>
          </g>
          {/* burst ring at closure point */}
          <circle cx="122" cy="563" r="40" fill="none" stroke={t.primary} strokeWidth="3"
            style={{ transformOrigin:'122px 563px', animation:'rc-ring 1.1s ease-out 0.1s both' }}/>
          <circle cx="210" cy="525" r="9" fill={t.primary} stroke="#fff" strokeWidth="2.5"/>
        </MapBase>
      </div>

      {/* top stats — run keeps going */}
      <div style={{ position:'absolute', top:62, left:16, right:16 }}>
        <div style={{ background:ui.surface, borderRadius:22, border:`0.5px solid ${ui.border}`,
          padding:'14px 18px', display:'flex', justifyContent:'space-between',
          boxShadow:'0 8px 24px rgba(0,0,0,0.18)' }}>
          <StatBlock k="Time" v="14:02" ui={ui}/>
          <StatBlock k="Distance" v="2.8 km" ui={ui}/>
          <StatBlock k="Area" v="0.50" ui={ui}/>
        </div>
      </div>

      {/* auto-claim toast */}
      <div style={{ position:'absolute', top:'40%', left:24, right:24,
        animation:'rc-num 0.6s cubic-bezier(.3,1.3,.5,1) 0.1s both' }}>
        <div style={{ background: t.dark ? 'rgba(20,20,24,0.92)' : 'rgba(255,255,255,0.95)',
          backdropFilter:'blur(16px)', WebkitBackdropFilter:'blur(16px)',
          borderRadius:22, padding:'18px 20px', border:`0.5px solid ${ui.border}`,
          boxShadow:'0 16px 50px rgba(0,0,0,0.3)', textAlign:'center' }}>
          <div style={{ width:54, height:54, borderRadius:27, background:t.primary, margin:'0 auto',
            display:'flex', alignItems:'center', justifyContent:'center',
            boxShadow:`0 8px 24px ${t.primary}66`,
            animation:'rc-badge 0.6s cubic-bezier(.3,1.4,.5,1) 0.2s both' }}>
            <svg width="28" height="28" viewBox="0 0 38 38" fill="none">
              <path d="M10 19.5l6 6 12-13" stroke="#fff" strokeWidth="3.5" strokeLinecap="round"
                strokeLinejoin="round" strokeDasharray="36" strokeDashoffset="36"
                style={{ animation:'rc-check 0.45s ease-out 0.5s both' }}/>
            </svg>
          </div>
          <div style={{ marginTop:12, fontFamily:F_SANS, fontSize:20, fontWeight:600,
            color:ui.text, letterSpacing:-0.4 }}>Loop claimed automatically</div>
          <div style={{ marginTop:4, fontFamily:F_SANS, fontSize:14, color:ui.muted }}>
            <b style={{ color:t.primary }}>+0.18 km²</b> added · keep running to claim more
          </div>
        </div>
      </div>

      {/* run continues — finish only ends the session */}
      <div style={{ position:'absolute', left:24, right:24, bottom:64, display:'flex',
        alignItems:'center', gap:14, justifyContent:'center' }}>
        <button style={{ width:64, height:64, borderRadius:32,
          background:ui.surface, border:`0.5px solid ${ui.border}`,
          display:'flex', alignItems:'center', justifyContent:'center',
          boxShadow:'0 8px 24px rgba(0,0,0,0.18)' }}>
          <svg width="20" height="20" viewBox="0 0 20 20" fill={ui.text}>
            <rect x="5" y="4" width="3.5" height="12"/><rect x="11.5" y="4" width="3.5" height="12"/>
          </svg>
        </button>
        <button style={{ flex:1, height:64, borderRadius:32, border:'none',
          background:'#E85D5D', color:'#fff', fontFamily:F_SANS, fontSize:17, fontWeight:600,
          display:'flex', alignItems:'center', justifyContent:'center', gap:10,
          boxShadow:'0 10px 30px rgba(232,93,93,0.45)' }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="#fff"><rect x="3" y="3" width="10" height="10" rx="1"/></svg>
          Finish run
        </button>
      </div>
    </div>
  );
}


// ─── shared header for sub-pages ────────────────────────────────────────
function SubHeader({ title, ui, action }) {
  return (
    <div style={{ padding:'62px 16px 12px', display:'flex', alignItems:'center',
      gap:6, borderBottom:`0.5px solid ${ui.border}`, position:'relative' }}>
      <button style={{ display:'flex', alignItems:'center', gap:3, background:'none',
        border:'none', padding:'4px 6px', color: ui.accent || '#3B82F6',
        fontFamily:F_SANS, fontSize:16 }}>
        <svg width="10" height="16" viewBox="0 0 10 16" fill="none" stroke="currentColor"
          strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M8 2L2 8l6 6"/></svg>
        Settings
      </button>
      <div style={{ position:'absolute', left:0, right:0, textAlign:'center',
        fontFamily:F_SANS, fontSize:17, fontWeight:600, color:ui.text, pointerEvents:'none' }}>{title}</div>
      {action && <div style={{ marginLeft:'auto', fontFamily:F_SANS, fontSize:16, fontWeight:600,
        color: ui.accent || '#3B82F6' }}>{action}</div>}
    </div>
  );
}


// ─── MAP STYLE PICKER — with LIVE preview (key request) ─────────────────
function MapStylePicker({ t, ui }) {
  const [sel, setSel] = React.useState(t.mapStyle || 'dark');
  const styles = [
    { id:'dark',  name:'Monochrome', desc:'Minimal, low-distraction. Best at night.' },
    { id:'light', name:'Realistic',  desc:'True-to-life streets, parks and water.' },
    { id:'game',  name:'Game',       desc:'Neon arcade look. Maximum fun.' },
  ];

  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <SubHeader title="Map style" ui={{...ui, accent:t.primary}}/>

      {/* LIVE preview — updates instantly as you tap a style below */}
      <div style={{ padding:'18px 20px 6px' }}>
        <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600, color:ui.muted,
          letterSpacing:1.2, textTransform:'uppercase', marginBottom:10,
          display:'flex', alignItems:'center', gap:8 }}>
          Live preview
          <span style={{ display:'inline-flex', alignItems:'center', gap:5,
            color:t.primary }}>
            <span style={{ width:6, height:6, borderRadius:3, background:t.primary,
              boxShadow:`0 0 5px ${t.primary}` }}/>updating
          </span>
        </div>
        <div style={{ position:'relative', height:200, borderRadius:22, overflow:'hidden',
          border:`0.5px solid ${ui.border}`, boxShadow:'0 8px 30px rgba(0,0,0,0.18)' }}>
          <MapBase palette={sel} w={362} h={200}>
            {DEFAULT_TERRITORIES.slice(0,3).map(tr => (
              <Territory key={tr.id} color={tr.id==='you'?t.primary:tr.color}
                poly={scaleProvPoly(tr.poly)} viz={t.territoryViz}/>
            ))}
            <circle cx="180" cy="110" r="7" fill={t.primary} stroke="#fff" strokeWidth="2.5"/>
          </MapBase>
          {/* floating pill mimic so it reads as the real map */}
          <div style={{ position:'absolute', top:12, left:12,
            display:'inline-flex', alignItems:'center', gap:7, padding:'7px 11px',
            borderRadius:999, background: sel==='light' ? 'rgba(255,255,255,0.9)' : 'rgba(20,20,24,0.8)',
            backdropFilter:'blur(10px)', WebkitBackdropFilter:'blur(10px)',
            border:`0.5px solid ${ui.border}` }}>
            <div style={{ width:18, height:18, borderRadius:9, background:t.primary,
              display:'flex', alignItems:'center', justifyContent:'center', color:'#fff',
              fontFamily:F_SANS, fontSize:9, fontWeight:600 }}>Y</div>
            <span style={{ fontFamily:F_SANS, fontSize:12, fontWeight:500,
              color: sel==='light' ? '#1a1a1a' : '#fff' }}>yusif</span>
          </div>
        </div>
      </div>

      {/* selectable cards, each a real thumbnail of that style */}
      <div style={{ flex:1, overflow:'auto', padding:'14px 16px 40px',
        display:'flex', flexDirection:'column', gap:12 }}>
        {styles.map(s => {
          const on = sel === s.id;
          return (
            <div key={s.id} onClick={() => setSel(s.id)}
              style={{ display:'flex', alignItems:'center', gap:14, padding:10,
                borderRadius:18, cursor:'pointer',
                background: on ? `${t.primary}12` : ui.surface,
                border: on ? `1.5px solid ${t.primary}` : `0.5px solid ${ui.border}` }}>
              {/* thumbnail */}
              <div style={{ width:72, height:72, borderRadius:14, overflow:'hidden', flexShrink:0,
                border:`0.5px solid ${ui.border}` }}>
                <MapBase palette={s.id} w={72} h={72}>
                  <Territory color={t.primary} poly="14,16 50,12 64,34 44,58 18,50" viz="fill-border"/>
                </MapBase>
              </div>
              <div style={{ flex:1 }}>
                <div style={{ fontFamily:F_SANS, fontSize:16, fontWeight:600, color:ui.text }}>{s.name}</div>
                <div style={{ fontFamily:F_SANS, fontSize:13, color:ui.muted, marginTop:3,
                  lineHeight:1.35 }}>{s.desc}</div>
              </div>
              {/* radio */}
              <div style={{ width:24, height:24, borderRadius:12, flexShrink:0,
                border: on ? 'none' : `2px solid ${ui.dim}`,
                background: on ? t.primary : 'transparent',
                display:'flex', alignItems:'center', justifyContent:'center' }}>
                {on && <svg width="13" height="13" viewBox="0 0 14 14" fill="none">
                  <path d="M3 7.5l3 3 5-6" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>}
              </div>
            </div>
          );
        })}

        <div style={{ fontFamily:F_SANS, fontSize:12, color:ui.dim, textAlign:'center',
          marginTop:6, lineHeight:1.5 }}>
          Changes apply to the map instantly — no need to go back to check.
        </div>
      </div>
    </div>
  );
}
// nudge the default territory polys toward the small preview viewport
function scaleProvPoly(poly) {
  return poly.split(' ').map(pt => {
    const [x,y] = pt.split(',').map(Number);
    return `${(x*0.9).toFixed(0)},${(y*0.42).toFixed(0)}`;
  }).join(' ');
}


// ─── ACCOUNT ────────────────────────────────────────────────────────────
function AccountSettings({ t, ui }) {
  const Row = ({ label, value, last, danger, sub }) => (
    <div style={{ display:'flex', alignItems:'center', minHeight:54, padding:'0 16px',
      borderBottom: last ? 'none' : `0.5px solid ${ui.border}` }}>
      <div style={{ flex:1 }}>
        <div style={{ fontFamily:F_SANS, fontSize:15, color: danger ? '#E85D5D' : ui.text }}>{label}</div>
        {sub && <div style={{ fontFamily:F_SANS, fontSize:12, color:ui.dim, marginTop:2 }}>{sub}</div>}
      </div>
      {value && <div style={{ fontFamily:F_SANS, fontSize:14, color:ui.muted, marginRight:6 }}>{value}</div>}
      {!danger && <Chevron ui={ui}/>}
    </div>
  );
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <SubHeader title="Account" ui={{...ui, accent:t.primary}}/>
      <div style={{ flex:1, overflow:'auto', padding:'20px 0 40px' }}>
        {/* connected google account */}
        <div style={{ margin:'0 16px 24px', padding:'16px', borderRadius:18, background:ui.surface,
          border:`0.5px solid ${ui.border}`, display:'flex', alignItems:'center', gap:14 }}>
          <div style={{ width:46, height:46, borderRadius:23, background:'#fff',
            display:'flex', alignItems:'center', justifyContent:'center',
            boxShadow:'0 1px 3px rgba(0,0,0,0.15)' }}>
            <svg width="22" height="22" viewBox="0 0 20 20">
              <path d="M19.6 10.23c0-.7-.06-1.36-.18-2H10v3.79h5.39a4.6 4.6 0 01-2 3.03v2.51h3.23c1.89-1.74 2.98-4.31 2.98-7.33z" fill="#4285F4"/>
              <path d="M10 20c2.7 0 4.96-.9 6.62-2.43l-3.23-2.51c-.9.6-2.04.96-3.39.96-2.6 0-4.81-1.76-5.6-4.12H1.06v2.59A10 10 0 0010 20z" fill="#34A853"/>
              <path d="M4.4 11.9A6 6 0 014.07 10c0-.66.11-1.3.32-1.9V5.51H1.06A10 10 0 000 10c0 1.61.39 3.14 1.06 4.49l3.34-2.59z" fill="#FBBC05"/>
              <path d="M10 3.98c1.47 0 2.78.5 3.82 1.5l2.86-2.87C14.96.99 12.7 0 10 0 6.1 0 2.74 2.24 1.06 5.51L4.4 8.1C5.2 5.74 7.4 3.98 10 3.98z" fill="#EA4335"/>
            </svg>
          </div>
          <div style={{ flex:1 }}>
            <div style={{ fontFamily:F_SANS, fontSize:15, fontWeight:600, color:ui.text }}>Google</div>
            <div style={{ fontFamily:F_SANS, fontSize:13, color:ui.muted, marginTop:1 }}>yusif@gmail.com</div>
          </div>
          <div style={{ display:'flex', alignItems:'center', gap:5, padding:'5px 10px', borderRadius:999,
            background:'#4ECCA322' }}>
            <div style={{ width:6, height:6, borderRadius:3, background:'#4ECCA3' }}/>
            <span style={{ fontFamily:F_MONO, fontSize:11, fontWeight:600, color:'#4ECCA3' }}>LINKED</span>
          </div>
        </div>

        <SettingsGroup ui={ui}>
          <Row label="Edit profile" sub="Name, username, team color"/>
          <Row label="Change username" value="@yusif"/>
          <Row label="Email" value="yusif@gmail.com" last/>
        </SettingsGroup>

        <SettingsGroup ui={ui} title="Data">
          <Row label="Export my runs" sub="Download a GPX of every claim"/>
          <Row label="Clear local cache" last/>
        </SettingsGroup>

        <SettingsGroup ui={ui}>
          <Row label="Sign out" danger/>
          <Row label="Delete account" danger sub="Removes your territory permanently" last/>
        </SettingsGroup>
      </div>
    </div>
  );
}


// ─── NOTIFICATIONS DETAIL ───────────────────────────────────────────────
function NotificationSettings({ t, ui }) {
  const [s, setS] = React.useState({ steal:true, enter:true, overtaken:true, weekly:false, nearby:true, sound:true });
  const Toggle = ({ k, label, sub, last }) => (
    <div style={{ display:'flex', alignItems:'center', minHeight:56, padding:'0 16px',
      borderBottom: last ? 'none' : `0.5px solid ${ui.border}` }}>
      <div style={{ flex:1, paddingRight:12 }}>
        <div style={{ fontFamily:F_SANS, fontSize:15, color:ui.text }}>{label}</div>
        {sub && <div style={{ fontFamily:F_SANS, fontSize:12, color:ui.dim, marginTop:2, lineHeight:1.35 }}>{sub}</div>}
      </div>
      <div onClick={() => setS(p => ({...p, [k]: !p[k]}))}
        style={{ width:42, height:25, borderRadius:13, flexShrink:0, cursor:'pointer',
          background: s[k] ? t.primary : ui.border, position:'relative', transition:'background .2s' }}>
        <div style={{ position:'absolute', top:2, left: s[k] ? 19 : 2, width:21, height:21,
          borderRadius:11, background:'#fff', boxShadow:'0 1px 3px rgba(0,0,0,0.18)',
          transition:'left .2s' }}/>
      </div>
    </div>
  );
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <SubHeader title="Notifications" ui={{...ui, accent:t.primary}}/>
      <div style={{ flex:1, overflow:'auto', padding:'20px 0 40px' }}>
        <SettingsGroup ui={ui} title="Territory">
          <Toggle k="steal" label="Someone takes my area"
            sub="A rival overlapped and claimed part of your land"/>
          <Toggle k="enter" label="Runner enters my area"
            sub="Someone is running inside your territory right now"/>
          <Toggle k="nearby" label="Rival nearby" sub="A top player started a run near you" last/>
        </SettingsGroup>

        <SettingsGroup ui={ui} title="Competition">
          <Toggle k="overtaken" label="Overtaken on the board"
            sub="You dropped a rank this week"/>
          <Toggle k="weekly" label="Weekly summary" sub="Every Monday at 9:00" last/>
        </SettingsGroup>

        <SettingsGroup ui={ui} title="Sound">
          <Toggle k="sound" label="In-run audio cues"
            sub="Hear a chime the moment a loop is claimed" last/>
        </SettingsGroup>
      </div>
    </div>
  );
}


// ─── shared bits ────────────────────────────────────────────────────────
function Chevron({ ui }) {
  return (
    <svg width="7" height="12" viewBox="0 0 7 12" fill="none" style={{ flexShrink:0 }}>
      <path d="M1 1l5 5-5 5" stroke={ui.dim} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}
function SettingsGroup({ ui, title, children }) {
  return (
    <div style={{ marginBottom:24 }}>
      {title && <div style={{ padding:'0 32px 6px', fontFamily:F_MONO, fontSize:10, fontWeight:600,
        color:ui.muted, letterSpacing:1.2, textTransform:'uppercase' }}>{title}</div>}
      <div style={{ margin:'0 16px', background:ui.surface, borderRadius:18,
        border:`0.5px solid ${ui.border}`, overflow:'hidden' }}>{children}</div>
    </div>
  );
}


// ─── SETTINGS MAIN (richer — icons, values, clear affordances) ──────────
function Settings({ t, ui }) {
  const Row = ({ icon, iconBg, label, value, toggle, chevron=true, last, danger, onToggle }) => (
    <div style={{ display:'flex', alignItems:'center', minHeight:52, padding:'8px 16px',
      borderBottom: last ? 'none' : `0.5px solid ${ui.border}` }}>
      {icon && (
        <div style={{ width:30, height:30, borderRadius:8, background:iconBg, marginRight:12,
          display:'flex', alignItems:'center', justifyContent:'center', flexShrink:0 }}>{icon}</div>
      )}
      <div style={{ flex:1, fontFamily:F_SANS, fontSize:15, color: danger ? '#E85D5D' : ui.text }}>{label}</div>
      {value && <div style={{ fontFamily:F_SANS, fontSize:14, color:ui.muted, marginRight:8 }}>{value}</div>}
      {toggle !== undefined ? (
        <div style={{ width:42, height:25, borderRadius:13, background: toggle ? t.primary : ui.border,
          position:'relative' }}>
          <div style={{ position:'absolute', top:2, left: toggle ? 19 : 2, width:21, height:21,
            borderRadius:11, background:'#fff', boxShadow:'0 1px 3px rgba(0,0,0,0.18)' }}/>
        </div>
      ) : (chevron && !danger && <Chevron ui={ui}/>)}
    </div>
  );
  const I = (path, opts={}) => (
    <svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2"
      strokeLinecap="round" strokeLinejoin="round" {...opts}>{path}</svg>
  );

  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <div style={{ padding:'70px 24px 18px' }}>
        <div style={{ fontFamily:F_SANS, fontSize:34, fontWeight:600, color:ui.text, letterSpacing:-1 }}>Settings</div>
      </div>

      <div style={{ flex:1, overflow:'auto', paddingBottom:40 }}>
        {/* profile card → opens Account */}
        <div style={{ margin:'0 16px 24px', padding:'14px 16px', borderRadius:18, background:ui.surface,
          border:`0.5px solid ${ui.border}`, display:'flex', alignItems:'center', gap:14 }}>
          <div style={{ width:52, height:52, borderRadius:26, background:t.primary,
            display:'flex', alignItems:'center', justifyContent:'center', color:'#fff',
            fontFamily:F_SANS, fontSize:20, fontWeight:600 }}>Y</div>
          <div style={{ flex:1 }}>
            <div style={{ fontFamily:F_SANS, fontSize:17, fontWeight:600, color:ui.text }}>Yusif</div>
            <div style={{ fontFamily:F_SANS, fontSize:13, color:ui.muted, marginTop:1 }}>@yusif · Account, security</div>
          </div>
          <Chevron ui={ui}/>
        </div>

        <SettingsGroup ui={ui} title="Map &amp; appearance">
          <Row iconBg="#3B82F6" icon={I(<><path d="M9 3L3 5.5v15L9 18l6 2.5 6-2.5v-15L15 5.5 9 3z"/><path d="M9 3v15M15 5.5v15"/></>)}
            label="Map style" value="Monochrome"/>
          <Row iconBg="#9B7EDC" icon={I(<><polygon points="12 3 20 8 17 19 7 19 4 8"/></>)}
            label="Territory look" value="Fill + border"/>
          <Row iconBg="#1F1F24" icon={I(<><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2"/></>)}
            label="Appearance" value="Dark" last/>
        </SettingsGroup>

        <SettingsGroup ui={ui} title="Tracking &amp; privacy">
          <Row iconBg="#4ECCA3" icon={I(<><circle cx="12" cy="10" r="3"/><path d="M12 21s-7-5.5-7-11a7 7 0 0114 0c0 5.5-7 11-7 11z"/></>)}
            label="Background tracking" toggle={true} chevron={false}/>
          <Row iconBg="#5BCEFA" icon={I(<><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></>)}
            label="Show me on the map" toggle={true} chevron={false}/>
          <Row iconBg="#F2C94C" icon={I(<><path d="M12 2a7 7 0 017 7c0 5-7 13-7 13S5 14 5 9a7 7 0 017-7z"/><circle cx="12" cy="9" r="2.5"/></>)}
            label="Location precision" value="Precise" last/>
        </SettingsGroup>

        <SettingsGroup ui={ui} title="Alerts">
          <Row iconBg="#E85D5D" icon={I(<><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9z"/><path d="M13.7 21a2 2 0 01-3.4 0"/></>)}
            label="Notifications" value="5 on" last/>
        </SettingsGroup>

        <SettingsGroup ui={ui} title="Support">
          <Row iconBg="#9AA0A6" icon={I(<><circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 015 0c0 1.5-2.5 2-2.5 3.5"/><circle cx="12" cy="17" r="0.6" fill="#fff" stroke="none"/></>)}
            label="Help &amp; support"/>
          <Row iconBg="#9AA0A6" icon={I(<><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><path d="M14 2v6h6"/></>)}
            label="Terms &amp; privacy" last/>
        </SettingsGroup>

        <SettingsGroup ui={ui}>
          <Row label="Sign out" danger chevron={false} last/>
        </SettingsGroup>

        <div style={{ textAlign:'center', fontFamily:F_MONO, fontSize:11, color:ui.dim, paddingTop:4 }}>
          RunClaim · v1.0.0
        </div>
      </div>
    </div>
  );
}


Object.assign(window, {
  AutoClaim, MapStylePicker, AccountSettings, NotificationSettings, Settings,
});
