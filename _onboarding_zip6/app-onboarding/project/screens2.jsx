// screens2.jsx — Completing the app: navigation + every missing state.
// Relies on globals from screens.jsx (UI, F_SANS, F_MONO, Pill, Dot,
// StatBlock, Mark) and map.jsx (MapBase, Territory, DEFAULT_TERRITORIES).

// ─── TAB BAR (the navigation spine that was missing) ────────────────────
function TabBar({ active, t, ui, floating = false }) {
  const dark = ui.text === '#fff';
  const tabs = [
    { id:'map',      label:'Map',      icon:(c)=>(
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round">
        <path d="M9 3L3 5.5v15L9 18l6 2.5 6-2.5v-15L15 5.5 9 3z"/><path d="M9 3v15M15 5.5v15"/>
      </svg>)},
    { id:'board',    label:'Board',    icon:(c)=>(
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinecap="round">
        <path d="M6 9V20M6 9L6 5h5v15M12 13v7M17 11v9M17 11l0-3" /><rect x="3.5" y="20" width="17" height="0.5"/>
      </svg>)},
    { id:'activity', label:'Activity', icon:(c)=>(
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round">
        <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9zM13.7 21a2 2 0 01-3.4 0"/>
      </svg>)},
    { id:'profile',  label:'Profile',  icon:(c)=>(
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke={c} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round">
        <circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-6.5 8-6.5s8 2.5 8 6.5"/>
      </svg>)},
  ];

  const bar = (
    <div style={{ display:'flex', height:64, paddingBottom:6 }}>
      {tabs.map(tab => {
        const on = tab.id === active;
        const c = on ? t.primary : ui.dim;
        return (
          <div key={tab.id} style={{ flex:1, display:'flex', flexDirection:'column',
            alignItems:'center', justifyContent:'center', gap:4, paddingTop:8 }}>
            {tab.icon(c)}
            <span style={{ fontFamily:F_SANS, fontSize:10, fontWeight: on?600:500,
              color:c, letterSpacing:0.1 }}>{tab.label}</span>
          </div>
        );
      })}
    </div>
  );

  if (floating) {
    // glass bar that floats over the map
    return (
      <div style={{ position:'absolute', left:0, right:0, bottom:0, zIndex:40,
        paddingBottom:24,
        background: dark
          ? 'linear-gradient(180deg, rgba(14,14,16,0) 0%, rgba(14,14,16,0.85) 40%)'
          : 'linear-gradient(180deg, rgba(236,234,229,0) 0%, rgba(236,234,229,0.9) 40%)' }}>
        <div style={{ margin:'0 14px',
          background: dark ? 'rgba(23,23,27,0.72)' : 'rgba(255,255,255,0.82)',
          backdropFilter:'blur(20px) saturate(180%)', WebkitBackdropFilter:'blur(20px) saturate(180%)',
          borderRadius:26, border:`0.5px solid ${ui.border}`,
          boxShadow:'0 8px 30px rgba(0,0,0,0.22)' }}>
          {bar}
        </div>
      </div>
    );
  }
  return (
    <div style={{ position:'absolute', left:0, right:0, bottom:0, zIndex:40,
      paddingBottom:24, background:ui.bg,
      borderTop:`0.5px solid ${ui.border}` }}>
      {bar}
    </div>
  );
}

// shared bottom spacer so scroll lists clear the tab bar
const TABBAR_H = 94;


// ─── ONBOARDING 2 — claim & steal ───────────────────────────────────────
function Onboarding2({ t, ui }) {
  return (
    <OnboardFrame t={t} ui={ui} step={1}
      title={<>Steal what<br/>others left open</>}
      body="Run through a rival's area to chip it away. Bigger loops take bigger bites.">
      <MapBase palette={t.mapStyle} w={354} h={354}>
        <Territory color="#E85D5D" poly="50,60 220,50 300,120 280,230 120,250 40,150" viz={t.territoryViz} opacity={0.5}/>
        <Territory color={t.primary} poly="150,150 280,160 300,250 200,300 120,250" viz={t.territoryViz}/>
        <polyline points="150,150 200,130 270,150 300,250" fill="none"
          stroke={t.primary} strokeWidth="4" strokeDasharray="2 7" strokeLinecap="round"/>
        <circle cx="300" cy="250" r="6" fill={t.primary}/>
      </MapBase>
    </OnboardFrame>
  );
}

