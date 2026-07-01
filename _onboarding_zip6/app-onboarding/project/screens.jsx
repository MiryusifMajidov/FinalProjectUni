// screens.jsx — All 12 RunClaim iOS screens.
// Each screen is a fragment rendered INSIDE an IOSDevice. The device frame
// owns status bar + home indicator; we paint the chrome above and content
// below.

const UI = {
  dark:  { bg:'#0E0E10', surface:'#17171B', surfaceAlt:'#1F1F24',
           text:'#fff', muted:'rgba(255,255,255,0.55)', dim:'rgba(255,255,255,0.35)',
           border:'rgba(255,255,255,0.08)' },
  light: { bg:'#ECEAE5', surface:'#fff', surfaceAlt:'#F5F3EE',
           text:'#0E0E10', muted:'rgba(0,0,0,0.55)', dim:'rgba(0,0,0,0.35)',
           border:'rgba(0,0,0,0.07)' },
};

// fonts
const F_SANS = '"Geist", -apple-system, system-ui, sans-serif';
const F_MONO = '"Geist Mono", "JetBrains Mono", ui-monospace, monospace';

// ─── shared atoms ────────────────────────────────────────────────────────
function Pill({ children, ui, style }) {
  return (
    <div style={{
      display:'inline-flex', alignItems:'center', gap:8,
      padding:'10px 14px', borderRadius:999,
      background: ui.surface, color: ui.text,
      border:`0.5px solid ${ui.border}`,
      fontFamily: F_SANS, fontSize:14, fontWeight:500,
      boxShadow:'0 1px 2px rgba(0,0,0,0.08), 0 8px 24px rgba(0,0,0,0.10)',
      ...style,
    }}>{children}</div>
  );
}

function Dot({ color, size=8 }) {
  return <div style={{ width:size, height:size, borderRadius:size, background:color, flexShrink:0 }}/>;
}

function StatBlock({ k, v, ui, mono=true, align='left' }) {
  return (
    <div style={{ textAlign:align }}>
      <div style={{ fontFamily:F_SANS, fontSize:10, fontWeight:600,
        letterSpacing:0.8, textTransform:'uppercase', color:ui.muted }}>{k}</div>
      <div style={{ fontFamily: mono ? F_MONO : F_SANS, fontSize:28, fontWeight:600,
        color:ui.text, letterSpacing:-0.5, lineHeight:1.05, marginTop:4 }}>{v}</div>
    </div>
  );
}

// Logo mark — a hand-drawn-feel pentagon loop with closing arrow
function Mark({ size=44, color='#3B82F6' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 44 44" fill="none">
      <path d="M 8 14 L 22 6 L 36 16 L 32 34 L 14 36 Z"
        stroke={color} strokeWidth="3" strokeLinejoin="round" strokeLinecap="round"/>
      <circle cx="8" cy="14" r="3.5" fill={color}/>
    </svg>
  );
}


// ─── 1. SPLASH ──────────────────────────────────────────────────────────
function Splash({ t, ui }) {
  return (
    <div style={{ height:'100%', display:'flex', flexDirection:'column',
      alignItems:'center', justifyContent:'center', background:ui.bg, paddingBottom:80 }}>
      <Mark size={64} color={t.primary}/>
      <div style={{ fontFamily:F_SANS, fontSize:34, fontWeight:600,
        color:ui.text, letterSpacing:-1.2, marginTop:22 }}>RunClaim</div>
      <div style={{ fontFamily:F_MONO, fontSize:11, fontWeight:500,
        color:ui.muted, marginTop:10, letterSpacing:1.2, textTransform:'uppercase' }}>
        Every step is territory
      </div>
    </div>
  );
}


// ─── 2. ONBOARDING ──────────────────────────────────────────────────────
function Onboarding({ t, ui }) {
  // Mini map illustration with one closed territory + one being drawn
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex',
      flexDirection:'column', paddingTop:62 }}>
      {/* paged dots */}
      <div style={{ display:'flex', justifyContent:'center', gap:6, marginTop:20 }}>
        <div style={{ width:18, height:5, borderRadius:3, background:t.primary }}/>
        <div style={{ width:5, height:5, borderRadius:3, background:ui.dim }}/>
        <div style={{ width:5, height:5, borderRadius:3, background:ui.dim }}/>
      </div>

      {/* illustration */}
      <div style={{ flex:1, padding:'40px 24px 0', display:'flex',
        alignItems:'center', justifyContent:'center' }}>
        <div style={{ width:'100%', aspectRatio:'1/1', position:'relative',
          borderRadius:32, overflow:'hidden',
          border:`0.5px solid ${ui.border}`, background:ui.surface }}>
          <MapBase palette={t.mapStyle} w={354} h={354}>
            <Territory color={t.primary}
              poly="60,80 200,60 280,140 250,260 110,280 50,180"
              viz={t.territoryViz}/>
            {/* in-progress dotted loop */}
            <polyline points="200,300 250,320 280,300" fill="none"
              stroke={t.primary} strokeWidth="3" strokeDasharray="2 6" strokeLinecap="round"/>
            <circle cx="200" cy="300" r="6" fill={t.primary}/>
            <circle cx="200" cy="300" r="12" fill={t.primary} fillOpacity="0.25"/>
          </MapBase>
        </div>
      </div>

      {/* copy */}
      <div style={{ padding:'32px 28px 0', textAlign:'center' }}>
        <div style={{ fontFamily:F_SANS, fontSize:30, fontWeight:600,
          color:ui.text, letterSpacing:-0.8, lineHeight:1.1 }}>
          Run a loop.<br/>Claim the ground.
        </div>
        <div style={{ fontFamily:F_SANS, fontSize:15, fontWeight:400, lineHeight:1.45,
          color:ui.muted, marginTop:14, maxWidth:320, margin:'14px auto 0' }}>
          Close any path on the map and the area inside becomes yours.
          Everyone in the city sees it.
        </div>
      </div>

      {/* CTA */}
      <div style={{ padding:'28px 24px 56px' }}>
        <button style={{ width:'100%', height:54, borderRadius:27, border:'none',
          background:t.primary, color:'#fff',
          fontFamily:F_SANS, fontSize:16, fontWeight:600, letterSpacing:-0.2 }}>
          Continue
        </button>
        <div style={{ textAlign:'center', marginTop:16,
          fontFamily:F_SANS, fontSize:14, color:ui.muted }}>Skip</div>
      </div>
    </div>
  );
}


