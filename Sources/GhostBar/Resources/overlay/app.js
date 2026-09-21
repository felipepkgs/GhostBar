const bars = document.querySelectorAll(".bar");

// Rebuilds the Control Strip row from the user's real, live customization —
// pushed from Swift (ControlStripReader) right before each fade-in.
window.setControlStrip = function (items) {
  const bar = document.getElementById("barControl");
  const dot = bar.querySelector(".dot");
  bar.querySelectorAll(".group, .spacer").forEach((el) => el.remove());

  items.forEach((item) => {
    if (item.kind === "space") {
      const spacer = document.createElement("div");
      spacer.className = "spacer";
      bar.insertBefore(spacer, dot);
      return;
    }
    const group = document.createElement("div");
    group.className = "group";
    group.style.flex = String(item.icons.length);
    item.icons.forEach((icon) => {
      const seg = document.createElement("div");
      seg.className = "seg";
      if (icon.type === "image" || icon.type === "image-small") {
        const img = document.createElement("img");
        img.className = icon.type === "image-small" ? "icon-img small" : "icon-img";
        img.src = "icons/" + icon.value;
        seg.appendChild(img);
      } else {
        seg.textContent = icon.value;
      }
      group.appendChild(seg);
    });
    bar.insertBefore(group, dot);
  });
};

// Hides whichever row ISN'T the Touch Bar's actual current mode for the
// frontmost app, instead of always presenting both as equally plausible.
window.setMode = function (mode) {
  const fKeysRow = document.getElementById("barFKeys").closest(".row");
  const controlRow = document.getElementById("barControl").closest(".row");
  fKeysRow.classList.toggle("hidden", mode !== "functionKeys");
  controlRow.classList.toggle("hidden", mode !== "controlStrip");
};

// Preferences' "Theme" picker — see style.css's body[data-theme="..."]
// blocks for what each one actually changes.
window.setTheme = function (theme) {
  document.body.dataset.theme = theme;
};

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