// ─── ONBOARDING 3 — compete ─────────────────────────────────────────────
function Onboarding3({ t, ui }) {
  return (
    <OnboardFrame t={t} ui={ui} step={2} last
      title={<>Climb the<br/>weekly board</>}
      body="Every km² counts toward your rank. The whole city is playing on the same map.">
      <div style={{ width:'100%', padding:'30px 22px', display:'flex',
        flexDirection:'column', gap:12 }}>
        {[
          { n:'Kai',   c:'#E85D5D', w:'100%', km:'4.82' },
          { n:'Aysu',  c:'#F2C94C', w:'78%',  km:'3.91' },
          { n:'yusif', c:t.primary, w:'52%',  km:'1.42', you:true },
        ].map((r,i) => (
          <div key={i} style={{ display:'flex', alignItems:'center', gap:12 }}>
            <div style={{ width:30, height:30, borderRadius:15, background:r.c, flexShrink:0,
              display:'flex', alignItems:'center', justifyContent:'center',
              color:'#fff', fontFamily:F_SANS, fontSize:13, fontWeight:600 }}>{r.n[0].toUpperCase()}</div>
            <div style={{ flex:1 }}>
              <div style={{ display:'flex', justifyContent:'space-between', marginBottom:5 }}>
                <span style={{ fontFamily:F_SANS, fontSize:13, fontWeight:500, color:ui.text }}>{r.n}{r.you && ' · you'}</span>
                <span style={{ fontFamily:F_MONO, fontSize:12, color:ui.muted }}>{r.km}</span>
              </div>
              <div style={{ height:6, borderRadius:3, background:ui.border, overflow:'hidden' }}>
                <div style={{ width:r.w, height:'100%', background:r.c, borderRadius:3 }}/>
              </div>
            </div>
          </div>
        ))}
      </div>
    </OnboardFrame>
  );
}

function OnboardFrame({ t, ui, step, last, title, body, children }) {
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column', paddingTop:62 }}>
      <div style={{ display:'flex', justifyContent:'center', gap:6, marginTop:20 }}>
        {[0,1,2].map(i => (
          <div key={i} style={{ width: i===step?18:5, height:5, borderRadius:3,
            background: i===step ? t.primary : ui.dim }}/>
        ))}
      </div>
      <div style={{ flex:1, padding:'40px 24px 0', display:'flex', alignItems:'center', justifyContent:'center' }}>
        <div style={{ width:'100%', aspectRatio:'1/1', position:'relative', borderRadius:32,
          overflow:'hidden', border:`0.5px solid ${ui.border}`, background:ui.surface,
          display:'flex', alignItems:'center', justifyContent:'center' }}>{children}</div>
      </div>
      <div style={{ padding:'32px 28px 0', textAlign:'center' }}>
        <div style={{ fontFamily:F_SANS, fontSize:30, fontWeight:600, color:ui.text,
          letterSpacing:-0.8, lineHeight:1.1 }}>{title}</div>
        <div style={{ fontFamily:F_SANS, fontSize:15, lineHeight:1.45, color:ui.muted,
          marginTop:14, maxWidth:320, margin:'14px auto 0' }}>{body}</div>
      </div>
      <div style={{ padding:'28px 24px 56px' }}>
        <button style={{ width:'100%', height:54, borderRadius:27, border:'none',
          background:t.primary, color:'#fff', fontFamily:F_SANS, fontSize:16, fontWeight:600 }}>
          {last ? 'Get started' : 'Continue'}
        </button>
        {!last && <div style={{ textAlign:'center', marginTop:16, fontFamily:F_SANS, fontSize:14, color:ui.muted }}>Skip</div>}
      </div>
    </div>
  );
}


