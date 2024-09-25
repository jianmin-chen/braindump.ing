import Component from './component'
import { post } from './utils'

/** @jsx Component.createElement */
const Subscribe = () => {
  const [email, setEmail] = Component.useState('')

  const subscribe = async event => {
    event.preventDefault()
    post('/subscribe', { email }).then(res => {
      console.log(res)
    })
  }

  return (
    <form onSubmit={subscribe}>
      <input
        type="email"
        placeholder="jc@braindump.ing"
        onInput={event => setEmail(() => event.target.value)}
      />
      <button type="submit">Subscribe</button>
    </form>
  )
}

Component.render(<Subscribe />, document.getElementById('subscribe'))
