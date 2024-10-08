export const serverUrl = 'http://127.0.0.1:5000'

export const post = (route, kv) =>
  new Promise((resolve, reject) => {
    fetch(serverUrl + route, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: new URLSearchParams(kv)
    }).then(res => {
      if (res.ok) return resolve(res)
      return reject(res)
    })
  })

export const get = route =>
  new Promise((resolve, reject) => {
    fetch(serverUrl + route).then(res => {
      if (res.ok) return resolve(res)
      return reject(res)
    })
  })
