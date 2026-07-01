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
  const tk = { primary: t.primary, mapStyle: t.mapStyle, territoryViz: t.territoryViz, dark: t.dark };

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
        <DCSection id="auth" title="Onboarding & Auth"
          subtitle="Splash → 3 onboarding slides → Google or guest → name → permissions">
          <DCArtboard id="splash" label="01 · Splash" width={402} height={874}>
            <Frame><Splash t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="onboarding" label="02 · Onboarding · run a loop" width={402} height={874}>
            <Frame><Onboarding t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="onboarding2" label="03 · Onboarding · steal land" width={402} height={874}>
            <Frame><Onboarding2 t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="onboarding3" label="04 · Onboarding · compete" width={402} height={874}>
            <Frame><Onboarding3 t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="login" label="05 · Login" width={402} height={874}>
            <Frame><Login t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="guest" label="06 · Guest mode" width={402} height={874}>
            <Frame><GuestMap t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="username" label="07 · Username" width={402} height={874}>
            <Frame><Username t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="loc-perm" label="08 · Location permission" width={402} height={874}>
            <Frame><LocationPermission t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="notif-perm" label="09 · Notification permission" width={402} height={874}>
            <Frame><NotifPermission t={tk} ui={ui}/></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="run" title="Map & Run"
          subtitle="The core loop — see the map, tap a territory, run, claim, share">
          <DCArtboard id="map" label="10 · Map (idle)" width={402} height={874}>
            <Frame><MapIdle t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="territory" label="11 · Territory detail" width={402} height={874}>
            <Frame><TerritoryDetail t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="countdown" label="12 · Countdown" width={402} height={874}>
            <Frame><Countdown t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="active" label="13 · Active run" width={402} height={874}>
            <Frame><ActiveRun t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="autoclaim" label="14 · Auto-claim (loop closes) ✦" width={402} height={874}>
            <Frame><AutoClaim t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="paused" label="15 · Run paused" width={402} height={874}>
            <Frame><RunPaused t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="claimed" label="16 · Run summary" width={402} height={874}>
            <Frame><Claimed t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="celebrate" label="17 · Claim celebration ✦" width={402} height={874}>
            <Frame dark={true}><ClaimCelebration t={tk} ui={UI.dark}/></Frame>
          </DCArtboard>
          <DCArtboard id="share" label="18 · Share card" width={402} height={874}>
            <Frame dark={true}><ShareCard t={tk} ui={UI.dark}/></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="social" title="Social & Activity"
          subtitle="Who's claiming what, and who's coming for yours">
          <DCArtboard id="leader" label="19 · Leaderboard" width={402} height={874}>
            <Frame><Leaderboard t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="notifs" label="20 · Activity" width={402} height={874}>
            <Frame><Notifications t={tk} ui={ui}/></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="me" title="Profile & Settings"
          subtitle="Your map, your stats, your account">
          <DCArtboard id="profile" label="21 · Profile" width={402} height={874}>
            <Frame><Profile t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="edit" label="22 · Edit profile" width={402} height={874}>
            <Frame><EditProfile t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="stats" label="23 · Stats" width={402} height={874}>
            <Frame><Stats t={tk} ui={ui}/></Frame>
          </DCArtboard>
        </DCSection>

        <DCSection id="settings-flow" title="Settings — every screen"
          subtitle="The hub and each page a row opens. Map style has a live preview so you never leave to check.">
          <DCArtboard id="settings" label="24 · Settings (hub)" width={402} height={874}>
            <Frame><Settings t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="map-style" label="25 · Map style · live preview ✦" width={402} height={874}>
            <Frame><MapStylePicker t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="account" label="26 · Account" width={402} height={874}>
            <Frame><AccountSettings t={tk} ui={ui}/></Frame>
          </DCArtboard>
          <DCArtboard id="notif-settings" label="27 · Notifications" width={402} height={874}>
            <Frame><NotificationSettings t={tk} ui={ui}/></Frame>
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
