// system.jsx — iOS system-level surfaces for the running Live Activity:
//   • LockScreen          — full lock screen with Live Activity card
//   • SpringboardCompact  — Home screen showing the Dynamic Island pill
//   • DynamicIslandExpanded — long-press expanded view over home screen
// All three use the SAME source data so they read as one moment in time.

// Mini map fragment, used in lock screen + expanded island.
function LiveMiniMap({ palette, primary, viz, w, h, trail = '60,80 100,60 160,52 220,56 280,60 320,70' }) {
  return (
    <MapBase palette={palette} w={w} h={h}>
      <Territory color={primary} poly="40,40 200,30 310,60 290,110 110,120 30,90"
        viz={viz} opacity={0.55}/>
      <polyline points={trail} fill="none" stroke={primary} strokeWidth="4.5"
        strokeLinecap="round" strokeLinejoin="round"
        style={{ filter: `drop-shadow(0 0 5px ${primary})` }}/>
      <circle cx="320" cy="70" r="12" fill={primary} fillOpacity="0.3"/>
      <circle cx="320" cy="70" r="5" fill={primary} stroke="#fff" strokeWidth="2"/>
    </MapBase>
  );
}


// ─── A. LOCK SCREEN with Live Activity ──────────────────────────────────
function LockScreen({ t, ui }) {
  const C = MAP_PALETTES[t.mapStyle] || MAP_PALETTES.dark;
  return (
    <div style={{ height:'100%', background:'#000', position:'relative',
      display:'flex', flexDirection:'column', overflow:'hidden' }}>
      {/* subtle wallpaper */}
      <div style={{ position:'absolute', inset:0,
        background:`radial-gradient(120% 80% at 30% 18%, ${t.primary}33 0%, rgba(15,15,25,0.95) 50%, #000 100%)` }}/>

      {/* time + date — top */}
      <div style={{ position:'relative', paddingTop:74, textAlign:'center' }}>
        <svg width="14" height="18" viewBox="0 0 14 18" style={{ opacity:0.85 }}>
          <rect x="1" y="8.5" width="12" height="8.5" rx="2" fill="#fff"/>
          <path d="M3.5 8.5V5a3.5 3.5 0 017 0v3.5" stroke="#fff" strokeWidth="1.4" fill="none"/>
        </svg>
        <div style={{ marginTop:18, fontFamily: F_SANS, fontSize:18,
          color:'#fff', opacity:0.85, fontWeight:500 }}>
          Monday, May 25
        </div>
        <div style={{ marginTop:-4, fontFamily:'-apple-system, "SF Pro Display", system-ui',
          fontSize:96, fontWeight:200, color:'#fff',
          letterSpacing:-3, lineHeight:1 }}>9:41</div>
      </div>

      {/* Live Activity card */}
      <div style={{ position:'relative', flex:1, padding:'36px 12px 0' }}>
        <div style={{
          background:'rgba(20,20,22,0.68)',
          backdropFilter:'blur(24px) saturate(180%)',
          WebkitBackdropFilter:'blur(24px) saturate(180%)',
          borderRadius:26, padding:'14px 14px 12px',
          border:'0.5px solid rgba(255,255,255,0.08)',
          boxShadow:'0 1px 0 rgba(255,255,255,0.05) inset, 0 20px 60px rgba(0,0,0,0.5)',
        }}>
          {/* header */}
          <div style={{ display:'flex', alignItems:'center', gap:10 }}>
            <div style={{ width:30, height:30, borderRadius:8,
              background:t.primary, display:'flex', alignItems:'center', justifyContent:'center' }}>
              <Mark size={18} color="#fff"/>
            </div>
            <div style={{ flex:1 }}>
              <div style={{ fontFamily:F_SANS, fontSize:13, fontWeight:600, color:'#fff' }}>
                RunClaim
              </div>
              <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
                color:'rgba(255,255,255,0.55)', letterSpacing:1, textTransform:'uppercase', marginTop:1 }}>
                Tracking · loop open
              </div>
            </div>
            {/* red live dot */}
            <div style={{ display:'flex', alignItems:'center', gap:5,
              padding:'4px 8px', borderRadius:999,
              background:'rgba(232,93,93,0.18)' }}>
              <div style={{ width:6, height:6, borderRadius:3, background:'#E85D5D' }}/>
              <span style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
                color:'#E85D5D', letterSpacing:1 }}>LIVE</span>
            </div>
          </div>

          {/* numbers */}
          <div style={{ marginTop:14, display:'flex', alignItems:'flex-end',
            justifyContent:'space-between' }}>
            <div>
              <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
                color:'rgba(255,255,255,0.5)', letterSpacing:1, textTransform:'uppercase' }}>Distance</div>
              <div style={{ fontFamily:F_SANS, fontSize:38, fontWeight:600,
                color:'#fff', letterSpacing:-1.2, lineHeight:1, marginTop:2 }}>
                2.4<span style={{ fontFamily:F_MONO, fontSize:13,
                  color:'rgba(255,255,255,0.5)', marginLeft:4 }}>km</span>
              </div>
            </div>
            <div style={{ textAlign:'right' }}>
              <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
                color:'rgba(255,255,255,0.5)', letterSpacing:1, textTransform:'uppercase' }}>Time</div>
              <div style={{ fontFamily:F_MONO, fontSize:24, fontWeight:600,
                color:'#fff', letterSpacing:-0.5, lineHeight:1, marginTop:5 }}>12:48</div>
            </div>
            <div style={{ textAlign:'right' }}>
              <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
                color:'rgba(255,255,255,0.5)', letterSpacing:1, textTransform:'uppercase' }}>Area</div>
              <div style={{ fontFamily:F_MONO, fontSize:24, fontWeight:600,
                color:t.primary, letterSpacing:-0.5, lineHeight:1, marginTop:5 }}>0.32</div>
            </div>
          </div>

          {/* mini map */}
          <div style={{ marginTop:14, borderRadius:16, overflow:'hidden', height:120 }}>
            <LiveMiniMap palette={t.mapStyle} primary={t.primary} viz={t.territoryViz} w={354} h={120}/>
          </div>

          {/* hint row */}
          <div style={{ marginTop:10, display:'flex', alignItems:'center',
            gap:8, padding:'2px 4px' }}>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke={t.primary} strokeWidth="1.5">
              <circle cx="6" cy="6" r="4.5"/>
              <path d="M6 3.5v2.8l1.8 1"/>
            </svg>
            <div style={{ flex:1, fontFamily:F_SANS, fontSize:12,
              color:'rgba(255,255,255,0.7)' }}>
              Close the loop to claim <b style={{ color:'#fff' }}>+0.32 km²</b>
            </div>
          </div>
        </div>
      </div>

      {/* bottom: flashlight + camera */}
      <div style={{ position:'relative', padding:'0 36px 32px',
        display:'flex', justifyContent:'space-between' }}>
        {[
          <path key="f" d="M9 1l-2 5h3l-3 8 2-6H6l3-7z" fill="#fff"/>,
          <g key="c"><rect x="1.5" y="4.5" width="13" height="9" rx="2" stroke="#fff" strokeWidth="1.4" fill="none"/><circle cx="8" cy="9" r="2.5" stroke="#fff" strokeWidth="1.4" fill="none"/></g>
        ].map((svg, i) => (
          <div key={i} style={{ width:46, height:46, borderRadius:23,
            background:'rgba(80,80,80,0.5)',
            backdropFilter:'blur(16px)', WebkitBackdropFilter:'blur(16px)',
            display:'flex', alignItems:'center', justifyContent:'center' }}>
            <svg width="16" height="16" viewBox="0 0 16 16">{svg}</svg>
          </div>
        ))}
      </div>

      {/* status bar (white, atop wallpaper) */}
      <div style={{ position:'absolute', top:0, left:0, right:0, zIndex:5 }}>
        <IOSStatusBar dark={true}/>
      </div>
    </div>
  );
}