// ─── 3. LOGIN ────────────────────────────────────────────────────────────
function Login({ t, ui }) {
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex',
      flexDirection:'column', padding:'62px 24px 56px' }}>
      <div style={{ flex:1, display:'flex', flexDirection:'column',
        alignItems:'center', justifyContent:'center', paddingBottom:60 }}>
        <Mark size={48} color={t.primary}/>
        <div style={{ fontFamily:F_SANS, fontSize:30, fontWeight:600,
          color:ui.text, letterSpacing:-0.8, marginTop:24 }}>Welcome back</div>
        <div style={{ fontFamily:F_SANS, fontSize:15, color:ui.muted,
          marginTop:8 }}>Sign in to keep your territory</div>
      </div>

      <div style={{ display:'flex', flexDirection:'column', gap:12 }}>
        {/* Google */}
        <button style={{ height:54, borderRadius:27, border:'none',
          background:'#fff', color:'#1F1F24',
          fontFamily:F_SANS, fontSize:16, fontWeight:500, letterSpacing:-0.2,
          display:'flex', alignItems:'center', justifyContent:'center', gap:12,
          boxShadow:'0 1px 2px rgba(0,0,0,0.08)' }}>
          <svg width="20" height="20" viewBox="0 0 20 20">
            <path d="M19.6 10.23c0-.7-.06-1.36-.18-2H10v3.79h5.39a4.6 4.6 0 01-2 3.03v2.51h3.23c1.89-1.74 2.98-4.31 2.98-7.33z" fill="#4285F4"/>
            <path d="M10 20c2.7 0 4.96-.9 6.62-2.43l-3.23-2.51c-.9.6-2.04.96-3.39.96-2.6 0-4.81-1.76-5.6-4.12H1.06v2.59A10 10 0 0010 20z" fill="#34A853"/>
            <path d="M4.4 11.9A6 6 0 014.07 10c0-.66.11-1.3.32-1.9V5.51H1.06A10 10 0 000 10c0 1.61.39 3.14 1.06 4.49l3.34-2.59z" fill="#FBBC05"/>
            <path d="M10 3.98c1.47 0 2.78.5 3.82 1.5l2.86-2.87C14.96.99 12.7 0 10 0 6.1 0 2.74 2.24 1.06 5.51L4.4 8.1C5.2 5.74 7.4 3.98 10 3.98z" fill="#EA4335"/>
          </svg>
          Continue with Google
        </button>

        {/* divider */}
        <div style={{ display:'flex', alignItems:'center', gap:12, padding:'12px 0' }}>
          <div style={{ flex:1, height:0.5, background:ui.border }}/>
          <span style={{ fontFamily:F_MONO, fontSize:11, color:ui.dim,
            letterSpacing:1, textTransform:'uppercase' }}>or</span>
          <div style={{ flex:1, height:0.5, background:ui.border }}/>
        </div>

        {/* Guest */}
        <button style={{ height:54, borderRadius:27,
          border:`0.5px solid ${ui.border}`, background:'transparent',
          color:ui.text,
          fontFamily:F_SANS, fontSize:16, fontWeight:500, letterSpacing:-0.2 }}>
          Continue as guest
        </button>

        <div style={{ textAlign:'center', marginTop:16,
          fontFamily:F_SANS, fontSize:12, color:ui.dim, lineHeight:1.5 }}>
          By continuing you accept our<br/>
          <span style={{ color:ui.muted }}>Terms</span> and <span style={{ color:ui.muted }}>Privacy</span>.
        </div>
      </div>
    </div>
  );
}


