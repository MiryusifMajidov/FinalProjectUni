// app.jsx — RunClaim design canvas + tweaks
// Lays all 12 iOS screens out in 4 grouped sections on a DesignCanvas.

const TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "primary": "#3B82F6",
  "mapStyle": "dark",
  "territoryViz": "fill-border",
  "dark": true
}/*EDITMODE-END*/;

function App() {
  const [t, setTweak] = useTweaks(TWEAK_DEFAULTS);
  const ui = t.dark ? UI.dark : UI.light;
  const tk = { primary: t.primary, mapStyle: t.mapStyle, territoryViz: t.territoryViz };

  // Wrap each screen in an iOS device for consistency
  const Frame = ({ children, dark }) => (
    <IOSDevice dark={dark ?? t.dark} width={402} height={874}>
      {children}
    </IOSDevice>
  );

  // Per-style override (for the "Map styles" section that locks each artboard
  // to a specific style, regardless of the current tweak)
  const styleOverride = (mapStyle, darkUI) => ({
    tk: { ...tk, mapStyle },
    ui: darkUI ? UI.dark : UI.light,
    dark: darkUI,
  });
  const variants = {
    dark:  styleOverride('dark',  true),
    light: styleOverride('light', false),
    game:  styleOverride('game',  true),
  };

  return (
    <>
      <DesignCanvas>
        <DCSection id="auth" title="Auth & Onboarding"
          subtitle="Splash → onboarding → Google or guest → pick a name">
          <DCArtboard id="splash" label="01 · Splash" width={402} height={874}>
            <Frame><Splash t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="onboarding" label="02 · Onboarding" width={402} height={874}>
            <Frame><Onboarding t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="login" label="03 · Login" width={402} height={874}>
            <Frame><Login t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="username" label="04 · Username" width={402} height={874}>
            <Frame><Username t={tk} ui={ui}/></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="run" title="Map & Run"
          subtitle="The core loop — see your map, run, claim territory">
          <DCArtboard id="map" label="05 · Map (idle)" width={402} height={874}>
            <Frame><MapIdle t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="active" label="06 · Active run" width={402} height={874}>
            <Frame><ActiveRun t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="claimed" label="07 · Territory claimed" width={402} height={874}>
            <Frame><Claimed t={tk} ui={ui}/></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="social" title="Social & Activity"
          subtitle="Who's claiming what, and who's coming for yours">
          <DCArtboard id="leader" label="08 · Leaderboard" width={402} height={874}>
            <Frame><Leaderboard t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="notifs" label="09 · Activity" width={402} height={874}>
            <Frame><Notifications t={tk} ui={ui}/></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="me" title="Profile & Settings"
          subtitle="Your map, your stats, your account">
          <DCArtboard id="profile" label="10 · Profile" width={402} height={874}>
            <Frame><Profile t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="stats" label="11 · Stats" width={402} height={874}>
            <Frame><Stats t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="settings" label="12 · Settings" width={402} height={874}>
            <Frame><Settings t={tk} ui={ui}/></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="mapstyles" title="Map styles"
          subtitle="The same screen in every style — pick from Settings">
          <DCArtboard id="ms-dark" label="Monochrome · dark" width={402} height={874}>
            <IOSDevice dark={true} width={402} height={874}>
              <MapIdle t={variants.dark.tk} ui={variants.dark.ui}/>
            </IOSDevice>
          </DCArtboard>
          <DCArtboard id="ms-light" label="Monochrome · light" width={402} height={874}>
            <IOSDevice dark={false} width={402} height={874}>
              <MapIdle t={variants.light.tk} ui={variants.light.ui}/>
            </IOSDevice>
          </DCArtboard>
          <DCArtboard id="ms-game" label="Game" width={402} height={874}>
            <IOSDevice dark={true} width={402} height={874}>
              <MapIdle t={variants.game.tk} ui={variants.game.ui}/>
            </IOSDevice>
          </DCArtboard>
        </DCSection>

        <DCSection id="bg" title="Background tracking"
          subtitle="The run lives on outside the app — Dynamic Island + Lock screen Live Activity">
          <DCArtboard id="lock" label="13 · Lock screen" width={402} height={874}>
            <IOSDevice dark={true} width={402} height={874}>
              <LockScreen t={tk} ui={UI.dark}/>
            </IOSDevice>
          </DCArtboard>
          <DCArtboard id="island" label="14 · Dynamic Island · compact" width={402} height={874}>
            <IOSDevice dark={true} width={402} height={874}>
              <SpringboardLive t={tk} ui={UI.dark}/>
            </IOSDevice>
          </DCArtboard>
          <DCArtboard id="island-exp" label="15 · Dynamic Island · expanded" width={402} height={874}>
            <IOSDevice dark={true} width={402} height={874}>
              <IslandExpanded t={tk} ui={UI.dark}/>
            </IOSDevice>
          </DCArtboard>
          <DCArtboard id="inapp" label="16 · Inside another app" width={402} height={874}>
            <IOSDevice dark={true} width={402} height={874}>
              <InAppLive t={tk} ui={UI.dark}/>
            </IOSDevice>
          </DCArtboard>
        </DCSection>
      </DesignCanvas>

      <TweaksPanel title="Tweaks">
        <TweakSection label="Theme"/>
        <TweakToggle label="Dark mode" value={t.dark}
          onChange={(v) => setTweak('dark', v)}/>
        <TweakColor label="Primary" value={t.primary}
          options={['#3B82F6', '#FF5A4E', '#0ACF83', '#A855F7', '#FACC15', '#111827']}
          onChange={(v) => setTweak('primary', v)}/>

        <TweakSection label="Map"/>
        <TweakRadio label="Style" value={t.mapStyle}
          options={['dark', 'light', 'game']}
          onChange={(v) => setTweak('mapStyle', v)}/>

        <TweakSection label="Territory"/>
        <TweakSelect label="Visual" value={t.territoryViz}
          options={[
            { value:'fill-border', label:'Fill + border' },
            { value:'solid',       label:'Solid' },
            { value:'stripe',      label:'Stripe pattern' },
            { value:'glow',        label:'Glow' },
          ]}
          onChange={(v) => setTweak('territoryViz', v)}/>
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