// ─── B. SPRINGBOARD with Dynamic Island compact ─────────────────────────
function SpringboardLive({ t, ui }) {
  return (
    <SpringboardBase t={t}>
      {/* Dynamic Island — compact, split */}
      <DynamicIslandCompact t={t}/>
    </SpringboardBase>
  );
}


// ─── C. Dynamic Island expanded (long-press) ────────────────────────────
function IslandExpanded({ t, ui }) {
  return (
    <SpringboardBase t={t} dim>
      <div style={{ position:'absolute', top:11, left:'50%', transform:'translateX(-50%)',
        zIndex:60, width:374 }}>
        <div style={{
          background:'#0A0A0C', borderRadius:42, padding:'16px 18px 18px',
          border:'0.5px solid rgba(255,255,255,0.06)',
          boxShadow:'0 20px 60px rgba(0,0,0,0.6), 0 4px 14px rgba(0,0,0,0.35)',
        }}>
          {/* top row: app + LIVE */}
          <div style={{ display:'flex', alignItems:'center', gap:10,
            padding:'8px 8px 14px' }}>
            <div style={{ width:34, height:34, borderRadius:10,
              background:t.primary, display:'flex', alignItems:'center', justifyContent:'center' }}>
              <Mark size={20} color="#fff"/>
            </div>
            <div style={{ flex:1 }}>
              <div style={{ fontFamily:F_SANS, fontSize:14, fontWeight:600, color:'#fff' }}>RunClaim</div>
              <div style={{ fontFamily:F_MONO, fontSize:11, color:'rgba(255,255,255,0.55)' }}>Loop in progress</div>
            </div>
            <div style={{ display:'flex', alignItems:'center', gap:5,
              padding:'4px 8px', borderRadius:999, background:'rgba(232,93,93,0.18)' }}>
              <div style={{ width:6, height:6, borderRadius:3, background:'#E85D5D' }}/>
              <span style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600,
                color:'#E85D5D', letterSpacing:1 }}>LIVE</span>
            </div>
          </div>

          {/* stats + map row */}
          <div style={{ display:'flex', gap:14, padding:'0 6px' }}>
            <div style={{ flex:1, display:'flex', flexDirection:'column', gap:14, justifyContent:'center' }}>
              {[
                { k:'Distance', v:'2.4 km',  c:'#fff' },
                { k:'Time',     v:'12:48',   c:'#fff' },
                { k:'Area',     v:'0.32 km²', c:t.primary },
              ].map(s => (
                <div key={s.k}>
                  <div style={{ fontFamily:F_MONO, fontSize:9, fontWeight:600,
                    color:'rgba(255,255,255,0.5)', letterSpacing:1, textTransform:'uppercase' }}>{s.k}</div>
                  <div style={{ fontFamily:F_MONO, fontSize:22, fontWeight:600,
                    color:s.c, letterSpacing:-0.5, lineHeight:1.05, marginTop:2 }}>{s.v}</div>
                </div>
              ))}
            </div>
            <div style={{ width:150, height:150, borderRadius:18, overflow:'hidden' }}>
              <LiveMiniMap palette={t.mapStyle} primary={t.primary} viz={t.territoryViz}
                w={150} h={150}
                trail="30,110 50,80 80,55 120,40 145,55"/>
            </div>
          </div>

          {/* control buttons */}
          <div style={{ marginTop:16, display:'flex', gap:10 }}>
            <button style={{ flex:1, height:44, borderRadius:14, border:'none',
              background:'rgba(255,255,255,0.08)', color:'#fff',
              fontFamily:F_SANS, fontSize:14, fontWeight:600,
              display:'flex', alignItems:'center', justifyContent:'center', gap:8 }}>
              <svg width="12" height="12" viewBox="0 0 12 12" fill="#fff">
                <rect x="2" y="1.5" width="2.5" height="9"/>
                <rect x="7.5" y="1.5" width="2.5" height="9"/>
              </svg>
              Pause
            </button>
            <button style={{ flex:1, height:44, borderRadius:14, border:'none',
              background:'rgba(232,93,93,0.22)', color:'#E85D5D',
              fontFamily:F_SANS, fontSize:14, fontWeight:600,
              display:'flex', alignItems:'center', justifyContent:'center', gap:8 }}>
              <svg width="11" height="11" viewBox="0 0 11 11" fill="#E85D5D">
                <rect width="11" height="11" rx="1.5"/>
              </svg>
              Stop &amp; claim
            </button>
          </div>
        </div>
      </div>
    </SpringboardBase>
  );
}