// ─── LOCATION PERMISSION (the iOS system sheet, in context) ─────────────
function LocationPermission({ t, ui }) {
  return (
    <div style={{ height:'100%', position:'relative', overflow:'hidden' }}>
      {/* dimmed map behind */}
      <div style={{ position:'absolute', inset:0 }}>
        <MapBase palette={t.mapStyle} w={402} h={874}>
          <Territory color={t.primary} poly={DEFAULT_TERRITORIES[0].poly} viz={t.territoryViz} opacity={0.6}/>
        </MapBase>
      </div>
      <div style={{ position:'absolute', inset:0, background:'rgba(0,0,0,0.45)' }}/>

      {/* explainer pinned above the system alert */}
      <div style={{ position:'absolute', top:120, left:32, right:32, textAlign:'center' }}>
        <div style={{ fontFamily:F_SANS, fontSize:22, fontWeight:600, color:'#fff',
          letterSpacing:-0.4, textShadow:'0 2px 12px rgba(0,0,0,0.5)' }}>
          RunClaim needs your location
        </div>
        <div style={{ fontFamily:F_SANS, fontSize:14, color:'rgba(255,255,255,0.8)',
          marginTop:8, lineHeight:1.45 }}>
          to draw your route and claim territory while you run — even with the screen off.
        </div>
      </div>

      {/* iOS system permission alert */}
      <div style={{ position:'absolute', top:'50%', left:'50%', transform:'translate(-50%,-50%)',
        width:270, borderRadius:14, overflow:'hidden',
        background:'rgba(248,248,248,0.94)', backdropFilter:'blur(20px)',
        WebkitBackdropFilter:'blur(20px)', textAlign:'center' }}>
        <div style={{ padding:'20px 16px 16px' }}>
          <div style={{ fontFamily:F_SANS, fontSize:17, fontWeight:600, color:'#000' }}>
            Allow “RunClaim” to use your location?
          </div>
          <div style={{ fontFamily:F_SANS, fontSize:13, color:'#000', marginTop:6, lineHeight:1.35 }}>
            Your live position is used to track runs and update the map.
          </div>
          {/* mini map thumbnail like iOS shows */}
          <div style={{ marginTop:12, height:90, borderRadius:8, overflow:'hidden' }}>
            <MapBase palette={t.mapStyle === 'light' ? 'light' : 'dark'} w={238} h={90}>
              <Territory color={t.primary} poly="40,30 150,20 210,55 170,80 60,75" viz="fill-border"/>
            </MapBase>
          </div>
        </div>
        <div style={{ borderTop:'0.5px solid rgba(0,0,0,0.18)', display:'flex', flexDirection:'column' }}>
          {['Allow Once', 'Allow While Using App'].map((l,i) => (
            <div key={i} style={{ padding:'12px', fontFamily:F_SANS, fontSize:17,
              color:'#007AFF', fontWeight: i===1?600:400,
              borderBottom:'0.5px solid rgba(0,0,0,0.18)' }}>{l}</div>
          ))}
          <div style={{ padding:'12px', fontFamily:F_SANS, fontSize:17, color:'#007AFF' }}>Don’t Allow</div>
        </div>
      </div>

      <div style={{ position:'absolute', top:0, left:0, right:0, zIndex:5 }}>
        <IOSStatusBar dark={true}/>
      </div>
    </div>
  );
}


// ─── NOTIFICATION PERMISSION (custom pre-prompt) ────────────────────────
function NotifPermission({ t, ui }) {
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column',
      padding:'62px 24px 0' }}>
      <div style={{ flex:1, display:'flex', flexDirection:'column', justifyContent:'center', gap:14 }}>
        <div style={{ width:64, height:64, borderRadius:18, background:`${t.primary}1F`,
          display:'flex', alignItems:'center', justifyContent:'center' }}>
          <svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke={t.primary} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round">
            <path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9zM13.7 21a2 2 0 01-3.4 0"/>
          </svg>
        </div>
        <div style={{ fontFamily:F_SANS, fontSize:28, fontWeight:600, color:ui.text,
          letterSpacing:-0.6, lineHeight:1.12 }}>
          Know the moment<br/>someone takes your land
        </div>
        <div style={{ fontFamily:F_SANS, fontSize:15, color:ui.muted, lineHeight:1.45 }}>
          We’ll ping you when a rival crosses your border, overtakes you, or when your weekly summary is ready.
        </div>

        {/* sample notification preview */}
        <div style={{ marginTop:12, padding:'12px 14px', borderRadius:16,
          background:ui.surface, border:`0.5px solid ${ui.border}`,
          display:'flex', gap:12, alignItems:'center' }}>
          <div style={{ width:38, height:38, borderRadius:9, background:'#E85D5D',
            display:'flex', alignItems:'center', justifyContent:'center', color:'#fff',
            fontFamily:F_SANS, fontWeight:600 }}>K</div>
          <div style={{ flex:1 }}>
            <div style={{ fontFamily:F_SANS, fontSize:13, fontWeight:600, color:ui.text }}>RunClaim</div>
            <div style={{ fontFamily:F_SANS, fontSize:13, color:ui.muted }}>Kai took 0.12 km² of your territory</div>
          </div>
          <div style={{ fontFamily:F_MONO, fontSize:11, color:ui.dim }}>now</div>
        </div>
      </div>
      <div style={{ padding:'0 0 24px', display:'flex', flexDirection:'column', gap:10 }}>
        <button style={{ height:54, borderRadius:27, border:'none', background:t.primary,
          color:'#fff', fontFamily:F_SANS, fontSize:16, fontWeight:600 }}>Turn on notifications</button>
        <button style={{ height:48, borderRadius:24, border:'none', background:'transparent',
          color:ui.muted, fontFamily:F_SANS, fontSize:15, fontWeight:500 }}>Not now</button>
      </div>
    </div>
  );
}