// ─── 4. USERNAME ────────────────────────────────────────────────────────
function Username({ t, ui }) {
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex',
      flexDirection:'column', padding:'72px 24px 0' }}>
      <div style={{ fontFamily:F_MONO, fontSize:11, fontWeight:500,
        color:ui.muted, letterSpacing:1.2, textTransform:'uppercase' }}>Step 1 of 1</div>
      <div style={{ fontFamily:F_SANS, fontSize:30, fontWeight:600,
        color:ui.text, letterSpacing:-0.8, marginTop:12, lineHeight:1.1 }}>
        Pick a name<br/>others will see
      </div>
      <div style={{ fontFamily:F_SANS, fontSize:15, color:ui.muted,
        marginTop:12, lineHeight:1.45 }}>
        This is what appears on the map and the leaderboard.
        You can change it later.
      </div>

      {/* input */}
      <div style={{ marginTop:36 }}>
        <div style={{ fontFamily:F_MONO, fontSize:11, fontWeight:600,
          color:ui.muted, letterSpacing:1, textTransform:'uppercase' }}>Username</div>
        <div style={{ marginTop:10, height:56,
          borderBottom:`1.5px solid ${t.primary}`,
          display:'flex', alignItems:'center', gap:10 }}>
          <span style={{ fontFamily:F_SANS, fontSize:22, color:ui.dim }}>@</span>
          <span style={{ fontFamily:F_SANS, fontSize:22, color:ui.text,
            fontWeight:500, letterSpacing:-0.4 }}>yusif</span>
          <span style={{ width:2, height:24, background:t.primary,
            animation:'none' }}/>
          <div style={{ marginLeft:'auto', fontFamily:F_MONO, fontSize:12,
            color:ui.muted }}>5 / 20</div>
        </div>
        <div style={{ marginTop:10, fontFamily:F_SANS, fontSize:13,
          color:'#4ECCA3', display:'flex', alignItems:'center', gap:6 }}>
          <span>✓</span> Available
        </div>
      </div>

      <div style={{ flex:1 }}/>

      {/* primary CTA */}
      <button style={{ height:54, borderRadius:27, border:'none', margin:'0 0 24px',
        background:t.primary, color:'#fff',
        fontFamily:F_SANS, fontSize:16, fontWeight:600, letterSpacing:-0.2 }}>
        Enter the map
      </button>
    </div>
  );
}