// ─── Springboard base (iOS home screen behind island/expanded) ──────────
function SpringboardBase({ t, dim = false, children }) {
  const apps = [
    ['#FFB341', 'FaceTime'], ['#5BCEFA', 'Calendar'], ['#FFFFFF', 'Photos'],
    ['#2B2B2B', 'Camera'],   ['#FFD60A', 'Notes'],    ['#F2C94C', 'Reminders'],
    ['#34C759', 'Maps'],     ['#FF3B30', 'Weather'],

    ['#5856D6', 'Music'],    ['#1D1D1F', 'Calculator'], ['#0A84FF', 'iMessage'],
    ['#34C759', 'Phone'],    ['#FF6B6B', 'Health'],    ['#F2C94C', 'Wallet'],
    ['#FF9F4A', 'Files'],    [t.primary, 'RunClaim'],
  ];
  const dock = [
    ['#0A84FF', 'Safari'], ['#FF3B30', 'Mail'],
    ['#34C759', 'Phone'], ['#5856D6', 'Music'],
  ];
  return (
    <div style={{ height:'100%', background:'#000', position:'relative', overflow:'hidden' }}>
      {/* wallpaper */}
      <div style={{ position:'absolute', inset:0,
        background:`radial-gradient(120% 80% at 30% 20%, ${t.primary}28 0%, #0A0A18 40%, #000 100%)` }}/>
      {dim && <div style={{ position:'absolute', inset:0, background:'rgba(0,0,0,0.55)', backdropFilter:'blur(20px)' }}/>}

      {/* status bar — white because wallpaper is dark */}
      <div style={{ position:'absolute', top:0, left:0, right:0, zIndex:5 }}>
        <IOSStatusBar dark={true}/>
      </div>

      {/* app grid */}
      <div style={{ position:'absolute', top:88, left:0, right:0, bottom:140,
        padding:'0 22px', display:'flex', flexDirection:'column', gap:22 }}>
        {[0, 1, 2, 3].map(row => (
          <div key={row} style={{ display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:14 }}>
            {apps.slice(row*4, row*4+4).map(([c, n], i) => (
              <AppIcon key={i} color={c} name={n} primary={t.primary}/>
            ))}
          </div>
        ))}
      </div>

      {/* page dots */}
      <div style={{ position:'absolute', bottom:108, left:0, right:0,
        display:'flex', justifyContent:'center', gap:6 }}>
        {[0,1,2].map(i => (
          <div key={i} style={{ width:6, height:6, borderRadius:3,
            background: i === 0 ? '#fff' : 'rgba(255,255,255,0.4)' }}/>
        ))}
      </div>

      {/* dock */}
      <div style={{ position:'absolute', bottom:36, left:14, right:14, height:82,
        borderRadius:32, padding:'8px 14px',
        background:'rgba(255,255,255,0.18)',
        backdropFilter:'blur(20px)', WebkitBackdropFilter:'blur(20px)',
        border:'0.5px solid rgba(255,255,255,0.18)',
        display:'grid', gridTemplateColumns:'repeat(4,1fr)', gap:14, alignItems:'center' }}>
        {dock.map(([c, n], i) => (
          <AppIcon key={i} color={c} name={n} dock primary={t.primary}/>
        ))}
      </div>

      {children}
    </div>
  );
}

