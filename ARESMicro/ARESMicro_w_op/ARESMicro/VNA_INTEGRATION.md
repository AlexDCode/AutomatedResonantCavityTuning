# ARESMicro VNA Integration

VNA connection + measurement support for ARES_Micro, ported from the ARES
(AutomatedRadioEvaluationSuite) object-oriented instrument framework. It is
**fully standalone** — everything lives inside this project, no ARES install
required.

## What was added

```
AutomatedRadioEvaluationSuiteMicro1.0/src/support/instrumentControl/
├── ITransport.m        Abstract I/O interface (VISA / TCP / simulation seam)
├── VisaTransport.m     Real hardware over VISA (LAN, GPIB, USB)
├── TcpTransport.m      Raw TCP sockets (e.g. Copper Mountain S4 bridge)
├── SimTransport.m      No hardware at all — scripted responses for dev/tests
├── SCPIInstrument.m    Base SCPI driver (command registry, JSON dialects)
├── VNAInstCtrl.m       The VNA driver (sweeps, traces, complex S-params)
├── CommandSets/        Per-model SCPI dialects (drop-in JSON, no code edits)
│   ├── N5232B.json     Keysight PNA-L (the lab 4-port)
│   ├── E5072A.json     Agilent/Keysight ENA
│   └── CMT808U.json    Copper Mountain (via S4 socket server)
├── vnaAddressList.m    VNA dropdown items from instrumentAddresses.csv
├── connectVNA.m        Dropdown entry / address  ->  connected driver
├── readVNATraces.m     One sweep, read every configured trace (formatted)
├── readSMatrix.m       One sweep, full complex n-port S-matrix
├── plotVNATraces.m     Draw a one-shot measurement onto app.UIAxes
├── VNALiveView.m       Real-time continuously updating S-parameter display
├── disconnectVNA.m     Clean teardown (stops live view, then disconnects)
├── updateAppVNAData.m  Mirrors live data into app variables every tick
└── tests/test_vna_sim.m  Headless self-test (run it: 9/9 PASS, no hardware)
```

## Philosophy (same as ARES)

**You set up traces and CALIBRATE on the VNA front panel; the app only
reads.** The app never changes your instrument state except to trigger single
sweeps (and optionally restore continuous sweep so the display goes live
again).

## Quick start — no app changes needed

Test from the MATLAB command window first:

```matlab
cd .../AutomatedRadioEvaluationSuiteMicro1.0/src
addpath(genpath('support'))

% Real hardware (pick any entry vnaAddressList() prints):
vna  = connectVNA("Keysight Technologies N5232B: TCPIP0::192.168.1.161::inst0::INSTR");
meas = readVNATraces(vna);              % reads whatever is on the screen
plot(meas.freqHz/1e9, meas.data); legend(meas.names)

[freqHz, S] = readSMatrix(vna, 1:4);    % full 4-port complex matrix
squeeze(20*log10(abs(S(2,1,:))))        % |S21| in dB vs frequency

vna.setContinuous(true);                % give the operator a live display
vna.disconnect();

% No hardware handy? Simulated VNA (also how the self-test runs):
vna = connectVNA("SIM", 'Simulate', true);
```

Self-test: `cd support/instrumentControl/tests; test_vna_sim`

## Wiring it into ARES_Micro.mlapp (App Designer steps)

The `.mlapp` is a binary that only App Designer can edit, so these edits are
manual. The Setup tab already has `VNASliderDropDown` and `VNAStatusLabel` —
they just need a property, a button, and three callbacks.

**1. Add two private properties** (Code View → red "Property" button → Private):

```matlab
VNA = [];        % VNAInstCtrl driver, [] when disconnected
LiveView = [];   % VNALiveView, [] until live plotting starts
```

**2. Fix the path setup in `startupFcn` and populate the dropdown.** The
current `addpath(genpath('.\'))` only works if MATLAB's current folder
happens to be `src`. Replace it with a location-independent version:

```matlab
appDir = fileparts(mfilename('fullpath'));
addpath(genpath(fullfile(appDir, 'support')));

try
    app.VNASliderDropDown.Items = vnaAddressList();
catch ME
    app.VNAStatusLabel.Text = 'Status: no instrument CSV';
end
```

**3. Add a "Connect VNA" button** on the Setup tab (a free row under the
dropdown) with this `ButtonPushedFcn`:

```matlab
try
    app.VNAStatusLabel.Text = 'Status: Connecting...'; drawnow;
    app.VNA = connectVNA(app.VNASliderDropDown.Value);
    idParts = split(app.VNA.IDN, ",");
    app.VNAStatusLabel.Text = "Status: " + strjoin(idParts(1:min(2,end)), " ");
catch ME
    app.VNAStatusLabel.Text = 'Status: Failed';
    uialert(app.UIFigure, ME.message, 'VNA Connection Error');
end
```

**4. Add a "Live View" STATE button** (App Designer: *State Button*, not a
push button) on the Tune tab. The S-Parameters axes then updates
continuously in real time while the actuator sliders move — no snapshot
clicking. `ValueChangedFcn`:

```matlab
try
    if event.Value                        % toggled ON
        if isempty(app.LiveView)
            app.LiveView = VNALiveView(app.VNA, app.UIAxes, 'Period', 0.1);
        end
        app.LiveView.start();
    else                                  % toggled OFF
        app.LiveView.stop();
    end
catch ME
    app.LiveViewButton.Value = false;
    uialert(app.UIFigure, ME.message, 'VNA Live View Error');
end
```

How it works: `start()` runs one synchronized sweep to learn the trace
setup, then puts the VNA in free-running continuous sweep and just *samples*
the trace buffers every 0.1 s, updating the plot lines in place. The real
refresh rate is bounded by the instrument's sweep/transfer speed, not the
timer — ticks that arrive while a read is in flight are skipped, so a short
period is always safe. If a torn mid-sweep frame ever bothers you (heavy
averaging, many points), construct with `'Mode', "triggered"` for coherent
one-sweep-per-frame updates at a slower rate.

(Prefer a one-shot button instead? `meas = readVNATraces(app.VNA);
plotVNATraces(app.UIAxes, meas);` still works.)

**5. Feed the optimizer.** In the Optimize-tab callbacks (the
`read_live_vna_data()` placeholder in `optiProg/BayesionOpt.m`), the live
measurement is:

```matlab
if ~isempty(app.LiveView), app.LiveView.pause(); end   % one socket, one owner

[freqHz, S] = readSMatrix(app.VNA, 1:4);   % S(i,j,k) = Sij at freqHz(k)

% e.g. evaluate at the design frequency f0:
[~, fi] = min(abs(freqHz - f0));
y_measured = 20*log10(abs(reshape(S(:,:,fi), [], 1)));   % 16x1 dB vector

if ~isempty(app.LiveView), app.LiveView.resume(); end
```

**Important:** the live view and the optimizer share one SCPI connection, so
the poller must be paused around synchronized reads (interleaved queries
corrupt each other). Pause once before the optimization loop and resume
after it — not per iteration. Each `readSMatrix` call is one triggered
sweep, which is exactly what an MPC/Bayesian step wants.

**6. Disconnect** — in a Disconnect button and/or the app's `delete`, use
the `disconnectVNA` helper (it never throws — safe with nothing connected,
stale handles, or an instrument that was already unplugged):

```matlab
disconnectVNA(app.VNA, app.LiveView);
app.VNA = [];
app.LiveView = [];
app.VNAStatusLabel.Text = 'Status: Disconnected';
if isprop(app, 'LiveViewButton'), app.LiveViewButton.Value = false; end
```

Two notes from the field on "the disconnect button does nothing":
- An earlier revision of this guide never updated `VNAStatusLabel` on
  disconnect, so a *working* disconnect looked like a dead button. Keep the
  status-label line.
- If the callback references `app.LiveView` but you never added that
  property (step 1), the callback dies on "Unrecognized property" before
  reaching the disconnect. `disconnectVNA(app.VNA)` alone works if you
  skipped the live view.

Stopping the live view timer (which `disconnectVNA` does first) matters: an
orphaned timer keeps firing after the connection closes and spams warnings.

## Live frequency / S-parameter variables in the app

While the live view is running it also keeps the newest arrays available —
no extra instrument I/O, they update with every polling tick.

**Option A — read them wherever you need them (no wiring at all):**

```matlab
freqHz = app.LiveView.FreqHz;      % [npts x 1] Hz
sParam = app.LiveView.Data;        % [npts x nTraces] display units (dB)
names  = app.LiveView.Names;       % ["S11" "S21" ...]
m      = app.LiveView.latest();    % or all of it atomically in one struct
                                   % (.freqHz .data .sdata .names .time)
```

Any callback — an Optimize button, the gap-slider logic, a logging routine —
can do this at any moment and always gets the latest data.

**Option B — dedicated app variables, refreshed automatically every tick.**
App Designer steps:

1. Code View → **Property ▼ → Public Property** (must be *Public*: an
   external function cannot write private app properties). Add:

   ```matlab
   properties (Access = public)
       VNAFreqHz   = [];          % [npts x 1] sweep frequencies (Hz)
       VNASParams  = [];          % [npts x nTraces] live data (dB)
       VNASNames   = strings(0);  % trace labels
       VNASComplex = [];          % complex S-params (StoreComplex only)
   end
   ```

2. In the Live View toggle callback (step 4 above), build the live view
   with the `UpdateFcn` hook wired to the bundled bridge function:

   ```matlab
   app.LiveView = VNALiveView(app.VNA, app.UIAxes, ...
       'UpdateFcn', @(meas) updateAppVNAData(app, meas));
   app.LiveView.start();
   ```

   `updateAppVNAData` copies each field into the matching app property and
   silently skips any property you chose not to add.

3. Use them anywhere, e.g. a numeric readout of |S21| at the design
   frequency (put this in the same UpdateFcn chain or any callback):

   ```matlab
   [~, fi] = min(abs(app.VNAFreqHz - 1.5e9));
   app.S21Label.Text = sprintf('S21: %.2f dB', ...
       app.VNASParams(fi, app.VNASNames == "S21"));
   ```