// ─── 5. MAP IDLE (main app) ─────────────────────────────────────────────
function MapIdle({ t, ui }) {
  return (
    <div style={{ height:'100%', background:ui.bg, position:'relative' }}>
      {/* full-bleed map */}
      <div style={{ position:'absolute', inset:0 }}>
        <MapBase palette={t.mapStyle} w={402} h={874}>
          {DEFAULT_TERRITORIES.map(tr => (
            <g key={tr.id}>
              <Territory color={tr.color} poly={tr.poly} viz={t.territoryViz}/>
              {tr.label && (
                <text x={tr.poly.split(' ')[0].split(',')[0]} y={tr.poly.split(' ')[0].split(',')[1]}
                  fill={tr.color} fontSize="10" fontFamily={F_MONO} fontWeight="600"
                  dy="-8" letterSpacing="1">{tr.label}</text>
              )}
            </g>
          ))}
          {/* your current position pulse */}
          <circle cx="200" cy="380" r="20" fill={t.primary} fillOpacity="0.18"/>
          <circle cx="200" cy="380" r="8" fill={t.primary} stroke="#fff" strokeWidth="2.5"/>
        </MapBase>
      </div>

      {/* top floating chrome */}
      <div style={{ position:'absolute', top:62, left:16, right:16,
        display:'flex', justifyContent:'space-between', alignItems:'flex-start' }}>
        <Pill ui={ui}>
          <div style={{ width:24, height:24, borderRadius:12, background:t.primary,
            display:'flex', alignItems:'center', justifyContent:'center',
            color:'#fff', fontFamily:F_SANS, fontSize:11, fontWeight:600 }}>Y</div>
          <span>yusif</span>
          <div style={{ width:0.5, height:14, background:ui.border, margin:'0 2px' }}/>
          <span style={{ fontFamily:F_MONO, color:ui.muted, fontSize:13 }}>1.42 km²</span>
        </Pill>
        <Pill ui={ui} style={{ padding:'10px 12px' }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke={ui.text} strokeWidth="1.5">
            <path d="M2 5h14M2 9h14M2 13h14"/>
          </svg>
        </Pill>
      </div>

      {/* mid-floating: territories nearby card */}
      <div style={{ position:'absolute', left:16, right:16, bottom:268,
        background:ui.surface, borderRadius:18, padding:'12px 14px',
        border:`0.5px solid ${ui.border}`,
        boxShadow:'0 8px 24px rgba(0,0,0,0.18)' }}>
        <div style={{ display:'flex', justifyContent:'space-between', alignItems:'center' }}>
          <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
            color:ui.muted, letterSpacing:1, textTransform:'uppercase' }}>Nearby runners</div>
          <div style={{ fontFamily:F_SANS, fontSize:12, color:t.primary, fontWeight:500 }}>See all</div>
        </div>
        <div style={{ display:'flex', gap:10, marginTop:10 }}>
          {[
            { c:'#E85D5D', n:'Kai',  d:'140 m' },
            { c:'#F2C94C', n:'Aysu', d:'320 m' },
            { c:'#9B7EDC', n:'Tom',  d:'480 m' },
          ].map(r => (
            <div key={r.n} style={{ flex:1, display:'flex', alignItems:'center', gap:8 }}>
              <Dot color={r.c} size={10}/>
              <div>
                <div style={{ fontFamily:F_SANS, fontSize:13, fontWeight:500, color:ui.text }}>{r.n}</div>
                <div style={{ fontFamily:F_MONO, fontSize:11, color:ui.muted }}>{r.d}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* primary CTA — start run */}
      <div style={{ position:'absolute', left:24, right:24, bottom:120,
        display:'flex', alignItems:'center', gap:12 }}>
        <button style={{ flex:1, height:64, borderRadius:32, border:'none',
          background:t.primary, color:'#fff',
          fontFamily:F_SANS, fontSize:17, fontWeight:600, letterSpacing:-0.3,
          display:'flex', alignItems:'center', justifyContent:'center', gap:10,
          boxShadow:`0 10px 30px ${t.primary}55` }}>
          <svg width="20" height="20" viewBox="0 0 20 20" fill="#fff">
            <path d="M6 4l11 6-11 6V4z"/>
          </svg>
          Start run
        </button>
        <button style={{ width:64, height:64, borderRadius:32, border:'none',
          background:ui.surface, border:`0.5px solid ${ui.border}`,
          display:'flex', alignItems:'center', justifyContent:'center',
          boxShadow:'0 8px 24px rgba(0,0,0,0.18)' }}>
          <svg width="22" height="22" viewBox="0 0 22 22" fill="none" stroke={ui.text} strokeWidth="1.6">
            <circle cx="11" cy="11" r="3.5"/>
            <path d="M11 1v3M11 18v3M21 11h-3M4 11H1M18.07 3.93l-2.12 2.12M6.05 15.95l-2.12 2.12M18.07 18.07l-2.12-2.12M6.05 6.05L3.93 3.93"/>
          </svg>
        </button>
      </div>

      <TabBar active="map" t={t} ui={ui} floating/>
    </div>
  );
}


// ─── 6. ACTIVE RUN ──────────────────────────────────────────────────────
function ActiveRun({ t, ui }) {
  // Trail is a partial open polyline being drawn from a starting point
  const trail = '120,580 130,540 150,500 180,470 220,460 260,450 295,440 320,430 340,400';
  return (
    <div style={{ height:'100%', background:ui.bg, position:'relative' }}>
      <div style={{ position:'absolute', inset:0 }}>
        <MapBase palette={t.mapStyle} w={402} h={874}>
          {/* dimmed other territories */}
          {DEFAULT_TERRITORIES.filter(x => x.id !== 'you').map(tr => (
            <Territory key={tr.id} color={tr.color} poly={tr.poly}
              viz={t.territoryViz} opacity={0.35}/>
          ))}
          <Territory color={t.primary} poly={DEFAULT_TERRITORIES[0].poly}
            viz={t.territoryViz} opacity={0.7}/>

          {/* in-progress trail */}
          <polyline points={trail} fill="none" stroke={t.primary} strokeWidth="5"
            strokeLinecap="round" strokeLinejoin="round"
            style={{ filter:`drop-shadow(0 0 6px ${t.primary})` }}/>
          {/* ghost dashed return path showing closure */}
          <line x1="340" y1="400" x2="120" y2="580" stroke={t.primary}
            strokeWidth="2" strokeDasharray="3 6" opacity="0.5"/>

          <circle cx="340" cy="400" r="14" fill={t.primary} fillOpacity="0.25"/>
          <circle cx="340" cy="400" r="7" fill={t.primary} stroke="#fff" strokeWidth="2.5"/>
        </MapBase>
      </div>

      {/* top stats pill */}
      <div style={{ position:'absolute', top:62, left:16, right:16 }}>
        <div style={{ background:ui.surface, borderRadius:22,
          border:`0.5px solid ${ui.border}`, padding:'14px 18px',
          display:'flex', justifyContent:'space-between',
          boxShadow:'0 8px 24px rgba(0,0,0,0.18)' }}>
          <StatBlock k="Time"     v="12:48"  ui={ui}/>
          <StatBlock k="Distance" v="2.4 km" ui={ui}/>
          <StatBlock k="Area"     v="0.32"   ui={ui}/>
        </div>
        <div style={{ marginTop:10, display:'flex', justifyContent:'center' }}>
          <Pill ui={ui} style={{ padding:'6px 12px', fontSize:12, fontWeight:500 }}>
            <Dot color={t.primary}/>
            <span style={{ color:ui.muted }}>Loops are claimed automatically</span>
          </Pill>
        </div>
      </div>

      {/* Spotify now-playing — runs in parallel with the run */}
      <div style={{ position:'absolute', left:16, right:16, bottom:144 }}>
        <SpotifyBar t={t} ui={ui}/>
      </div>

      {/* bottom controls — stop (big red) + pause */}
      <div style={{ position:'absolute', left:24, right:24, bottom:64,
        display:'flex', alignItems:'center', gap:14, justifyContent:'center' }}>
        <button style={{ width:64, height:64, borderRadius:32, border:'none',
          background:ui.surface, border:`0.5px solid ${ui.border}`,
          display:'flex', alignItems:'center', justifyContent:'center',
          boxShadow:'0 8px 24px rgba(0,0,0,0.18)' }}>
          <svg width="20" height="20" viewBox="0 0 20 20" fill={ui.text}>
            <rect x="5" y="4" width="3.5" height="12"/>
            <rect x="11.5" y="4" width="3.5" height="12"/>
          </svg>
        </button>
        <button style={{ flex:1, height:64, borderRadius:32, border:'none',
          background:'#E85D5D', color:'#fff',
          fontFamily:F_SANS, fontSize:17, fontWeight:600, letterSpacing:-0.3,
          display:'flex', alignItems:'center', justifyContent:'center', gap:10,
          boxShadow:'0 10px 30px rgba(232,93,93,0.45)' }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="#fff">
            <rect x="3" y="3" width="10" height="10" rx="1"/>
          </svg>
          Finish run
        </button>
      </div>
    </div>
  );
}


// ─── 7. TERRITORY COMPLETE ──────────────────────────────────────────────
function Claimed({ t, ui }) {
  // small map preview at top showing newly claimed shape glowing
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex',
      flexDirection:'column' }}>
      {/* dimmed mini map */}
      <div style={{ height:340, position:'relative', overflow:'hidden' }}>
        <MapBase palette={t.mapStyle} w={402} h={340}>
          <Territory color={t.primary}
            poly="80,80 220,60 320,140 290,260 150,290 60,200"
            viz="glow"/>
        </MapBase>
        <div style={{ position:'absolute', inset:0,
          background:`linear-gradient(180deg, transparent 0%, ${ui.bg} 95%)` }}/>
      </div>

      {/* content */}
      <div style={{ flex:1, padding:'20px 28px 0', textAlign:'center' }}>
        <div style={{ fontFamily:F_MONO, fontSize:11, fontWeight:600,
          color:t.primary, letterSpacing:1.2, textTransform:'uppercase' }}>
          Territory claimed
        </div>
        <div style={{ marginTop:16, fontFamily:F_SANS, fontSize:72,
          fontWeight:600, color:ui.text, letterSpacing:-2.5, lineHeight:1 }}>
          +0.42
        </div>
        <div style={{ marginTop:6, fontFamily:F_MONO, fontSize:13,
          color:ui.muted, letterSpacing:0.5 }}>km² added to your map</div>

        {/* stats row */}
        <div style={{ marginTop:36, display:'flex', justifyContent:'space-between',
          padding:'18px 4px',
          borderTop:`0.5px solid ${ui.border}`,
          borderBottom:`0.5px solid ${ui.border}` }}>
          <StatBlock k="Time"     v="18:32"  ui={ui} align="left"/>
          <StatBlock k="Distance" v="3.6 km" ui={ui} align="center"/>
          <StatBlock k="Pace"     v="5:09"   ui={ui} align="right"/>
        </div>

        <div style={{ marginTop:18, fontFamily:F_SANS, fontSize:13,
          color:ui.muted, lineHeight:1.5 }}>
          You overlapped <b style={{ color:'#E85D5D' }}>● Kai's</b> territory.
          Their area shrank by 0.08 km².
        </div>
      </div>

      {/* CTAs */}
      <div style={{ padding:'20px 24px 56px', display:'flex', flexDirection:'column', gap:10 }}>
        <button style={{ height:54, borderRadius:27, border:'none',
          background:t.primary, color:'#fff',
          fontFamily:F_SANS, fontSize:16, fontWeight:600, letterSpacing:-0.2 }}>
          Save &amp; share
        </button>
        <button style={{ height:54, borderRadius:27,
          border:`0.5px solid ${ui.border}`, background:'transparent', color:ui.text,
          fontFamily:F_SANS, fontSize:16, fontWeight:500 }}>
          Back to map
        </button>
      </div>
    </div>
  );
}


