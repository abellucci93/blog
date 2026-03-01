'use strict';

const clapButton = document.getElementById("clap-button");
const clapCount = document.getElementById("clap-count");

if (clapButton && clapCount) {
  const identifier = clapButton.dataset.identifier;

  // Load initial count
  fetch(`/api/claps/count?identifier=${identifier}`)
    .then(resp => resp.ok ? resp.json() : null)
    .then(data => { if (data?.clap?.count != null) clapCount.textContent = data.clap.count; });

  // Click listener
  clapButton.addEventListener("click", async (e) => {
    e.preventDefault();
    const resp = await fetch("http://localhost:8000/api/claps", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ identifier })
    });
    if (resp.ok) {
      const data = await resp.json();
      clapCount.textContent = data.clap.count;
    }
  });
}