function AppIcon({ color, name, dock = false, primary }) {
  const isApp = name === 'RunClaim';
  return (
    <div style={{ display:'flex', flexDirection:'column', alignItems:'center', gap:6 }}>
      <div style={{ width:60, height:60, borderRadius:14,
        background: color,
        boxShadow:'0 2px 6px rgba(0,0,0,0.25)',
        display:'flex', alignItems:'center', justifyContent:'center',
        color:'#fff', fontFamily: F_SANS, fontSize:24, fontWeight:600,
        position:'relative', overflow:'hidden' }}>
        {isApp && <Mark size={36} color="#fff"/>}
        {!isApp && name === 'Music'   && '♪'}
        {!isApp && name === 'Maps'    && (
          <svg width="34" height="34" viewBox="0 0 34 34"><path d="M3 6l9-3 10 3 9-3v25l-9 3-10-3-9 3z" fill="#fff" opacity="0.95"/><circle cx="17" cy="17" r="3" fill="#FF3B30"/></svg>
        )}
        {!isApp && name === 'Camera'  && (
          <svg width="22" height="20" viewBox="0 0 22 20" fill="#fff"><circle cx="11" cy="11" r="5"/><path d="M7 2h8l2 3h3v13H1V5h4z" fillOpacity="0.001"/><rect width="22" height="16" y="4" rx="3" fill="none" stroke="#fff" strokeWidth="1.6"/></svg>
        )}
        {!isApp && !['Music','Maps','Camera'].includes(name) && (
          <span style={{ opacity:0.85, fontWeight:700 }}>{name[0]}</span>
        )}
      </div>
      {!dock && (
        <div style={{ fontFamily:F_SANS, fontSize:10.5, color:'#fff',
          textShadow:'0 1px 1px rgba(0,0,0,0.4)' }}>{name}</div>
      )}
    </div>
  );
}