// ─── COUNTDOWN before a run ─────────────────────────────────────────────
function Countdown({ t, ui }) {
  return (
    <div style={{ height:'100%', position:'relative', overflow:'hidden', background:'#000' }}>
      <div style={{ position:'absolute', inset:0, opacity:0.4 }}>
        <MapBase palette={t.mapStyle} w={402} h={874}>
          <Territory color={t.primary} poly={DEFAULT_TERRITORIES[0].poly} viz={t.territoryViz}/>
        </MapBase>
      </div>
      <div style={{ position:'absolute', inset:0,
        background:`radial-gradient(60% 40% at 50% 45%, ${t.primary}30, rgba(0,0,0,0.85) 70%)` }}/>

      <div style={{ position:'absolute', inset:0, display:'flex', flexDirection:'column',
        alignItems:'center', justifyContent:'center', gap:8 }}>
        <div style={{ fontFamily:F_MONO, fontSize:12, fontWeight:600, color:'rgba(255,255,255,0.6)',
          letterSpacing:2, textTransform:'uppercase' }}>Get ready</div>
        <div style={{ position:'relative', width:180, height:180, display:'flex',
          alignItems:'center', justifyContent:'center' }}>
          <svg width="180" height="180" viewBox="0 0 180 180" style={{ position:'absolute', transform:'rotate(-90deg)' }}>
            <circle cx="90" cy="90" r="82" fill="none" stroke="rgba(255,255,255,0.12)" strokeWidth="5"/>
            <circle cx="90" cy="90" r="82" fill="none" stroke={t.primary} strokeWidth="5"
              strokeLinecap="round" strokeDasharray="515" strokeDashoffset="172"/>
          </svg>
          <div style={{ fontFamily:F_SANS, fontSize:96, fontWeight:600, color:'#fff', letterSpacing:-3 }}>3</div>
        </div>
        <div style={{ fontFamily:F_SANS, fontSize:15, color:'rgba(255,255,255,0.7)', marginTop:8 }}>
          GPS locked · ready to claim
        </div>
      </div>

      <button style={{ position:'absolute', bottom:64, left:24, right:24, height:54,
        borderRadius:27, border:'1px solid rgba(255,255,255,0.2)', background:'rgba(255,255,255,0.08)',
        color:'#fff', fontFamily:F_SANS, fontSize:16, fontWeight:500,
        backdropFilter:'blur(10px)' }}>Cancel</button>

      <div style={{ position:'absolute', top:0, left:0, right:0, zIndex:5 }}>
        <IOSStatusBar dark={true}/>
      </div>
    </div>
  );
}


