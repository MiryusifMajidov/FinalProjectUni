// celebrate.jsx — Animated "loop completed" celebration.
// Self-contained CSS keyframe animation that auto-replays on a loop so it
// reads as motion inside the static design canvas. Sequence:
//   0.0s  screen flash + glow ignites
//   0.2s  territory outline draws itself, then fills
//   0.7s  burst ring expands, confetti launches
//   0.9s  "+0.42 km²" springs in and counts up
//   1.4s  supporting text + CTA settle

// inject keyframes once
function ClaimCelebrationStyles() {
  return (
    <style dangerouslySetInnerHTML={{ __html: `
      @keyframes rc-flash { 0%{opacity:0} 12%{opacity:0.9} 100%{opacity:0} }
      @keyframes rc-glow  { 0%{opacity:0; transform:scale(0.6)} 40%{opacity:1} 100%{opacity:0.55; transform:scale(1)} }
      @keyframes rc-draw  { to { stroke-dashoffset:0 } }
      @keyframes rc-fill  { 0%{fill-opacity:0} 100%{fill-opacity:0.32} }
      @keyframes rc-ring  { 0%{transform:scale(0.2);opacity:0.9;stroke-width:6} 100%{transform:scale(2.4);opacity:0;stroke-width:0.5} }
      @keyframes rc-ring2 { 0%{transform:scale(0.2);opacity:0;stroke-width:5} 18%{opacity:0.7} 100%{transform:scale(2.9);opacity:0;stroke-width:0.5} }
      @keyframes rc-pop   { 0%{transform:scale(0);opacity:0} 60%{transform:scale(1.18)} 80%{transform:scale(0.95)} 100%{transform:scale(1);opacity:1} }
      @keyframes rc-num   { 0%{transform:scale(0.3) translateY(20px);opacity:0} 55%{transform:scale(1.12)} 100%{transform:scale(1) translateY(0);opacity:1} }
      @keyframes rc-rise  { 0%{transform:translateY(16px);opacity:0} 100%{transform:translateY(0);opacity:1} }
      @keyframes rc-conf  { 0%{transform:translate(0,0) rotate(0);opacity:0} 8%{opacity:1} 100%{transform:translate(var(--cx),var(--cy)) rotate(var(--cr));opacity:0} }
      @keyframes rc-check { 0%{stroke-dashoffset:36} 100%{stroke-dashoffset:0} }
      @keyframes rc-badge { 0%{transform:scale(0) rotate(-30deg);opacity:0} 60%{transform:scale(1.2) rotate(8deg)} 100%{transform:scale(1) rotate(0);opacity:1} }
      @media (prefers-reduced-motion: reduce) {
        .rc-anim, .rc-anim * { animation: none !important; }
      }
    ` }}/>
  );
}

function Confetti({ primary, replayKey }) {
  // deterministic-ish spread around center
  const colors = [primary, '#F2C94C', '#4ECCA3', '#E85D5D', '#9B7EDC', '#fff'];
  const pieces = React.useMemo(() => {
    const arr = [];
    for (let i = 0; i < 36; i++) {
      const ang = (Math.PI * 2 * i) / 36 + (i % 3) * 0.2;
      const dist = 120 + (i % 5) * 46;
      arr.push({
        c: colors[i % colors.length],
        cx: Math.cos(ang) * dist,
        cy: Math.sin(ang) * dist - 40, // bias upward
        cr: (i % 2 ? 1 : -1) * (180 + (i % 4) * 120),
        delay: 0.7 + (i % 6) * 0.04,
        size: i % 3 === 0 ? 10 : 7,
        round: i % 4 === 0,
      });
    }
    return arr;
  }, [replayKey]);

  return (
    <div style={{ position:'absolute', top:'34%', left:'50%', width:0, height:0, zIndex:6 }}>
      {pieces.map((p, i) => (
        <span key={i} style={{
          position:'absolute',
          width:p.size, height:p.round ? p.size : p.size * 0.5,
          borderRadius: p.round ? '50%' : 2,
          background:p.c,
          '--cx': `${p.cx}px`, '--cy': `${p.cy}px`, '--cr': `${p.cr}deg`,
          animation:`rc-conf 1.6s cubic-bezier(.2,.6,.3,1) ${p.delay}s both`,
        }}/>
      ))}
    </div>
  );
}

