// map.jsx — Three visually distinct map styles + territory polygons.
//   • mono — minimalist monochrome (Apple Maps dark)
//   • real — realistic Google Maps look (cased roads, parks, water, buildings)
//   • game — stylised neon / Tron-y look on a dark grid

const MAP_PALETTES = {
  // ─── monochrome (current minimalist version) ─────────────────────────
  dark: {
    kind: 'mono',
    bg: '#0E0E10',
    road: 'rgba(255,255,255,0.07)',
    roadMain: 'rgba(255,255,255,0.13)',
    roadMainW: 2.5,
    roadMinorW: 1,
    water: 'rgba(80,120,200,0.18)',
    park: 'rgba(120,170,130,0.10)',
    label: 'rgba(255,255,255,0.45)',
    building: 'rgba(255,255,255,0.04)',
    showBuildings: false,
  },

  // ─── realistic — Google Maps-like ────────────────────────────────────
  light: {
    kind: 'real',
    bg: '#EDE6D8',                 // warm land tan
    landBlock: '#E5DDCB',
    roadCasing: '#C5BBA6',         // road outline
    road: '#FFFFFF',               // road body (white)
    roadMainCasing: '#D4B570',     // arterial outline (slight orange-yellow)
    roadMain: '#FFE39C',           // arterial body (Google-yellow)
    roadMainW: 7,
    roadMinorW: 3.5,
    water: '#AECCEB',              // calm blue
    park: '#C7DFAB',               // saturated map-green
    label: '#5A5849',
    building: '#D9D0BC',           // building polygons
    buildingStroke: '#C8BFAB',
    showBuildings: true,
  },

  // ─── game — stylised, neon ───────────────────────────────────────────
  game: {
    kind: 'game',
    bg: '#08081C',                 // deep navy/violet
    grid: 'rgba(120,160,255,0.07)',
    road: 'rgba(140,220,255,0.35)',
    roadMain: '#5DD9FF',           // bright cyan
    roadMainW: 2.5,
    roadMinorW: 1.2,
    water: 'rgba(200,90,200,0.30)',// magenta water
    waterStroke: '#D26AE0',
    park: 'rgba(80,255,170,0.25)', // neon green park
    parkStroke: '#4AFFB3',
    label: 'rgba(220,240,255,0.85)',
    showBuildings: false,
    glow: true,
  },
};

// ─── base geometry (shared so all 3 styles read as same city) ──────────
const ROAD_MAIN_PATHS = [
  'M-20 240 Q 100 220 220 250 T 460 240',
  'M180 -20 Q 200 200 230 420 T 260 900',
  'M-20 540 Q 140 530 280 560 T 460 540',
  'M40 -20 Q 80 240 60 480 T 90 900',
];

const ROAD_MINOR_PATHS = [
  'M-20 120 L 460 130', 'M-20 340 L 460 350',
  'M-20 440 L 460 450', 'M-20 640 L 460 650',
  'M-20 740 L 460 760', 'M-20 820 L 460 830',
  'M120 -20 L 130 900', 'M300 -20 L 320 900',
  'M370 -20 L 390 900',
];

const RIVER = 'M-20 700 Q 80 670 160 690 Q 260 720 340 680 Q 420 650 460 660 L 460 760 Q 380 740 300 770 Q 200 800 100 770 Q 30 750 -20 760 Z';
const PARK  = 'M 240 100 L 360 90 L 380 200 L 280 220 L 235 170 Z';

const BUILDINGS = [
  '50,160 92,156 96,182 54,184',
  '95,160 130,158 134,184 99,186',
  '210,300 252,296 256,330 214,334',
  '260,304 308,300 312,338 264,342',
  '60,400 105,396 108,425 64,428',
  '110,400 152,398 154,427 113,430',
  '290,420 332,418 336,448 294,450',
  '140,500 180,498 184,528 144,530',
  '345,520 392,518 396,548 348,550',
  '210,580 262,578 266,605 214,608',
  '40,600 78,598 81,625 43,627',
  '300,180 340,178 342,208 302,210',
  '380,300 410,298 412,335 382,337',
  '20,260 60,258 62,290 22,292',
  '270,650 318,648 322,680 274,682',
];