// ─── 8. LEADERBOARD ─────────────────────────────────────────────────────
function Leaderboard({ t, ui }) {
  const rows = [
    { rank:1, n:'Kai',     km:'4.82', c:'#E85D5D', delta:'+0.18' },
    { rank:2, n:'Aysu',    km:'3.91', c:'#F2C94C', delta:'+0.04' },
    { rank:3, n:'Tom',     km:'2.50', c:'#9B7EDC', delta:'−0.12' },
    { rank:4, n:'yusif',   km:'1.42', c:t.primary, delta:'+0.42', you:true },
    { rank:5, n:'Lena',    km:'1.08', c:'#4ECCA3', delta:'+0.02' },
    { rank:6, n:'Diaz',    km:'0.92', c:'#FF9F4A', delta:'0' },
    { rank:7, n:'Sara',    km:'0.71', c:'#5BCEFA', delta:'+0.11' },
    { rank:8, n:'Ravi',    km:'0.55', c:'#F286D8', delta:'−0.03' },
  ];
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      {/* header */}
      <div style={{ padding:'70px 24px 16px' }}>
        <div style={{ fontFamily:F_MONO, fontSize:11, fontWeight:600,
          color:ui.muted, letterSpacing:1.2, textTransform:'uppercase' }}>This week</div>
        <div style={{ fontFamily:F_SANS, fontSize:34, fontWeight:600,
          color:ui.text, letterSpacing:-1, marginTop:4 }}>Leaderboard</div>
      </div>

      {/* tabs */}
      <div style={{ padding:'0 16px 12px' }}>
        <div style={{ display:'flex', background:ui.surface, borderRadius:12,
          padding:3, border:`0.5px solid ${ui.border}` }}>
          {['Weekly', 'All-time', 'Friends'].map((tab, i) => (
            <div key={tab} style={{ flex:1, height:34, display:'flex',
              alignItems:'center', justifyContent:'center', borderRadius:10,
              background: i === 0 ? ui.surfaceAlt : 'transparent',
              fontFamily:F_SANS, fontSize:13, fontWeight: i===0?600:500,
              color: i===0 ? ui.text : ui.muted,
              boxShadow: i===0 ? '0 1px 2px rgba(0,0,0,0.10)' : 'none' }}>
              {tab}
            </div>
          ))}
        </div>
      </div>

      {/* list */}
      <div style={{ flex:1, overflow:'auto', padding:'4px 16px 110px' }}>
        {rows.map(r => (
          <div key={r.rank} style={{
            display:'flex', alignItems:'center', gap:14,
            padding:'14px 12px', borderRadius:14,
            background: r.you ? `${t.primary}14` : 'transparent',
            border: r.you ? `0.5px solid ${t.primary}40` : '0.5px solid transparent',
            marginBottom:4 }}>
            <div style={{ width:24, fontFamily:F_MONO, fontSize:13,
              fontWeight:600, color: r.rank<=3 ? ui.text : ui.muted,
              textAlign:'center' }}>{r.rank}</div>
            <div style={{ width:36, height:36, borderRadius:18,
              background:r.c, display:'flex', alignItems:'center', justifyContent:'center',
              color:'#fff', fontFamily:F_SANS, fontSize:14, fontWeight:600 }}>
              {r.n[0].toUpperCase()}
            </div>
            <div style={{ flex:1 }}>
              <div style={{ fontFamily:F_SANS, fontSize:15, fontWeight:500,
                color:ui.text }}>{r.n}{r.you && <span style={{ color:ui.muted, fontWeight:400 }}> · you</span>}</div>
              {/* progress bar */}
              <div style={{ marginTop:6, height:3, borderRadius:2,
                background:ui.border, overflow:'hidden' }}>
                <div style={{ width: `${(parseFloat(r.km)/4.82)*100}%`,
                  height:'100%', background:r.c }}/>
              </div>
            </div>
            <div style={{ textAlign:'right' }}>
              <div style={{ fontFamily:F_MONO, fontSize:14, fontWeight:600,
                color:ui.text }}>{r.km}</div>
              <div style={{ fontFamily:F_MONO, fontSize:11,
                color: r.delta.startsWith('−') ? '#E85D5D' :
                       r.delta.startsWith('+') ? '#4ECCA3' : ui.dim }}>{r.delta}</div>
            </div>
          </div>
        ))}
      </div>

      <TabBar active="board" t={t} ui={ui}/>
    </div>
  );
}