// ─── RUN PAUSED ─────────────────────────────────────────────────────────
function RunPaused({ t, ui }) {
  const trail = '120,580 130,540 150,500 180,470 220,460 260,450 295,440 320,430 340,400';
  return (
    <div style={{ height:'100%', background:ui.bg, position:'relative' }}>
      <div style={{ position:'absolute', inset:0, filter:'saturate(0.5)' }}>
        <MapBase palette={t.mapStyle} w={402} h={874}>
          <Territory color={t.primary} poly={DEFAULT_TERRITORIES[0].poly} viz={t.territoryViz} opacity={0.5}/>
          <polyline points={trail} fill="none" stroke={t.primary} strokeWidth="5"
            strokeLinecap="round" strokeLinejoin="round" opacity="0.7"/>
          <circle cx="340" cy="400" r="7" fill={t.primary} stroke="#fff" strokeWidth="2.5"/>
        </MapBase>
      </div>
      <div style={{ position:'absolute', inset:0, background: t.dark ? 'rgba(14,14,16,0.55)' : 'rgba(236,234,229,0.5)' }}/>

      {/* paused banner */}
      <div style={{ position:'absolute', top:62, left:16, right:16 }}>
        <div style={{ background:ui.surface, borderRadius:22, border:`0.5px solid ${ui.border}`,
          padding:'14px 18px', display:'flex', justifyContent:'space-between',
          boxShadow:'0 8px 24px rgba(0,0,0,0.2)' }}>
          <StatBlock k="Time" v="12:48" ui={ui}/>
          <StatBlock k="Distance" v="2.4 km" ui={ui}/>
          <StatBlock k="Area" v="0.32" ui={ui}/>
        </div>
      </div>

      <div style={{ position:'absolute', top:'42%', left:0, right:0, textAlign:'center' }}>
        <div style={{ fontFamily:F_MONO, fontSize:13, fontWeight:600, color:ui.muted,
          letterSpacing:2, textTransform:'uppercase' }}>Paused</div>
        <div style={{ fontFamily:F_SANS, fontSize:34, fontWeight:600, color:ui.text,
          letterSpacing:-0.8, marginTop:4 }}>Take a breath</div>
      </div>

      <div style={{ position:'absolute', left:24, right:24, bottom:64, display:'flex',
        flexDirection:'column', gap:12 }}>
        <button style={{ height:64, borderRadius:32, border:'none', background:t.primary,
          color:'#fff', fontFamily:F_SANS, fontSize:17, fontWeight:600,
          display:'flex', alignItems:'center', justifyContent:'center', gap:10,
          boxShadow:`0 10px 30px ${t.primary}55` }}>
          <svg width="18" height="18" viewBox="0 0 20 20" fill="#fff"><path d="M6 4l11 6-11 6V4z"/></svg>
          Resume
        </button>
        <button style={{ height:54, borderRadius:27, border:`0.5px solid ${ui.border}`,
          background:ui.surface, color:'#E85D5D', fontFamily:F_SANS, fontSize:16, fontWeight:600 }}>
          Stop &amp; claim
        </button>
      </div>
    </div>
  );
}