function MapBase({ palette = 'dark', w = 402, h = 700, children, style = {} }) {
  const C = MAP_PALETTES[palette] || MAP_PALETTES.dark;
  const isMono = C.kind === 'mono';
  const isReal = C.kind === 'real';
  const isGame = C.kind === 'game';

  return (
    <svg viewBox={`0 0 ${w} ${h}`} width={w} height={h}
      style={{ display:'block', background: C.bg, ...style }}>
      <defs>
        <pattern id="stripe-pattern" patternUnits="userSpaceOnUse" width="6" height="6" patternTransform="rotate(45)">
          <line x1="0" y1="0" x2="0" y2="6" stroke="currentColor" strokeWidth="2.5"/>
        </pattern>
        {isGame && (
          <pattern id="game-grid" patternUnits="userSpaceOnUse" width="28" height="28">
            <path d={`M 28 0 L 0 0 0 28`} fill="none" stroke={C.grid} strokeWidth="1"/>
          </pattern>
        )}
        {isGame && (
          <filter id="game-glow" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="2.5" result="b"/>
            <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
        )}
      </defs>

      {/* land base */}
      <rect width={w} height={h} fill={C.bg}/>

      {/* game grid overlay */}
      {isGame && <rect width={w} height={h} fill="url(#game-grid)"/>}

      {/* park */}
      {isReal && <path d={PARK} fill={C.park} stroke="#B5CC93" strokeWidth="1"/>}
      {isMono && <path d={PARK} fill={C.park}/>}
      {isGame && <path d={PARK} fill={C.park} stroke={C.parkStroke} strokeWidth="1.5" filter="url(#game-glow)"/>}

      {/* river / water */}
      {isReal && <path d={RIVER} fill={C.water} stroke="#8FB6DC" strokeWidth="1"/>}
      {isMono && <path d={RIVER} fill={C.water}/>}
      {isGame && <path d={RIVER} fill={C.water} stroke={C.waterStroke} strokeWidth="1.5" filter="url(#game-glow)"/>}

      {/* buildings (real only) */}
      {C.showBuildings && BUILDINGS.map((pts, i) => (
        <polygon key={i} points={pts} fill={C.building} stroke={C.buildingStroke} strokeWidth="0.6"/>
      ))}

      {/* ROADS — render differs per kind */}
      {isReal && (
        <g>
          {/* minor casing → minor body, then main casing → main body */}
          {ROAD_MINOR_PATHS.map((d, i) => (
            <path key={`mc${i}`} d={d} stroke={C.roadCasing} strokeWidth={C.roadMinorW + 1.5} fill="none" strokeLinecap="round"/>
          ))}
          {ROAD_MINOR_PATHS.map((d, i) => (
            <path key={`mb${i}`} d={d} stroke={C.road} strokeWidth={C.roadMinorW} fill="none" strokeLinecap="round"/>
          ))}
          {ROAD_MAIN_PATHS.map((d, i) => (
            <path key={`Mc${i}`} d={d} stroke={C.roadMainCasing} strokeWidth={C.roadMainW + 2} fill="none" strokeLinecap="round"/>
          ))}
          {ROAD_MAIN_PATHS.map((d, i) => (
            <path key={`Mb${i}`} d={d} stroke={C.roadMain} strokeWidth={C.roadMainW} fill="none" strokeLinecap="round"/>
          ))}
        </g>
      )}

      {(isMono || isGame) && (
        <g filter={isGame ? 'url(#game-glow)' : undefined}>
          {ROAD_MINOR_PATHS.map((d, i) => (
            <path key={i} d={d} stroke={C.road} strokeWidth={C.roadMinorW} fill="none" strokeLinecap="round"/>
          ))}
          {ROAD_MAIN_PATHS.map((d, i) => (
            <path key={`M${i}`} d={d} stroke={C.roadMain} strokeWidth={C.roadMainW} fill="none" strokeLinecap="round"/>
          ))}
        </g>
      )}

      {/* labels — different typographic personality per style */}
      <g style={{
        fontFamily: isReal ? '"Geist", system-ui' : isGame ? '"Geist Mono", monospace' : '"Geist", system-ui',
        fontSize: isReal ? 11 : 9,
        fontWeight: isReal ? 500 : 600,
        letterSpacing: isReal ? 0.2 : (isGame ? 1.4 : 0.6),
        textTransform: isReal ? 'none' : 'uppercase',
      }}>
        <text x={200} y={420} fill={C.label} textAnchor="middle">{isReal ? 'City Center' : 'CITY CENTER'}</text>
        <text x={310} y={150} fill={C.label} textAnchor="middle">{isReal ? 'Central Park' : 'PARK'}</text>
        <text x={250} y={730} fill={C.label} textAnchor="middle" opacity={isReal ? 0.8 : 0.7}>{isReal ? 'River' : 'RIVER'}</text>
      </g>

      {children}
    </svg>
  );
}

// ─── territory polygons (unchanged) ────────────────────────────────────
const DEFAULT_TERRITORIES = [
  { id: 'you',  color: '#3B82F6', poly: '120,300 220,260 300,330 280,430 180,460 100,400', label: 'YOU' },
  { id: 'r1',   color: '#E85D5D', poly: '20,80 130,60 160,160 90,210 10,200', label: 'KAI' },
  { id: 'r2',   color: '#F2C94C', poly: '290,500 380,490 395,610 320,640 270,580' },
  { id: 'r3',   color: '#9B7EDC', poly: '20,500 110,520 100,650 30,680' },
  { id: 'r4',   color: '#4ECCA3', poly: '250,80 360,70 370,180 270,200' },
];

function Territory({ color, poly, viz = 'fill-border', strokeWidth = 3, opacity = 1 }) {
  if (viz === 'solid') {
    return <polygon points={poly} fill={color} stroke={color} strokeWidth={strokeWidth} opacity={opacity}/>;
  }
  if (viz === 'stripe') {
    return (
      <g opacity={opacity} style={{ color }}>
        <polygon points={poly} fill="url(#stripe-pattern)"/>
        <polygon points={poly} fill="none" stroke={color} strokeWidth={strokeWidth}/>
      </g>
    );
  }
  if (viz === 'glow') {
    return (
      <g opacity={opacity}>
        <polygon points={poly} fill={color} fillOpacity="0.25"
          stroke={color} strokeWidth={strokeWidth + 1}
          style={{ filter: `drop-shadow(0 0 8px ${color})` }}/>
      </g>
    );
  }
  return (
    <g opacity={opacity}>
      <polygon points={poly} fill={color} fillOpacity="0.28"/>
      <polygon points={poly} fill="none" stroke={color} strokeWidth={strokeWidth} strokeLinejoin="round"/>
    </g>
  );
}

Object.assign(window, { MapBase, Territory, DEFAULT_TERRITORIES, MAP_PALETTES });
