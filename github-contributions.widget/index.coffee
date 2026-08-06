# Set your GitHub username on the first line of the command below (GH_USER).
# Pulls the public contribution calendar — no token required, public data only.

# Display mode: 'monochrome' (grey scale) or 'color' (GitHub greens).
mode: 'color'

# History span: 'year' (full ~53 weeks, 2-column / 650px wide) or '6mo' (last
# ~26 weeks, 1-column / 320px wide).
span: '6mo'

command: "GH_USER='dionmunk'; curl -s \"https://github.com/users/$GH_USER/contributions\" | grep -oE 'data-date=\"[0-9-]+\"[^>]*data-level=\"[0-9]\"' | sed -E 's/.*data-date=\"([0-9-]+)\"[^>]*data-level=\"([0-9]\").*/\\1,\\2/' | grep -oE '[0-9-]+,[0-9]'"

# Enable or disable this widget.
widgetEnabled: true   # true | false

refreshFrequency: 1800000 # 30 minutes

style: """
  // grid: col 3 · row 1 (see LAYOUT.md)
  top 10px
  left 670px

  color var(--text, #fff)
  text-shadow: 0 1px 1px rgba(20, 1, 1, 0.2)
  font-family -apple-system, BlinkMacSystemFont, system-ui, sans-serif
  display inline-block

  // Panel width is set in update() to fit the grid exactly (10px squares + 2px gaps).
  .panel
    background var(--panel-bg, rgba(#000, .15))
    -webkit-backdrop-filter: blur(var(--panel-blur, 48px))
    backdrop-filter: blur(var(--panel-blur, 48px))
    border-radius 10px
    padding 10px
    box-sizing border-box

  // grid-template-columns is set in update() (one 10px track per week). Even 2px
  // gap on both axes; the panel is sized to fit so gaps stay exactly 2px.
  .grid
    display grid
    grid-template-rows repeat(7, 10px)
    gap 2px

  .sq
    border-radius 2px
    box-shadow 0 1px 1px rgba(20, 1, 1, 0.10)
"""

render: -> """
  <div class="panel">
    <div class="grid"></div>
  </div>
"""

update: (output, domEl) ->
  # Hide entirely when disabled.
  if not @widgetEnabled
    $(domEl).css('display', 'none')
    return
  $(domEl).css('display', '')
  root = $(domEl)

  # Five-shade scales for contribution levels 0–4. Toggle with `mode` up top.
  palettes =
    color:      ['var(--level-base, rgba(255,255,255,.1))', 'rgba(var(--green-ch, 255,255,255), .25)', 'rgba(var(--green-ch, 255,255,255), .5)', 'rgba(var(--green-ch, 255,255,255), .75)', 'rgba(var(--green-ch, 255,255,255), 1)']
    monochrome: ['rgba(255,255,255,.06)', 'rgba(255,255,255,.2)', 'rgba(255,255,255,.45)', 'rgba(255,255,255,.7)', 'rgba(255,255,255,1)']
  colors = palettes[@mode] ? palettes.monochrome
  DAY = 86400000

  lines = (output or '').trim().split('\n').filter (l) -> /^\d{4}-\d\d-\d\d,\d$/.test l
  if lines.length is 0
    root.find('.grid').html "<div style='grid-row:1;font-size:11px;color:rgba(255,255,255,.7)'>No data — set your GitHub username in the command.</div>"
    return

  data = for line in lines
    [date, level] = line.split(',')
    { dt: new Date(date + 'T00:00:00Z'), date: date, level: parseInt(level, 10) }

  # GitHub returns the days in DOM order, not guaranteed chronological — sort so
  # the window and column math below are correct (else columns go negative).
  data.sort (a, b) -> a.dt - b.dt

  # Show a whole number of week-columns ending on the current (possibly partial)
  # week. 'year' → 53 weeks (2-col, ~654px); '6mo' → 25 weeks, which fits one
  # column (318px) exactly at a 2px gap. The leading column is always a full week.
  span = @span ? 'year'
  weeks = if span is '6mo' then 25 else 53
  last = data[data.length - 1].dt
  startSunday = new Date(last)
  startSunday.setUTCDate(last.getUTCDate() - last.getUTCDay() - (weeks - 1) * 7)
  data = data.filter (d) -> d.dt >= startSunday
  colOf = (dt) -> Math.floor((dt - startSunday) / (7 * DAY)) + 1

  maxCol = 0
  squares = for d in data
    row = d.dt.getUTCDay() + 1
    col = colOf(d.dt)
    maxCol = col if col > maxCol
    color = colors[d.level] ? colors[0]
    "<div class='sq' style='grid-row:#{row};grid-column:#{col};background:#{color}' title='#{d.date} (level #{d.level})'></div>"

  # Fixed 10px square columns (uniform, no sub-pixel rounding); justify-content
  # space-between spreads the leftover width into the gaps so the grid still
  # fills the panel edge-to-edge.
  cols = "repeat(#{maxCol}, 10px)"
  root.find('.grid').css('grid-template-columns', cols).html squares.join('')

  # Size the panel to fit the grid exactly: N×10px squares + (N−1)×2px gaps + 10px
  # padding each side — keeps the gaps a clean, even 2px (no space-between flex).
  panelWidth = maxCol * 10 + (maxCol - 1) * 2 + 20
  root.find('.panel').css 'width', "#{panelWidth}px"
