function getBtnInnerHtml(likes, liked) {
  // XSS vuln lol
  return `${(liked) ?
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" style="width: 20px; height: 20px">
  <path d="m11.645 20.91-.007-.003-.022-.012a15.247 15.247 0 0 1-.383-.218 25.18 25.18 0 0 1-4.244-3.17C4.688 15.36 2.25 12.174 2.25 8.25 2.25 5.322 4.714 3 7.688 3A5.5 5.5 0 0 1 12 5.052 5.5 5.5 0 0 1 16.313 3c2.973 0 5.437 2.322 5.437 5.25 0 3.925-2.438 7.111-4.739 9.256a25.175 25.175 0 0 1-4.244 3.17 15.247 15.247 0 0 1-.383.219l-.022.012-.007.004-.003.001a.752.752 0 0 1-.704 0l-.003-.001Z" />
</svg>` :
  `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" style="width: 20px; height: 20px">
  <path stroke-linecap="round" stroke-linejoin="round" d="M21 8.25c0-2.485-2.099-4.5-4.688-4.5-1.935 0-3.597 1.126-4.312 2.733-.715-1.607-2.377-2.733-4.313-2.733C5.1 3.75 3 5.765 3 8.25c0 7.22 9 12 9 12s9-4.78 9-12Z" />
</svg>`}
<span>${likes}</span>`
}

Array.prototype.forEach.call(document.getElementsByClassName("like-btn"), el => {
  el.addEventListener('click', (e) => {   
    e.stopPropagation()
    if (!el.dataset.id || !el.dataset.type || !el.dataset.isliked) return
    const newLike = !JSON.parse(el.dataset.isliked)
    fetch("/like", {
      method: "PATCH",
      body: JSON.stringify({
        id: el.dataset.id,
        to_like: newLike,
        type: el.dataset.type
      }),
      headers: { "Content-Type": "application/json" }
    }).then(r => {
      if (!r.ok) alert("Could not like")
      el.dataset.isliked = JSON.stringify(newLike)
      el.innerHTML = getBtnInnerHtml(Number(el.querySelector("span").innerText) + (newLike ? 1 : -1), newLike)
    }).catch(e => alert("Could not like: " + e.message))
  })
})