**Want true complex S-parameters instead of display-format dB?** Build the
live view with `'StoreComplex', true`:

```matlab
app.LiveView = VNALiveView(app.VNA, app.UIAxes, 'StoreComplex', true, ...
    'UpdateFcn', @(meas) updateAppVNAData(app, meas));
```

Then `app.LiveView.SData` / `app.VNASComplex` hold [npts x nTraces] complex
values (same one-message-per-trace fast path, reading raw SDATA instead of
the display buffer), and the plot shows 20·log10|S| computed locally — note
that a trace formatted as *phase* on the VNA front panel will then display
as magnitude in the app. Free-run mode only; for a coherent single-sweep
complex frame (all 16 Sij from ONE sweep, optimizer-grade) keep using
`readSMatrix` with `pause()`/`resume()`.

Caveats: the arrays are round-robin fresh — with 16 traces at 4 per tick, a
column can be up to 4 ticks older than the newest one (check
`app.LiveView.LastUpdate` / `meas.time` if it matters). The `UpdateFcn`
runs on the UI thread at the tick rate: keep it cheap, and know that if it
errors it is disabled with a single warning (polling continues).

## Performance / lag

The live view is tuned so a full 4-port setup stays usable, using three
mechanisms (all automatic):

- **Compound reads** — each trace is fetched with one `select;:read` SCPI
  message instead of two round trips. Message latency, not data size,
  dominates on LAN.
- **Round-robin chunking** — only `MaxTracesPerTick` traces (default 4) are
  read per timer tick, so the UI thread is never blocked for a whole
  16-trace frame. Every trace still cycles through; sliders stay smooth.
- **Display decimation** — at most `MaxPoints` (default 501) points per
  line are drawn. App Designer axes render in a web canvas; 16 × 1601-point
  lines per frame is renderer lag, not instrument lag. The full sweep is
  still read.

If 16 traces are configured but you only tune against a few, **display a
subset — it is the biggest speedup available** (4 traces ≈ 4× the frame
rate):

```matlab
app.LiveView = VNALiveView(app.VNA, app.UIAxes, ...
    'Traces', ["S11" "S21" "S31" "S41"]);   % names or indices, e.g. [1 3 5]
```

Beyond that, the frame rate is set by the instrument: fewer sweep points
and a wider IF bandwidth make both the sweep and the transfers faster.

> **Pitfall from the existing code:** MATLAB does *not* dispatch
> `app.someFunction()` to plain functions on the path — that syntax only
> works for methods defined inside the .mlapp. The existing Pico helpers
> (`easyWakeUp`, `waitForResponse`, ...) are standalone files and must be
> called as `easyWakeUp(app)`, and likewise all VNA helpers are called as
> plain functions: `connectVNA(...)`, `readVNATraces(app.VNA)`, etc.

## Instrument database

`instrumentAddresses.csv` (at the ARESMicro project root, found
automatically) is accepted in **either** lab schema — the ARES format
`Description,Address,Type,Class` (preferred: the `Type` column makes VNA
filtering exact) or the legacy ARESMicro format `Manufacturer,Model,Address`
(VNAs recognized by model token). The current file is ARES-format and the
lab VNAs are already listed:

| Instrument | Address | Notes |
|---|---|---|
| Keysight N5232B PNA-L | `TCPIP0::192.168.1.161::inst0::INSTR` | 4-port, use for `readSMatrix(vna, 1:4)` |
| Agilent E5072A ENA | `TCPIP0::192.168.3.95::inst0::INSTR` | 2-port |
| Copper Mountain CMT808U | `TCPIP0::127.0.0.1::5025::SOCKET` | via S4 socket server, see below |

**Copper Mountain (CMT808U etc.):** these are USB-only — there is no network
endpoint on the instrument. Run the CMT **S4** software on the PC connected
to the VNA, enable its Socket Server (System → Misc Setup → Network Remote
Control Settings, port 5025, off by default), and keep S4 open; the CSV row
points at that PC (`127.0.0.1` when it is this machine). The `CMT808U.json`
dialect loads automatically from the model token. On CMT use
`readVNATraces` / `VNALiveView` (both de-interleave CMT's `(value, 0)` data
format); `readSMatrix` needs the trace-catalog query that CMT firmware
lacks, so it is Keysight-only for now.

## Notes & limits

- **Model token matters.** `connectVNA` pulls it from the dropdown text or
  the CSV so the right `CommandSets/<Model>.json` dialect loads. A raw
  address with no CSV match falls back to the Keysight PNA/ENA dialect.
- **Slow sweeps:** `vna.SweepTimeoutSec` defaults to 60 s. Raise it for many
  points / narrow IF bandwidth / heavy averaging.
- **Full 4-port matrix needs 16 traces** configured on the VNA. You can pass
  `readSMatrix(vna, 1:4, 'AutoCreate', true)` to let the driver define
  missing traces itself, but that SCPI path is not yet hardware-verified —
  prefer setting traces up on the front panel and calibrating there.
- **New VNA model?** Drop a `CommandSets/<Model>.json` with the differing
  commands next to the framework — no code edits needed.
