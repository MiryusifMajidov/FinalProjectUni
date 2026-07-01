// music.jsx — Minimal Spotify integration.
//   • SpotifyBar      — tiny now-playing strip shown during a run
//   • SpotifyConnect  — connect screen + pick one playlist (pre-run / settings)
// Real app: Spotify OAuth + Web Playback SDK. Here it's a faithful mock.

const SPOTIFY_GREEN = '#1DB954';

function SpotifyGlyph({ size = 16, color = '#fff' }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <path d="M12 2a10 10 0 100 20 10 10 0 000-20zm4.59 14.43a.62.62 0 01-.86.21c-2.35-1.44-5.3-1.76-8.79-.96a.62.62 0 11-.28-1.21c3.81-.87 7.08-.5 9.72 1.11.3.18.39.57.21.85zm1.22-2.72a.78.78 0 01-1.07.26c-2.69-1.65-6.79-2.13-9.97-1.17a.78.78 0 11-.45-1.49c3.63-1.1 8.15-.56 11.24 1.33.37.22.49.7.25 1.07zm.1-2.83C14.8 8.16 9.3 7.97 6.16 8.93a.93.93 0 11-.54-1.78c3.6-1.1 9.68-.88 13.49 1.38a.93.93 0 11-.95 1.6z"/>
    </svg>
  );
}