// ─── TERRITORY DETAIL (bottom sheet — tap any area on the map) ──────────
function TerritoryDetail({ t, ui }) {
  return (
    <div style={{ height:'100%', background:ui.bg, position:'relative' }}>
      <div style={{ position:'absolute', inset:0 }}>
        <MapBase palette={t.mapStyle} w={402} h={874}>
          {DEFAULT_TERRITORIES.map(tr => (
            <Territory key={tr.id} color={tr.color} poly={tr.poly} viz={t.territoryViz}
              opacity={tr.id==='r1' ? 1 : 0.4}/>
          ))}
        </MapBase>
      </div>
      <div style={{ position:'absolute', inset:0, background:'rgba(0,0,0,0.25)' }}/>

      {/* bottom sheet */}
      <div style={{ position:'absolute', left:0, right:0, bottom:0, zIndex:30,
        background:ui.surface, borderRadius:'28px 28px 0 0', padding:'12px 20px 40px',
        border:`0.5px solid ${ui.border}`, boxShadow:'0 -8px 40px rgba(0,0,0,0.3)' }}>
        <div style={{ width:40, height:5, borderRadius:3, background:ui.border, margin:'0 auto 18px' }}/>
        <div style={{ display:'flex', alignItems:'center', gap:14 }}>
          <div style={{ width:52, height:52, borderRadius:26, background:'#E85D5D',
            display:'flex', alignItems:'center', justifyContent:'center', color:'#fff',
            fontFamily:F_SANS, fontSize:20, fontWeight:600 }}>K</div>
          <div style={{ flex:1 }}>
            <div style={{ fontFamily:F_SANS, fontSize:19, fontWeight:600, color:ui.text }}>Kai’s territory</div>
            <div style={{ fontFamily:F_MONO, fontSize:12, color:ui.muted, marginTop:2 }}>RANK 1 · CITY CENTER</div>
          </div>
          <div style={{ padding:'6px 12px', borderRadius:999, background:'#E85D5D1F',
            fontFamily:F_MONO, fontSize:12, fontWeight:600, color:'#E85D5D' }}>RIVAL</div>
        </div>

        <div style={{ display:'flex', marginTop:20, padding:'16px 0',
          borderTop:`0.5px solid ${ui.border}`, borderBottom:`0.5px solid ${ui.border}` }}>
          <div style={{ flex:1, textAlign:'center' }}><StatBlock k="Area" v="4.82" ui={ui} align="center"/></div>
          <div style={{ flex:1, textAlign:'center' }}><StatBlock k="Held" v="12d" ui={ui} align="center"/></div>
          <div style={{ flex:1, textAlign:'center' }}><StatBlock k="Runs" v="86" ui={ui} align="center"/></div>
        </div>

        <div style={{ marginTop:16, padding:'12px 14px', borderRadius:14, background:`${t.primary}14`,
          display:'flex', alignItems:'center', gap:10 }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={t.primary} strokeWidth="2" strokeLinecap="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
          <span style={{ fontFamily:F_SANS, fontSize:13, color:ui.text }}>
            Overlaps <b>0.18 km²</b> of your land — run here to take it back.
          </span>
        </div>

        <button style={{ marginTop:16, width:'100%', height:54, borderRadius:27, border:'none',
          background:t.primary, color:'#fff', fontFamily:F_SANS, fontSize:16, fontWeight:600,
          display:'flex', alignItems:'center', justifyContent:'center', gap:10 }}>
          <svg width="18" height="18" viewBox="0 0 20 20" fill="#fff"><path d="M6 4l11 6-11 6V4z"/></svg>
          Run here
        </button>
      </div>

      <div style={{ position:'absolute', top:62, left:16 }}>
        <Pill ui={ui} style={{ padding:'10px 12px' }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={ui.text} strokeWidth="2" strokeLinecap="round"><path d="M15 18l-6-6 6-6"/></svg>
        </Pill>
      </div>
    </div>
  );
}


// ─── SHARE CARD (from “Save & share”) ───────────────────────────────────
function ShareCard({ t, ui }) {
  return (
    <div style={{ height:'100%', background:'#0A0A0C', display:'flex', flexDirection:'column',
      padding:'62px 0 0' }}>
      <div style={{ padding:'12px 24px', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
        <span style={{ fontFamily:F_SANS, fontSize:16, color:'rgba(255,255,255,0.6)' }}>Cancel</span>
        <span style={{ fontFamily:F_SANS, fontSize:17, fontWeight:600, color:'#fff' }}>Share</span>
        <span style={{ width:48 }}/>
      </div>

      {/* the shareable card */}
      <div style={{ flex:1, padding:'20px 24px 0', display:'flex', alignItems:'center' }}>
        <div style={{ width:'100%', borderRadius:24, overflow:'hidden',
          background:'#101015', border:'0.5px solid rgba(255,255,255,0.08)',
          boxShadow:'0 20px 60px rgba(0,0,0,0.5)' }}>
          <div style={{ height:230, position:'relative' }}>
            <MapBase palette={t.mapStyle} w={354} h={230}>
              <Territory color={t.primary} poly="60,40 230,30 320,90 290,180 120,200 50,120" viz="glow"/>
            </MapBase>
            <div style={{ position:'absolute', top:14, left:16, display:'flex', alignItems:'center', gap:8 }}>
              <Mark size={22} color="#fff"/>
              <span style={{ fontFamily:F_SANS, fontSize:14, fontWeight:600, color:'#fff' }}>RunClaim</span>
            </div>
          </div>
          <div style={{ padding:'18px 20px 22px' }}>
            <div style={{ fontFamily:F_SANS, fontSize:13, color:'rgba(255,255,255,0.55)' }}>yusif claimed</div>
            <div style={{ fontFamily:F_SANS, fontSize:46, fontWeight:600, color:'#fff',
              letterSpacing:-1.5, lineHeight:1, marginTop:4 }}>
              +0.42 <span style={{ fontFamily:F_MONO, fontSize:16, color:'rgba(255,255,255,0.5)' }}>km²</span>
            </div>
            <div style={{ display:'flex', gap:24, marginTop:18 }}>
              {[['3.6 km','Distance'],['18:32','Time'],['5:09','Pace']].map(([v,k])=>(
                <div key={k}>
                  <div style={{ fontFamily:F_MONO, fontSize:18, fontWeight:600, color:'#fff' }}>{v}</div>
                  <div style={{ fontFamily:F_MONO, fontSize:10, color:'rgba(255,255,255,0.45)',
                    letterSpacing:1, textTransform:'uppercase', marginTop:2 }}>{k}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* iOS share row */}
      <div style={{ padding:'24px 16px 40px', display:'flex', gap:18, overflow:'hidden' }}>
        {[['Messages','#34C759'],['Instagram','#E1306C'],['WhatsApp','#25D366'],['Copy','#3A3A3C'],['More','#3A3A3C']].map(([n,c])=>(
          <div key={n} style={{ display:'flex', flexDirection:'column', alignItems:'center', gap:6 }}>
            <div style={{ width:56, height:56, borderRadius:28, background:c,
              display:'flex', alignItems:'center', justifyContent:'center', color:'#fff',
              fontFamily:F_SANS, fontSize:20, fontWeight:600 }}>{n[0]}</div>
            <span style={{ fontFamily:F_SANS, fontSize:11, color:'rgba(255,255,255,0.7)' }}>{n}</span>
          </div>
        ))}
      </div>
    </div>
  );
}


// ─── EDIT PROFILE ───────────────────────────────────────────────────────
function EditProfile({ t, ui }) {
  const Field = ({ label, value, hint }) => (
    <div style={{ marginBottom:20 }}>
      <div style={{ fontFamily:F_MONO, fontSize:11, fontWeight:600, color:ui.muted,
        letterSpacing:1, textTransform:'uppercase', marginBottom:8 }}>{label}</div>
      <div style={{ height:50, borderRadius:14, background:ui.surface, border:`0.5px solid ${ui.border}`,
        display:'flex', alignItems:'center', padding:'0 14px',
        fontFamily:F_SANS, fontSize:16, color:ui.text }}>{value}</div>
      {hint && <div style={{ fontFamily:F_SANS, fontSize:12, color:ui.dim, marginTop:6 }}>{hint}</div>}
    </div>
  );
  const COLORS = ['#3B82F6','#FF5A4E','#0ACF83','#A855F7','#FACC15','#E85D5D','#5BCEFA','#F286D8'];
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <div style={{ padding:'62px 24px 12px', display:'flex', alignItems:'center', justifyContent:'space-between' }}>
        <span style={{ fontFamily:F_SANS, fontSize:16, color:ui.muted }}>Cancel</span>
        <span style={{ fontFamily:F_SANS, fontSize:17, fontWeight:600, color:ui.text }}>Edit profile</span>
        <span style={{ fontFamily:F_SANS, fontSize:16, fontWeight:600, color:t.primary }}>Save</span>
      </div>

      <div style={{ flex:1, overflow:'auto', padding:'16px 24px 40px' }}>
        {/* avatar */}
        <div style={{ display:'flex', flexDirection:'column', alignItems:'center', marginBottom:28 }}>
          <div style={{ position:'relative' }}>
            <div style={{ width:88, height:88, borderRadius:44, background:t.primary,
              display:'flex', alignItems:'center', justifyContent:'center', color:'#fff',
              fontFamily:F_SANS, fontSize:34, fontWeight:600 }}>Y</div>
            <div style={{ position:'absolute', bottom:0, right:0, width:30, height:30, borderRadius:15,
              background:ui.surface, border:`2px solid ${ui.bg}`, display:'flex', alignItems:'center', justifyContent:'center' }}>
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke={ui.text} strokeWidth="2"><path d="M12 5v14M5 12h14"/></svg>
            </div>
          </div>
        </div>

        <Field label="Username" value="@yusif" hint="This is how you appear on the map and board."/>
        <Field label="Display name" value="Yusif"/>
        <Field label="Email" value="yusif@gmail.com" hint="From your Google account."/>

        {/* team color picker */}
        <div style={{ fontFamily:F_MONO, fontSize:11, fontWeight:600, color:ui.muted,
          letterSpacing:1, textTransform:'uppercase', marginBottom:12 }}>Team color</div>
        <div style={{ display:'flex', gap:14, flexWrap:'wrap' }}>
          {COLORS.map(c => (
            <div key={c} style={{ width:38, height:38, borderRadius:19, background:c,
              border: c===t.primary ? `3px solid ${ui.text}` : `3px solid transparent`,
              boxShadow: c===t.primary ? `0 0 0 1px ${c}` : 'none' }}/>
          ))}
        </div>
      </div>
    </div>
  );
}


// ─── GUEST MODE (map with “save your progress” banner) ──────────────────
function GuestMap({ t, ui }) {
  return (
    <div style={{ height:'100%', background:ui.bg, position:'relative' }}>
      <div style={{ position:'absolute', inset:0 }}>
        <MapBase palette={t.mapStyle} w={402} h={874}>
          {DEFAULT_TERRITORIES.map(tr => (
            <Territory key={tr.id} color={tr.id==='you'?'#9AA0A6':tr.color} poly={tr.poly}
              viz={t.territoryViz} opacity={tr.id==='you'?0.8:0.5}/>
          ))}
          <circle cx="200" cy="380" r="8" fill="#9AA0A6" stroke="#fff" strokeWidth="2.5"/>
        </MapBase>
      </div>

      {/* guest pill */}
      <div style={{ position:'absolute', top:62, left:16, right:16, display:'flex', justifyContent:'space-between' }}>
        <Pill ui={ui}>
          <div style={{ width:24, height:24, borderRadius:12, background:'#9AA0A6',
            display:'flex', alignItems:'center', justifyContent:'center', color:'#fff',
            fontFamily:F_SANS, fontSize:11, fontWeight:600 }}>?</div>
          <span>Guest</span>
          <div style={{ width:0.5, height:14, background:ui.border, margin:'0 2px' }}/>
          <span style={{ fontFamily:F_MONO, color:ui.muted, fontSize:13 }}>0.30 km²</span>
        </Pill>
      </div>

      {/* save-progress banner */}
      <div style={{ position:'absolute', left:16, right:16, bottom:150,
        background:ui.surface, borderRadius:20, padding:'16px 18px',
        border:`0.5px solid ${ui.border}`, boxShadow:'0 8px 30px rgba(0,0,0,0.22)' }}>
        <div style={{ display:'flex', alignItems:'center', gap:10 }}>
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={t.primary} strokeWidth="1.8" strokeLinejoin="round" strokeLinecap="round"><path d="M19 21H5a2 2 0 01-2-2V5a2 2 0 012-2h11l5 5v11a2 2 0 01-2 2z"/><path d="M17 21v-8H7v8M7 3v5h8"/></svg>
          <div style={{ fontFamily:F_SANS, fontSize:15, fontWeight:600, color:ui.text }}>Don’t lose your territory</div>
        </div>
        <div style={{ fontFamily:F_SANS, fontSize:13, color:ui.muted, marginTop:6, lineHeight:1.45 }}>
          You’re playing as a guest. Sign in with Google to save your map and join the leaderboard.
        </div>
        <button style={{ marginTop:14, width:'100%', height:48, borderRadius:24, border:'none',
          background:'#fff', color:'#1F1F24', fontFamily:F_SANS, fontSize:15, fontWeight:600,
          display:'flex', alignItems:'center', justifyContent:'center', gap:10 }}>
          <svg width="18" height="18" viewBox="0 0 20 20">
            <path d="M19.6 10.23c0-.7-.06-1.36-.18-2H10v3.79h5.39a4.6 4.6 0 01-2 3.03v2.51h3.23c1.89-1.74 2.98-4.31 2.98-7.33z" fill="#4285F4"/>
            <path d="M10 20c2.7 0 4.96-.9 6.62-2.43l-3.23-2.51c-.9.6-2.04.96-3.39.96-2.6 0-4.81-1.76-5.6-4.12H1.06v2.59A10 10 0 0010 20z" fill="#34A853"/>
            <path d="M4.4 11.9A6 6 0 014.07 10c0-.66.11-1.3.32-1.9V5.51H1.06A10 10 0 000 10c0 1.61.39 3.14 1.06 4.49l3.34-2.59z" fill="#FBBC05"/>
            <path d="M10 3.98c1.47 0 2.78.5 3.82 1.5l2.86-2.87C14.96.99 12.7 0 10 0 6.1 0 2.74 2.24 1.06 5.51L4.4 8.1C5.2 5.74 7.4 3.98 10 3.98z" fill="#EA4335"/>
          </svg>
          Sign in with Google
        </button>
      </div>
    </div>
  );
}


Object.assign(window, {
  TabBar, TABBAR_H, Onboarding2, Onboarding3, LocationPermission, NotifPermission,
  Countdown, RunPaused, TerritoryDetail, ShareCard, EditProfile, GuestMap,
});
