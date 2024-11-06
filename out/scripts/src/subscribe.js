import Component from './component'
import { post } from './utils'

/** @jsx Component.createElement */
const Subscribe = () => {
  const [email, setEmail] = Component.useState('')
  const [placeholder, setPlaceholder] = Component.useState('jc@braindump.ing')
  const [info, setInfo] = Component.useState('Subscribe')
  const [success, setSuccess] = Component.useState(false)

  const subscribe = async event => {
    event.preventDefault()
    post('/subscribe', { email })
      .then(res => res.json())
      .then(submission => {
        if (submission.success) {
          setSuccess(() => true)
          setInfo(() => "You're subscribed!")
        } else throw new Error()
      }).catch(err => {
        setEmail(() => '')
        setPlaceholder(() => 'Shucks, try again!')
      })
  }

  return (
    <form onSubmit={subscribe}>
      <input
        type="email"
        disabled={success}
        placeholder={placeholder}
        onInput={event => setEmail(() => event.target.value)}
        value={email}
      />
      <button type="submit">{info}</button>
    </form>
  )
}

Component.render(<Subscribe />, document.getElementById('subscribe'))