// ─── 9. NOTIFICATIONS ───────────────────────────────────────────────────
function Notifications({ t, ui }) {
  const items = [
    { who:'Kai',  c:'#E85D5D', what:'took 0.12 km² of your territory', when:'2m', area:'Park east' },
    { who:'Aysu', c:'#F2C94C', what:'crossed your border', when:'18m', area:'Riverside' },
    { who:null,           c:t.primary,  what:'You claimed +0.42 km²', when:'1h', area:'City center', self:true },
    { who:'Tom',  c:'#9B7EDC', what:'is running near your area', when:'3h', area:'West blocks' },
    { who:'Lena', c:'#4ECCA3', what:'overtook you on the weekly board', when:'Yesterday' },
    { who:null,           c:t.primary,  what:'Your weekly summary is ready', when:'Yesterday', self:true },
  ];
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <div style={{ padding:'70px 24px 16px' }}>
        <div style={{ fontFamily:F_SANS, fontSize:34, fontWeight:600,
          color:ui.text, letterSpacing:-1 }}>Activity</div>
      </div>

      <div style={{ padding:'0 24px 8px', fontFamily:F_MONO, fontSize:10,
        fontWeight:600, color:ui.muted, letterSpacing:1.2, textTransform:'uppercase' }}>Today</div>

      <div style={{ flex:1, overflow:'auto', paddingBottom:110 }}>
        {items.map((it, i) => (
          <React.Fragment key={i}>
            {i === 4 && (
              <div style={{ padding:'14px 24px 8px', fontFamily:F_MONO, fontSize:10,
                fontWeight:600, color:ui.muted, letterSpacing:1.2,
                textTransform:'uppercase' }}>Earlier</div>
            )}
            <div style={{ padding:'14px 24px', display:'flex', gap:14,
              borderBottom:`0.5px solid ${ui.border}` }}>
              {/* avatar / dot */}
              {it.self ? (
                <div style={{ width:38, height:38, borderRadius:19,
                  background:'transparent', border:`1.5px solid ${it.c}`,
                  display:'flex', alignItems:'center', justifyContent:'center' }}>
                  <Mark size={18} color={it.c}/>
                </div>
              ) : (
                <div style={{ width:38, height:38, borderRadius:19, background:it.c,
                  display:'flex', alignItems:'center', justifyContent:'center',
                  color:'#fff', fontFamily:F_SANS, fontSize:15, fontWeight:600 }}>
                  {it.who[0]}
                </div>
              )}
              <div style={{ flex:1 }}>
                <div style={{ fontFamily:F_SANS, fontSize:15, color:ui.text,
                  lineHeight:1.35 }}>
                  {it.who && <b style={{ fontWeight:600 }}>{it.who} </b>}
                  <span style={{ color: it.self ? ui.text : ui.muted }}>{it.what}</span>
                </div>
                {it.area && (
                  <div style={{ marginTop:4, fontFamily:F_MONO, fontSize:11,
                    color:ui.dim, letterSpacing:0.4 }}>{it.area}</div>
                )}
              </div>
              <div style={{ fontFamily:F_MONO, fontSize:11, color:ui.dim,
                paddingTop:4 }}>{it.when}</div>
            </div>
          </React.Fragment>
        ))}
      </div>

      <TabBar active="activity" t={t} ui={ui}/>
    </div>
  );
}


