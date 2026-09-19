const bars = document.querySelectorAll(".bar");

window.onTouchPosition = function (data) {
  bars.forEach((bar) => {
    const dot = bar.querySelector(".dot");
    if (!data || !data.active) {
      dot.style.opacity = "0";
      clearActiveSeg(bar);
      return;
    }
    dot.style.opacity = "1";
    dot.style.left = (data.x * 100) + "%";
    highlightSeg(bar, data.x);
  });
};

// Lights up whichever segment the dot currently sits over, on both rows at
// once — cheap "touch feedback" that goes a long way toward feeling like a
// real display instead of a static reference chart.
function highlightSeg(bar, fraction) {
  const rect = bar.getBoundingClientRect();
  const pointerX = rect.left + fraction * rect.width;
  let match = null;
  bar.querySelectorAll(".seg").forEach((seg) => {
    const segRect = seg.getBoundingClientRect();
    if (pointerX >= segRect.left && pointerX <= segRect.right) match = seg;
  });
  bar.querySelectorAll(".seg.active-seg").forEach((seg) => {
    if (seg !== match) seg.classList.remove("active-seg");
  });
  if (match) match.classList.add("active-seg");
}

function clearActiveSeg(bar) {
  bar.querySelectorAll(".seg.active-seg").forEach((seg) => seg.classList.remove("active-seg"));
}

const actionIcons = {
  "Volume Up": "🔊", "Volume Down": "🔉", "Mute": "🔇",
  "Brightness Up": "🔆", "Brightness Down": "🔅",
  "Play / Pause": "⏯", "Next": "⏭", "Previous": "⏮",
  "Fast Forward": "⏩", "Rewind": "⏪", "Eject": "⏏",
  "Keyboard Brightness Up": "⌨️", "Keyboard Brightness Down": "⌨️",
  "Keyboard Brightness Toggle": "⌨️",
};

let actionHideTimer = null;

window.onAction = function (label) {
  const el = document.getElementById("action");
  const icon = actionIcons[label] || "•";
  el.innerHTML = `<div class="pill"><span class="icon">${icon}</span><span class="label">${label}</span></div>`;
  el.classList.add("visible");
  clearTimeout(actionHideTimer);
  actionHideTimer = setTimeout(() => el.classList.remove("visible"), 2000);
};