// ─── Dynamic Island compact (single wider pill that morphs over the
// default island; leading app icon + trailing live stat) ────────────────
function DynamicIslandCompact({ t }) {
  return (
    <div style={{
      position:'absolute', top:11, left:'50%', transform:'translateX(-50%)',
      height:37, borderRadius:22, background:'#000',
      display:'flex', alignItems:'center',
      padding:'0 12px 0 6px',
      zIndex:60,
      boxShadow:'0 4px 12px rgba(0,0,0,0.4)',
    }}>
      {/* leading: app icon */}
      <div style={{ width:26, height:26, borderRadius:8,
        background:t.primary, display:'flex',
        alignItems:'center', justifyContent:'center', flexShrink:0 }}>
        <Mark size={16} color="#fff"/>
      </div>
      {/* visual gap where the camera cutout sits */}
      <div style={{ width:96 }}/>
      {/* trailing: live stat */}
      <div style={{ display:'flex', alignItems:'center', gap:6 }}>
        <div style={{ width:6, height:6, borderRadius:3, background:t.primary,
          boxShadow:`0 0 5px ${t.primary}` }}/>
        <span style={{ fontFamily:F_MONO, fontSize:13, fontWeight:600,
          color:'#fff', letterSpacing:-0.3 }}>2.4 km</span>
      </div>
    </div>
  );
}


// ─── D. In-app Live Activity (Messages app with persistent island) ──────
function InAppLive({ t, ui }) {
  // Shows another app open (Messages-like) with the Dynamic Island still
  // holding the run, so the user understands the run persists across apps.
  return (
    <div style={{ height:'100%', background:'#000', position:'relative', overflow:'hidden' }}>
      {/* in-app content: a generic messaging UI */}
      <div style={{ position:'absolute', inset:0, background:'#000', color:'#fff' }}>
        <div style={{ height:62 }}/>
        {/* nav bar */}
        <div style={{ padding:'52px 16px 16px', display:'flex', flexDirection:'column',
          alignItems:'center', borderBottom:'0.5px solid rgba(255,255,255,0.08)' }}>
          <div style={{ width:54, height:54, borderRadius:27, background:'#5856D6',
            display:'flex', alignItems:'center', justifyContent:'center',
            color:'#fff', fontFamily:F_SANS, fontSize:20, fontWeight:600 }}>K</div>
          <div style={{ fontFamily:F_SANS, fontSize:13, fontWeight:500, color:'#fff',
            marginTop:6 }}>Kai</div>
          <div style={{ fontFamily:F_SANS, fontSize:11, color:'rgba(255,255,255,0.45)' }}>iMessage</div>
        </div>

        {/* messages */}
        <div style={{ padding:'20px 14px', display:'flex', flexDirection:'column', gap:10 }}>
          <div style={{ textAlign:'center', fontFamily:F_SANS, fontSize:11,
            color:'rgba(255,255,255,0.45)', padding:'4px 0' }}>Today 9:38 AM</div>
          {[
            { side:'in',  text:"you running rn?" },
            { side:'out', text:"yeah, looping the park" },
            { side:'in',  text:"don't you DARE take my block" },
            { side:'out', text:"too late 😎" },
          ].map((m, i) => (
            <div key={i} style={{ display:'flex',
              justifyContent: m.side === 'out' ? 'flex-end' : 'flex-start' }}>
              <div style={{ maxWidth:'72%', padding:'9px 14px', borderRadius:18,
                background: m.side === 'out' ? t.primary : 'rgba(255,255,255,0.13)',
                color:'#fff', fontFamily:F_SANS, fontSize:15 }}>{m.text}</div>
            </div>
          ))}
        </div>
      </div>

      {/* status bar */}
      <div style={{ position:'absolute', top:0, left:0, right:0, zIndex:5 }}>
        <IOSStatusBar dark={true}/>
      </div>

      {/* Dynamic Island persistent compact */}
      <DynamicIslandCompact t={t}/>
    </div>
  );
}


Object.assign(window, {
  LockScreen, SpringboardLive, IslandExpanded, InAppLive,
  LiveMiniMap, DynamicIslandCompact,
});