// ─── 10. PROFILE ────────────────────────────────────────────────────────
function Profile({ t, ui }) {
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column', overflow:'auto' }}>
      {/* hero with mini map of own territory */}
      <div style={{ position:'relative', paddingTop:62 }}>
        <div style={{ position:'absolute', top:0, left:0, right:0, height:260,
          overflow:'hidden', opacity:0.7 }}>
          <MapBase palette={t.mapStyle} w={402} h={260}>
            <Territory color={t.primary}
              poly="80,80 220,60 320,140 290,220 150,250 60,180"
              viz={t.territoryViz}/>
          </MapBase>
          <div style={{ position:'absolute', inset:0,
            background:`linear-gradient(180deg, transparent 30%, ${ui.bg} 100%)` }}/>
        </div>

        <div style={{ position:'relative', padding:'24px 24px 0',
          display:'flex', alignItems:'center', gap:14 }}>
          <div style={{ width:64, height:64, borderRadius:32, background:t.primary,
            display:'flex', alignItems:'center', justifyContent:'center',
            color:'#fff', fontFamily:F_SANS, fontSize:24, fontWeight:600,
            border:`3px solid ${ui.bg}`,
            boxShadow:'0 8px 24px rgba(0,0,0,0.18)' }}>Y</div>
          <div>
            <div style={{ fontFamily:F_SANS, fontSize:22, fontWeight:600,
              color:ui.text, letterSpacing:-0.5 }}>yusif</div>
            <div style={{ fontFamily:F_MONO, fontSize:12, color:ui.muted,
              letterSpacing:0.5, marginTop:2 }}>RANK · 4TH IN CITY</div>
          </div>
        </div>
      </div>

      {/* stats grid */}
      <div style={{ padding:'24px 24px 0' }}>
        <div style={{ background:ui.surface, borderRadius:18,
          border:`0.5px solid ${ui.border}`, padding:'18px 4px',
          display:'flex' }}>
          <div style={{ flex:1, textAlign:'center',
            borderRight:`0.5px solid ${ui.border}` }}>
            <StatBlock k="Total km²" v="1.42" ui={ui} align="center"/>
          </div>
          <div style={{ flex:1, textAlign:'center',
            borderRight:`0.5px solid ${ui.border}` }}>
            <StatBlock k="Runs" v="48" ui={ui} align="center"/>
          </div>
          <div style={{ flex:1, textAlign:'center' }}>
            <StatBlock k="Streak" v="12" ui={ui} align="center"/>
          </div>
        </div>
      </div>

      {/* achievements */}
      <div style={{ padding:'24px 24px 0' }}>
        <div style={{ display:'flex', justifyContent:'space-between',
          alignItems:'baseline', marginBottom:12 }}>
          <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
            color:ui.muted, letterSpacing:1.2, textTransform:'uppercase' }}>Achievements</div>
          <div style={{ fontFamily:F_SANS, fontSize:12, color:t.primary, fontWeight:500 }}>5 of 24</div>
        </div>
        <div style={{ display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:10 }}>
          {[
            { e:'△', n:'First loop' },
            { e:'◇', n:'10 km²' },
            { e:'○', n:'Night run' },
            { e:'☆', n:'Invader' },
            { e:'◆', n:'7-day' },
            { e:'?', n:'Locked', l:true },
            { e:'?', n:'Locked', l:true },
            { e:'?', n:'Locked', l:true },
          ].map((a, i) => (
            <div key={i} style={{ aspectRatio:'1/1', borderRadius:14,
              background: a.l ? 'transparent' : ui.surface,
              border:`0.5px solid ${ui.border}`,
              display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center',
              opacity: a.l ? 0.4 : 1 }}>
              <div style={{ fontFamily:F_SANS, fontSize:22,
                color: a.l ? ui.dim : t.primary, fontWeight:500 }}>{a.e}</div>
              <div style={{ fontFamily:F_MONO, fontSize:9, color:ui.muted,
                marginTop:4, letterSpacing:0.4, textTransform:'uppercase' }}>{a.n}</div>
            </div>
          ))}
        </div>
      </div>

      <div style={{ height:110, flexShrink:0 }}/>
      <TabBar active="profile" t={t} ui={ui}/>
    </div>
  );
}