// ─── NOW-PLAYING BAR (lives on the run screen) ──────────────────────────
function SpotifyBar({ t, ui, style }) {
  return (
    <div style={{
      display:'flex', alignItems:'center', gap:12, padding:'9px 12px 9px 9px',
      borderRadius:18,
      background: t.dark ? 'rgba(23,23,27,0.82)' : 'rgba(255,255,255,0.88)',
      backdropFilter:'blur(20px) saturate(180%)', WebkitBackdropFilter:'blur(20px) saturate(180%)',
      border:`0.5px solid ${ui.border}`,
      boxShadow:'0 8px 24px rgba(0,0,0,0.18)',
      ...style,
    }}>
      {/* album art */}
      <div style={{ width:40, height:40, borderRadius:10, flexShrink:0,
        background:`linear-gradient(135deg, ${t.primary}, #7B5Cff)`, position:'relative',
        display:'flex', alignItems:'center', justifyContent:'center', overflow:'hidden' }}>
        <svg width="18" height="18" viewBox="0 0 24 24" fill="rgba(255,255,255,0.9)">
          <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3" fill="rgba(255,255,255,0.9)"/><circle cx="18" cy="16" r="3" fill="rgba(255,255,255,0.9)"/>
        </svg>
      </div>

      {/* track meta */}
      <div style={{ flex:1, minWidth:0 }}>
        <div style={{ display:'flex', alignItems:'center', gap:6 }}>
          <SpotifyGlyph size={13} color={SPOTIFY_GREEN}/>
          <span style={{ fontFamily:F_SANS, fontSize:14, fontWeight:600, color:ui.text,
            whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis' }}>Power</span>
        </div>
        <div style={{ fontFamily:F_SANS, fontSize:12, color:ui.muted,
          whiteSpace:'nowrap', overflow:'hidden', textOverflow:'ellipsis', marginTop:1 }}>
          Kanye West · Running Hits
        </div>
      </div>

      {/* controls — just pause + skip (as simple as possible) */}
      <div style={{ display:'flex', alignItems:'center', gap:4, flexShrink:0 }}>
        <button style={{ width:36, height:36, borderRadius:18, border:'none', background:'transparent',
          display:'flex', alignItems:'center', justifyContent:'center' }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill={ui.text}>
            <rect x="4" y="3" width="2.5" height="10" rx="0.5"/><rect x="9.5" y="3" width="2.5" height="10" rx="0.5"/>
          </svg>
        </button>
        <button style={{ width:36, height:36, borderRadius:18, border:'none', background:'transparent',
          display:'flex', alignItems:'center', justifyContent:'center' }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill={ui.text}>
            <path d="M3 3l7 5-7 5V3z"/><rect x="11" y="3" width="2" height="10" rx="0.5"/>
          </svg>
        </button>
      </div>
    </div>
  );
}


// ─── CONNECT / PICK PLAYLIST ────────────────────────────────────────────
function SpotifyConnect({ t, ui }) {
  const [connected, setConnected] = React.useState(true);
  const [sel, setSel] = React.useState('running');
  const playlists = [
    { id:'running', name:'Running Hits',   meta:'180 BPM · 50 songs', c:'#E85D5D' },
    { id:'focus',   name:'Deep Focus',     meta:'Calm · 80 songs',    c:'#3B82F6' },
    { id:'hype',    name:'Beast Mode',     meta:'Hype · 65 songs',    c:'#F2C94C' },
    { id:'liked',   name:'Liked Songs',    meta:'342 songs',          c:'#7B5Cff' },
  ];

  return (
    <div style={{ height:'100%', background:ui.bg, display:'flex', flexDirection:'column' }}>
      <SubHeader title="Music" ui={{...ui, accent:t.primary}}/>

      {!connected ? (
        // ── not connected: single clear CTA ──
        <div style={{ flex:1, display:'flex', flexDirection:'column', alignItems:'center',
          justifyContent:'center', padding:'0 32px', textAlign:'center' }}>
          <div style={{ width:72, height:72, borderRadius:36, background:SPOTIFY_GREEN,
            display:'flex', alignItems:'center', justifyContent:'center' }}>
            <SpotifyGlyph size={40} color="#fff"/>
          </div>
          <div style={{ fontFamily:F_SANS, fontSize:24, fontWeight:600, color:ui.text,
            letterSpacing:-0.5, marginTop:22 }}>Play music as you run</div>
          <div style={{ fontFamily:F_SANS, fontSize:15, color:ui.muted, marginTop:10, lineHeight:1.45 }}>
            Connect Spotify to start a playlist automatically when your run begins.
          </div>
          <button onClick={() => setConnected(true)}
            style={{ marginTop:28, height:52, padding:'0 28px', borderRadius:26, border:'none',
              background:SPOTIFY_GREEN, color:'#fff', fontFamily:F_SANS, fontSize:16, fontWeight:600,
              display:'flex', alignItems:'center', gap:10, cursor:'pointer' }}>
            <SpotifyGlyph size={18} color="#fff"/> Connect Spotify
          </button>
        </div>
      ) : (
        // ── connected: status + pick a playlist ──
        <div style={{ flex:1, overflow:'auto', padding:'18px 16px 40px' }}>
          {/* connected status */}
          <div style={{ display:'flex', alignItems:'center', gap:12, padding:'12px 14px',
            borderRadius:16, background:ui.surface, border:`0.5px solid ${ui.border}`, marginBottom:24 }}>
            <div style={{ width:38, height:38, borderRadius:19, background:SPOTIFY_GREEN,
              display:'flex', alignItems:'center', justifyContent:'center' }}>
              <SpotifyGlyph size={22} color="#fff"/>
            </div>
            <div style={{ flex:1 }}>
              <div style={{ fontFamily:F_SANS, fontSize:15, fontWeight:600, color:ui.text }}>Spotify connected</div>
              <div style={{ fontFamily:F_SANS, fontSize:13, color:ui.muted, marginTop:1 }}>yusif · Premium</div>
            </div>
            <button onClick={() => setConnected(false)}
              style={{ background:'none', border:'none', fontFamily:F_SANS, fontSize:14,
                color:ui.muted, cursor:'pointer' }}>Disconnect</button>
          </div>

          {/* auto-play toggle */}
          <div style={{ display:'flex', alignItems:'center', padding:'14px 14px', borderRadius:16,
            background:ui.surface, border:`0.5px solid ${ui.border}`, marginBottom:24 }}>
            <div style={{ flex:1 }}>
              <div style={{ fontFamily:F_SANS, fontSize:15, color:ui.text }}>Auto-play when I start a run</div>
              <div style={{ fontFamily:F_SANS, fontSize:12, color:ui.dim, marginTop:2 }}>Starts the playlist below</div>
            </div>
            <div style={{ width:42, height:25, borderRadius:13, background:t.primary, position:'relative' }}>
              <div style={{ position:'absolute', top:2, left:19, width:21, height:21, borderRadius:11,
                background:'#fff', boxShadow:'0 1px 3px rgba(0,0,0,0.18)' }}/>
            </div>
          </div>

          {/* playlist picker */}
          <div style={{ fontFamily:F_MONO, fontSize:10, fontWeight:600, color:ui.muted,
            letterSpacing:1.2, textTransform:'uppercase', padding:'0 4px 10px' }}>Run playlist</div>
          <div style={{ display:'flex', flexDirection:'column', gap:8 }}>
            {playlists.map(p => {
              const on = sel === p.id;
              return (
                <div key={p.id} onClick={() => setSel(p.id)}
                  style={{ display:'flex', alignItems:'center', gap:14, padding:10, borderRadius:14,
                    cursor:'pointer',
                    background: on ? `${t.primary}12` : ui.surface,
                    border: on ? `1.5px solid ${t.primary}` : `0.5px solid ${ui.border}` }}>
                  <div style={{ width:48, height:48, borderRadius:10, flexShrink:0,
                    background:`linear-gradient(135deg, ${p.c}, ${p.c}99)`,
                    display:'flex', alignItems:'center', justifyContent:'center' }}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="rgba(255,255,255,0.9)">
                      <path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>
                    </svg>
                  </div>
                  <div style={{ flex:1 }}>
                    <div style={{ fontFamily:F_SANS, fontSize:15, fontWeight:600, color:ui.text }}>{p.name}</div>
                    <div style={{ fontFamily:F_SANS, fontSize:13, color:ui.muted, marginTop:2 }}>{p.meta}</div>
                  </div>
                  <div style={{ width:22, height:22, borderRadius:11, flexShrink:0,
                    border: on ? 'none' : `2px solid ${ui.dim}`, background: on ? t.primary : 'transparent',
                    display:'flex', alignItems:'center', justifyContent:'center' }}>
                    {on && <svg width="12" height="12" viewBox="0 0 14 14" fill="none">
                      <path d="M3 7.5l3 3 5-6" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}

Object.assign(window, { SpotifyBar, SpotifyConnect, SpotifyGlyph });
