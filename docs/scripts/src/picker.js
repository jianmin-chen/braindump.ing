import Component from './component'

const pickerSize = 30

// prettier-ignore
const colors = [[255, 0, 0], [255, 127, 0], [255, 255, 0], [0, 255, 0], [0, 0, 255], [102, 0, 255], [139, 0, 255]]
const interpolate = (a, b, p) => {
  const colorVal = idx => Math.round(a[idx] * (1 - p) + b[idx] * p)
  return [colorVal(0), colorVal(1), colorVal(2)]
}
const lerp = (x, y, a) => x * (1 - a) + y * a

const setColor = color => {
  const rgb = `rgb(${color[0]}, ${color[1]}, ${color[2]})`
  document.documentElement.style.setProperty('--theme', rgb)
  // localStorage.setItem('theme', rgb)
}

/** @jsx Component.createElement */
const Picker = () => {
  const [top, setTop] = Component.useState(0)
  const [left, setLeft] = Component.useState(0)
  const [dragging, setDragging] = Component.useState(false)

  const movePicker = event => {
    const newLeft = event.clientX - pickerSize / 2
    setLeft(() => newLeft)
    setTop(() => event.clientY - pickerSize / 2)

    if (dragging === true) {
      const p = lerp(0, colors.length - 1, newLeft / window.innerWidth)
      const start = colors[Math.floor(p)]
      const end = colors[Math.ceil(p)]
      setColor(interpolate(start, end, p - Math.floor(p)))
    }
  }

  return (
    <div
      id="color-picker-wrapper"
      onMouseMove={movePicker}
      onMouseDown={() => setDragging(() => true)}
      onMouseUp={() => setDragging(() => false)}>
      <h1 id="logo">braindump.ing</h1>
      <div className="picker" style={`top: ${top}px; left: ${left}px`} />
    </div>
  )
}

Component.render(<Picker />, document.querySelector('header'))