// ─── 11. STATS ──────────────────────────────────────────────────────────
function Stats({ t, ui }) {
  const days = [
    { d:'M', v:0.18 }, { d:'T', v:0.42 }, { d:'W', v:0.08 },
    { d:'T', v:0.31 }, { d:'F', v:0.00 }, { d:'S', v:0.55, today:true },
    { d:'S', v:0.00 },
  ];
  const max = 0.6;
  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <div style={{ padding:'70px 24px 16px' }}>
        <div style={{ fontFamily:F_MONO, fontSize:11, fontWeight:600,
          color:ui.muted, letterSpacing:1.2, textTransform:'uppercase' }}>This week</div>
        <div style={{ fontFamily:F_SANS, fontSize:34, fontWeight:600,
          color:ui.text, letterSpacing:-1, marginTop:4 }}>Stats</div>
      </div>

      {/* big numbers */}
      <div style={{ padding:'0 24px 8px' }}>
        <div style={{ display:'flex', alignItems:'baseline', gap:8 }}>
          <div style={{ fontFamily:F_SANS, fontSize:64, fontWeight:600,
            color:ui.text, letterSpacing:-2.2, lineHeight:1 }}>1.54</div>
          <div style={{ fontFamily:F_MONO, fontSize:14, color:ui.muted }}>km²</div>
        </div>
        <div style={{ marginTop:6, fontFamily:F_SANS, fontSize:13,
          color:ui.muted }}>
          <span style={{ color:'#4ECCA3', fontWeight:500 }}>+0.42</span> vs last week
        </div>
      </div>

      {/* chart */}
      <div style={{ padding:'28px 24px 0' }}>
        <div style={{ display:'flex', alignItems:'flex-end', gap:10, height:140 }}>
          {days.map((d, i) => (
            <div key={i} style={{ flex:1, display:'flex', flexDirection:'column',
              alignItems:'center', gap:8 }}>
              <div style={{ flex:1, width:'100%', display:'flex',
                alignItems:'flex-end' }}>
                <div style={{ width:'100%',
                  height: `${(d.v/max)*100}%`,
                  background: d.today ? t.primary : (d.v ? `${t.primary}55` : ui.border),
                  borderRadius: 6,
                  minHeight: d.v ? 4 : 2 }}/>
              </div>
              <div style={{ fontFamily:F_MONO, fontSize:11,
                color: d.today ? ui.text : ui.dim,
                fontWeight: d.today ? 600 : 500 }}>{d.d}</div>
            </div>
          ))}
        </div>
      </div>

      {/* recent runs */}
      <div style={{ padding:'32px 24px 0', flex:1, overflow:'auto' }}>
        <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
          color:ui.muted, letterSpacing:1.2, textTransform:'uppercase',
          marginBottom:10 }}>Recent runs</div>
        {[
          { date:'Today',     dist:'3.6 km', area:'+0.42', time:'18:32' },
          { date:'Wed',       dist:'1.2 km', area:'+0.08', time:'8:14' },
          { date:'Tue',       dist:'4.1 km', area:'+0.31', time:'24:01' },
          { date:'Mon',       dist:'2.0 km', area:'+0.18', time:'13:25' },
        ].map((r, i) => (
          <div key={i} style={{ display:'flex', alignItems:'center',
            padding:'14px 0',
            borderBottom: i<3 ? `0.5px solid ${ui.border}` : 'none' }}>
            <div style={{ flex:1 }}>
              <div style={{ fontFamily:F_SANS, fontSize:15, fontWeight:500,
                color:ui.text }}>{r.date}</div>
              <div style={{ fontFamily:F_MONO, fontSize:12, color:ui.muted,
                marginTop:2 }}>{r.dist} · {r.time}</div>
            </div>
            <div style={{ fontFamily:F_MONO, fontSize:15, fontWeight:600,
              color:t.primary }}>{r.area} km²</div>
          </div>
        ))}
      </div>
    </div>
  );
}


// ─── 12. SETTINGS ───────────────────────────────────────────────────────
function Settings({ t, ui }) {
  const Section = ({ title, children }) => (
    <div style={{ marginBottom:24 }}>
      <div style={{ padding:'0 32px 6px', fontFamily:F_MONO, fontSize:10,
        fontWeight:600, color:ui.muted, letterSpacing:1.2, textTransform:'uppercase' }}>
        {title}
      </div>
      <div style={{ margin:'0 16px', background:ui.surface, borderRadius:18,
        border:`0.5px solid ${ui.border}`, overflow:'hidden' }}>{children}</div>
    </div>
  );

  const Row = ({ label, value, toggle, last, danger }) => (
    <div style={{ display:'flex', alignItems:'center', minHeight:52,
      padding:'0 16px',
      borderBottom: last ? 'none' : `0.5px solid ${ui.border}` }}>
      <div style={{ flex:1, fontFamily:F_SANS, fontSize:15,
        color: danger ? '#E85D5D' : ui.text }}>{label}</div>
      {value && <div style={{ fontFamily:F_SANS, fontSize:14, color:ui.muted,
        marginRight:6 }}>{value}</div>}
      {toggle !== undefined && (
        <div style={{ width:42, height:25, borderRadius:13,
          background: toggle ? t.primary : ui.border, position:'relative',
          transition:'background .2s' }}>
          <div style={{ position:'absolute', top:2, left: toggle ? 19 : 2,
            width:21, height:21, borderRadius:11, background:'#fff',
            boxShadow:'0 1px 3px rgba(0,0,0,0.18)' }}/>
        </div>
      )}
      {!toggle && value === undefined && !danger && (
        <svg width="6" height="10" viewBox="0 0 6 10" fill="none">
          <path d="M1 1l4 4-4 4" stroke={ui.dim} strokeWidth="1.5" strokeLinecap="round"/>
        </svg>
      )}
    </div>
  );

  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <div style={{ padding:'70px 24px 24px' }}>
        <div style={{ fontFamily:F_SANS, fontSize:34, fontWeight:600,
          color:ui.text, letterSpacing:-1 }}>Settings</div>
      </div>

      <div style={{ flex:1, overflow:'auto', paddingBottom:40 }}>
        <Section title="Account">
          <Row label="Signed in as" value="yusif@gmail.com"/>
          <Row label="Username" value="@yusif"/>
          <Row label="Team color" value="● Blue" last/>
        </Section>

        <Section title="Map &amp; Privacy">
          <Row label="Show me on the map" toggle={true}/>
          <Row label="Public profile" toggle={true}/>
          <Row label="Background tracking" toggle={false}/>
          <Row label="Map style" value="Monochrome" last/>
        </Section>

        <Section title="Notifications">
          <Row label="Someone takes my area" toggle={true}/>
          <Row label="Runner enters my area" toggle={true}/>
          <Row label="Weekly summary" toggle={false} last/>
        </Section>

        <Section title="">
          <Row label="Help &amp; support"/>
          <Row label="Terms"/>
          <Row label="Sign out" danger last/>
        </Section>

        <div style={{ textAlign:'center', fontFamily:F_MONO, fontSize:11,
          color:ui.dim, paddingTop:8 }}>RunClaim · v1.0.0</div>
      </div>
    </div>
  );
}


Object.assign(window, {
  Splash, Onboarding, Login, Username, MapIdle, ActiveRun,
  Claimed, Leaderboard, Notifications, Profile, Stats, Settings, UI,
});
