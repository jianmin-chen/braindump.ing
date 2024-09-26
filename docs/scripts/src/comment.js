import Component from './component'
import { get } from './utils'

const appendComment = (container, { name, comment, comments }) => {
  console.log(name, comment)
  /** @jsx Component.createElement */
  const Comment = () => {
    return (
      <div className="comment">
        <h3>{name}</h3>
        {comment}
      </div>
    )
  }
  Component.render(<Comment />, container)
}

/** @jsx Component.createElement */
const Comment = () => {
  return <div></div>
}

const container = document.querySelector('.comments')
get('/comments/' + window.slug)
  .then(res => res.json())
  .then(comments => {
    comments.map(comment => appendComment(container, comment))
    if (!comments.length) throw new Error()
  })
  .catch(err => {
    container.innerHTML = '<p>No comments yet.</p>'
  })
