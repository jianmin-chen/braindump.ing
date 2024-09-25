import Component from './component'

/** @jsx Component.createElement */
const Comments = () => {
  const [comments, setComments] = Component.useState([])

  return (
    <div>
      {comments.length ? (
        <div>there are comments.</div>
      ) : (
        <p className="no-comments">
          <i>No comments yet.</i>
        </p>
      )}
    </div>
  )
}

Component.render(<Comments />, document.querySelector('.comments'))