function ClaimCelebration({ t, ui }) {
  const [replayKey, setReplayKey] = React.useState(0);
  React.useEffect(() => {
    const id = setInterval(() => setReplayKey(k => k + 1), 4600);
    return () => clearInterval(id);
  }, []);

  const P = t.primary;
  const poly = '110,40 230,28 312,96 286,200 150,224 70,150';

  return (
    <div className="rc-anim" key={replayKey}
      style={{ height:'100%', position:'relative', overflow:'hidden',
        background:'#08080C', display:'flex', flexDirection:'column' }}>
      <ClaimCelebrationStyles/>

      {/* radial glow */}
      <div style={{ position:'absolute', inset:0,
        background:`radial-gradient(70% 45% at 50% 32%, ${P}40, rgba(8,8,12,0.4) 60%, #08080C 100%)`,
        animation:'rc-glow 1.2s ease-out both' }}/>
      {/* white flash */}
      <div style={{ position:'absolute', inset:0, background:'#fff', mixBlendMode:'overlay',
        animation:'rc-flash 0.7s ease-out 0.55s both', pointerEvents:'none' }}/>

      {/* status bar */}
      <div style={{ position:'absolute', top:0, left:0, right:0, zIndex:8 }}>
        <IOSStatusBar dark={true}/>
      </div>

      {/* ───── stage: territory draws + rings + confetti ───── */}
      <div style={{ position:'relative', height:340, marginTop:70 }}>
        {/* expanding rings */}
        <svg width="402" height="340" viewBox="0 0 402 340"
          style={{ position:'absolute', inset:0, overflow:'visible' }}>
          <g style={{ transformOrigin:'201px 150px' }}>
            <circle cx="201" cy="150" r="70" fill="none" stroke={P}
              style={{ transformOrigin:'201px 150px', animation:`rc-ring 1.1s ease-out 0.6s both` }}/>
            <circle cx="201" cy="150" r="70" fill="none" stroke={P}
              style={{ transformOrigin:'201px 150px', animation:`rc-ring2 1.4s ease-out 0.7s both` }}/>
          </g>
        </svg>

        {/* the claimed territory */}
        <svg width="402" height="340" viewBox="0 0 402 340"
          style={{ position:'absolute', inset:0, overflow:'visible',
            filter:`drop-shadow(0 0 16px ${P}aa)` }}>
          <polygon points={poly} fill={P}
            style={{ animation:'rc-fill 0.6s ease-out 0.55s both' }}/>
          <polygon points={poly} fill="none" stroke={P} strokeWidth="4"
            strokeLinejoin="round" strokeLinecap="round"
            strokeDasharray="760" strokeDashoffset="760"
            style={{ animation:'rc-draw 0.7s cubic-bezier(.5,0,.2,1) 0.2s both' }}/>
          {/* runner dot closing the loop */}
          <circle cx="110" cy="40" r="7" fill="#fff"
            style={{ animation:'rc-pop 0.4s ease-out 0.85s both' }}/>
        </svg>

        {/* center checkmark badge */}
        <div style={{ position:'absolute', top:110, left:'50%', transform:'translateX(-50%)',
          width:80, height:80, borderRadius:40, background:P,
          display:'flex', alignItems:'center', justifyContent:'center',
          boxShadow:`0 12px 40px ${P}88`,
          animation:'rc-badge 0.6s cubic-bezier(.3,1.4,.5,1) 0.95s both' }}>
          <svg width="38" height="38" viewBox="0 0 38 38" fill="none">
            <path d="M10 19.5l6 6 12-13" stroke="#fff" strokeWidth="3.5"
              strokeLinecap="round" strokeLinejoin="round"
              strokeDasharray="36" strokeDashoffset="36"
              style={{ animation:'rc-check 0.45s ease-out 1.25s both' }}/>
          </svg>
        </div>

        <Confetti primary={P} replayKey={replayKey}/>
      </div>

      {/* ───── numbers + copy ───── */}
      <div style={{ position:'relative', flex:1, padding:'8px 28px 0', textAlign:'center', zIndex:7 }}>
        <div style={{ fontFamily:F_MONO, fontSize:12, fontWeight:600, color:P,
          letterSpacing:2, textTransform:'uppercase',
          animation:'rc-rise 0.5s ease-out 1.1s both' }}>
          Loop closed
        </div>
        <div style={{ marginTop:10, fontFamily:F_SANS, fontSize:30, fontWeight:600,
          color:'#fff', letterSpacing:-0.6,
          animation:'rc-rise 0.5s ease-out 1.2s both' }}>
          The land is yours
        </div>

        <div style={{ marginTop:16, display:'flex', alignItems:'baseline',
          justifyContent:'center', gap:8,
          animation:'rc-num 0.7s cubic-bezier(.3,1.3,.5,1) 1.0s both' }}>
          <CountUp to={0.42} primary={P} replayKey={replayKey}/>
          <span style={{ fontFamily:F_MONO, fontSize:18, color:'rgba(255,255,255,0.5)' }}>km²</span>
        </div>
        <div style={{ marginTop:6, fontFamily:F_SANS, fontSize:14, color:'rgba(255,255,255,0.6)',
          animation:'rc-rise 0.5s ease-out 1.5s both' }}>
          claimed · you’re now <b style={{ color:'#fff' }}>3rd</b> in the city
        </div>
      </div>

      {/* ───── CTAs ───── */}
      <div style={{ position:'relative', padding:'0 24px 56px', display:'flex',
        flexDirection:'column', gap:10, zIndex:7,
        animation:'rc-rise 0.5s ease-out 1.65s both' }}>
        <button style={{ height:54, borderRadius:27, border:'none', background:P, color:'#fff',
          fontFamily:F_SANS, fontSize:16, fontWeight:600 }}>Save &amp; share</button>
        <button style={{ height:54, borderRadius:27, border:'1px solid rgba(255,255,255,0.16)',
          background:'transparent', color:'#fff', fontFamily:F_SANS, fontSize:16, fontWeight:500 }}>
          Back to map
        </button>
      </div>
    </div>
  );
}

// number that counts up from 0 to `to` on each replay
function CountUp({ to, primary, replayKey }) {
  const [val, setVal] = React.useState(0);
  React.useEffect(() => {
    setVal(0);
    let raf, start;
    const delay = 1000; // sync with rc-num animation start
    const dur = 700;
    const tick = (ts) => {
      if (!start) start = ts;
      const e = ts - start;
      if (e < delay) { raf = requestAnimationFrame(tick); return; }
      const p = Math.min((e - delay) / dur, 1);
      const eased = 1 - Math.pow(1 - p, 3);
      setVal(to * eased);
      if (p < 1) raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [replayKey, to]);

  return (
    <span style={{ fontFamily:F_SANS, fontSize:76, fontWeight:600, color:'#fff',
      letterSpacing:-3, lineHeight:1, fontVariantNumeric:'tabular-nums' }}>
      +{val.toFixed(2)}
    </span>
  );
}

Object.assign(window, { ClaimCelebration, ClaimCelebrationStyles });
